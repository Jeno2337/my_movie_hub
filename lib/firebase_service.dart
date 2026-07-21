import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  User? get currentUser => _auth.currentUser;

  // Auth stream to track login status
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Watchlist & Favorites Collections
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Local Storage Keys
  static const String _userPrefsKey = 'user_data';
  static const String _languagePrefsKey = 'user_language';

  // Helper to run Firestore operations with retry logic
  Future<T> _runWithRetry<T>(
    Future<T> Function() action, {
    int retries = 3,
  }) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        return await action();
      } on FirebaseException catch (e) {
        attempt++;
        if (e.code == 'unavailable' && attempt < retries) {
          print(
            'FIRESTORE: Service unavailable, retrying in ${attempt * 2}s (Attempt $attempt)...',
          );
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    }
    throw Exception('Firestore operation failed after $retries attempts');
  }

  // Helper to convert Firestore specific types (like Timestamp) to JSON-friendly types
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      }
    });
    return sanitized;
  }

  Future<void> saveUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitized = _sanitizeData(data);
      await prefs.setString(_userPrefsKey, json.encode(sanitized));
      print('LOCAL STORAGE: User data saved successfully.');
    } catch (e) {
      print('LOCAL STORAGE ERROR: Failed to save user data. $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_userPrefsKey);
      if (dataString != null) {
        return json.decode(dataString) as Map<String, dynamic>;
      }
    } catch (e) {
      print('LOCAL STORAGE ERROR: Failed to fetch user data. $e');
    }
    return null;
  }

  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userPrefsKey);
      print('LOCAL STORAGE: User data cleared.');
    } catch (e) {
      print('LOCAL STORAGE ERROR: Failed to clear user data. $e');
    }
  }

  Future<void> setLanguage(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefsKey, code);
      if (currentUser != null) {
        await _usersCollection.doc(currentUser!.uid).update({'language': code});
      }
    } catch (e) {
      print('SET LANGUAGE ERROR: $e');
    }
  }

  Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languagePrefsKey) ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  Future<void> toggleWatchlist({
    required int id,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _runWithRetry(() async {
      final docRef = _usersCollection
          .doc(user.uid)
          .collection('watchlist')
          .doc(id.toString());
      final doc = await docRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (doc.exists) {
        await docRef.delete();
      } else {
        final Map<String, dynamic> uploadData = Map<String, dynamic>.from(
          details,
        );
        uploadData['id'] = id;
        uploadData['type'] = type;
        uploadData['added_at'] = FieldValue.serverTimestamp();

        await docRef.set(uploadData);
      }
    });
  }

  Future<void> toggleFavorite({
    required int id,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _runWithRetry(() async {
      final docRef = _usersCollection
          .doc(user.uid)
          .collection('favorites')
          .doc(id.toString());

      final doc = await docRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (doc.exists) {
        await docRef.delete();
      } else {
        final Map<String, dynamic> uploadData = Map<String, dynamic>.from(
          details,
        );
        uploadData['id'] = id;
        uploadData['type'] = type;
        uploadData['added_at'] = FieldValue.serverTimestamp();

        await docRef.set(uploadData);
      }
    });
  }

  Stream<bool> isFavorited(int id) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _usersCollection
        .doc(user.uid)
        .collection('favorites')
        .doc(id.toString())
        .snapshots(includeMetadataChanges: true)
        .map((doc) => doc.exists);
  }

  Stream<Map<String, dynamic>> getLibraryStats() {
    final user = currentUser;
    if (user == null) return Stream.value({});

    final favorites = _usersCollection
        .doc(user.uid)
        .collection('favorites')
        .snapshots();
    final watching = _usersCollection
        .doc(user.uid)
        .collection('watching')
        .snapshots();
    final completed = _usersCollection
        .doc(user.uid)
        .collection('completed')
        .snapshots();
    final watchlist = _usersCollection
        .doc(user.uid)
        .collection('watchlist')
        .snapshots();

    return CombineLatestStream.list([
      favorites,
      watching,
      completed,
      watchlist,
    ]).map((snapshots) {
      final favDocs = snapshots[0].docs;
      final watchingDocs = snapshots[1].docs;
      final completedDocs = snapshots[2].docs;
      final watchlistDocs = snapshots[3].docs;

      int movieMins = 0;
      int tvMins = 0;
      int movieCount = 0;
      int showCount = 0;
      int episodeCount = 0;

      Map<String, int> movieGenres = {};
      Map<String, int> tvGenres = {};

      for (var doc in completedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] ?? 'movie';
        final runtime = data['runtime'] ?? 0;
        final genres = data['genres'] as List?;

        if (type == 'movie') {
          movieMins += (runtime as int);
          movieCount++;
          if (genres != null) {
            for (var g in genres) {
              final n = g['name'] as String?;
              if (n != null) movieGenres[n] = (movieGenres[n] ?? 0) + 1;
            }
          }
        } else {
          tvMins += (runtime as int);
          if (type == 'tv') showCount++;
          if (type == 'episode') episodeCount++;
          if (genres != null) {
            for (var g in genres) {
              final n = g['name'] as String?;
              if (n != null) tvGenres[n] = (tvGenres[n] ?? 0) + 1;
            }
          }
        }
      }

      final totalMinutes = movieMins + tvMins;

      // Top Movie Genres
      final sortedMovieGenres = movieGenres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMovieGenres = sortedMovieGenres
          .take(3)
          .map(
            (e) => {
              'name': e.key,
              'percentage': movieCount == 0 ? 0.0 : e.value / movieCount,
            },
          )
          .toList();

      // Top TV Genres
      final sortedTvGenres = tvGenres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTvGenres = sortedTvGenres
          .take(3)
          .map(
            (e) => {
              'name': e.key,
              'percentage': (showCount + episodeCount) == 0
                  ? 0.0
                  : e.value / (showCount + episodeCount),
            },
          )
          .toList();

      return {
        'favorites': favDocs.length,
        'watching': watchingDocs.length,
        'completed': completedDocs.length,
        'watchlist': watchlistDocs.length,
        'watchTimeHrs': (totalMinutes / 60).toStringAsFixed(1),
        'movieMinutes': movieMins,
        'tvMinutes': tvMins,
        'movies': movieCount,
        'shows': showCount,
        'episodes': episodeCount,
        'topMovieGenres': topMovieGenres,
        'topTvGenres': topTvGenres,
        'completionRate': (watchlistDocs.length + completedDocs.length) == 0
            ? 0.0
            : completedDocs.length /
                  (watchlistDocs.length + completedDocs.length),
      };
    });
  }

  Stream<bool> isWatchlisted(int id) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _usersCollection
        .doc(user.uid)
        .collection('watchlist')
        .doc(id.toString())
        .snapshots(includeMetadataChanges: true)
        .map((doc) => doc.exists);
  }

  Future<void> markAsCompleted({
    required int id,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _runWithRetry(() async {
      // 1. Add to completed
      final completedDoc = _usersCollection
          .doc(user.uid)
          .collection('completed')
          .doc(id.toString());

      final Map<String, dynamic> uploadData = Map<String, dynamic>.from(
        details,
      );
      uploadData['id'] = id;
      uploadData['type'] = type;
      uploadData['completed_at'] = FieldValue.serverTimestamp();

      await completedDoc.set(uploadData, SetOptions(merge: true));

      // 2. Remove from watching
      await _usersCollection
          .doc(user.uid)
          .collection('watching')
          .doc(id.toString())
          .delete();
    });
  }

  Stream<QuerySnapshot> getCompletedStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _usersCollection
        .doc(user.uid)
        .collection('completed')
        .orderBy('completed_at', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<bool> isWatching(int id) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _usersCollection
        .doc(user.uid)
        .collection('watching')
        .doc(id.toString())
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<bool> isCompleted(int id) {
    final user = currentUser;
    if (user == null) return Stream.value(false);
    return _usersCollection
        .doc(user.uid)
        .collection('completed')
        .doc(id.toString())
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> addToWatching({
    required int id,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _runWithRetry(() async {
      final docRef = _usersCollection
          .doc(user.uid)
          .collection('watching')
          .doc(id.toString());

      final Map<String, dynamic> uploadData = Map<String, dynamic>.from(
        details,
      );
      uploadData['id'] = id;
      uploadData['type'] = type;
      uploadData['updated_at'] = FieldValue.serverTimestamp();

      await docRef.set(uploadData, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot> getWatchingStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _usersCollection
        .doc(user.uid)
        .collection('watching')
        .orderBy('updated_at', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot> getWatchlistStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _usersCollection
        .doc(user.uid)
        .collection('watchlist')
        .orderBy('added_at', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot> getFavoritesStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _usersCollection
        .doc(user.uid)
        .collection('favorites')
        .orderBy('added_at', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<List<Map<String, dynamic>>> getAllLibraryItemsStream() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    final f = _usersCollection
        .doc(user.uid)
        .collection('favorites')
        .snapshots();
    final w = _usersCollection.doc(user.uid).collection('watching').snapshots();
    final c = _usersCollection
        .doc(user.uid)
        .collection('completed')
        .snapshots();
    final l = _usersCollection
        .doc(user.uid)
        .collection('watchlist')
        .snapshots();

    return CombineLatestStream.list([f, w, c, l]).map((snapshots) {
      final List<Map<String, dynamic>> items = [];
      final Set<int> seenIds = {};

      for (var snap in snapshots) {
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final id = data['id'] as int?;
          if (id != null && !seenIds.contains(id)) {
            items.add(data);
            seenIds.add(id);
          }
        }
      }
      return items;
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String mobile,
  }) async {
    try {
      // 1. Create Auth User
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Store Extra Details in Firestore
      if (credential.user != null) {
        final userData = {
          'uid': credential.user!.uid,
          'name': name,
          'email': email,
          'mobile': mobile,
          'created_at': FieldValue.serverTimestamp(),
          'language': 'en',
        };

        await _runWithRetry(() async {
          await _usersCollection.doc(credential.user!.uid).set(userData);
        });

        print('FIRESTORE: User profile stored.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'The account already exists for that email.';
      } else if (e.code == 'weak-password') {
        throw 'The password provided is too weak.';
      }
      throw 'Something went wrong. Please try again.';
    } catch (e) {
      throw 'Something went wrong. Please try again.';
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate with Firebase Auth
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Fetch User Profile from Firestore
      if (credential.user != null) {
        final doc = await _runWithRetry(() async {
          return await _usersCollection
              .doc(credential.user!.uid)
              .get(const GetOptions(source: Source.serverAndCache));
        });

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['language'] != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_languagePrefsKey, data['language']);
          }
          return data;
        } else {
          return {'uid': credential.user!.uid, 'email': email};
        }
      }
      throw 'User credential empty';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw 'Invalid email or password.';
      }
      throw 'Something went wrong. Please try again.';
    } catch (e) {
      throw 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await clearUserData();
  }
}
