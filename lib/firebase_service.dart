import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        // 'unavailable' error is common on first runs or connectivity issues
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

  Future<void> toggleWatchlist(
    int id,
    String type,
    String title,
    String posterPath,
  ) async {
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
        await docRef.set({
          'id': id,
          'type': type,
          'title': title,
          'poster_path': posterPath,
          'added_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> toggleFavorite(
    int id,
    String type,
    String title,
    String posterPath,
  ) async {
    final user = currentUser;
    if (user == null) return;

    await _runWithRetry(() async {
      final docRef = _usersCollection
          .doc(user.uid)
          .collection('favorites')
          .doc(id.toString());

      // Attempt to get document with cache awareness
      final doc = await docRef.get(
        const GetOptions(source: Source.serverAndCache),
      );

      if (doc.exists) {
        await docRef.delete();
      } else {
        await docRef.set({
          'id': id,
          'type': type,
          'title': title,
          'poster_path': posterPath,
          'added_at': FieldValue.serverTimestamp(),
        });
      }
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

  Stream<QuerySnapshot> getFavoritesStream() {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _usersCollection
        .doc(user.uid)
        .collection('favorites')
        .orderBy('added_at', descending: true)
        .snapshots(includeMetadataChanges: true);
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
          return doc.data() as Map<String, dynamic>;
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
