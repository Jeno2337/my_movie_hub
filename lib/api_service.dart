import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _apiKey = '52a8d08460f52a0406ba246ed2f200c3';

  Future<Map<String, dynamic>> _getWithRetry(Uri url, {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          print('API ERROR Status ${response.statusCode} for $url');
          throw HttpException('Status ${response.statusCode}');
        }
      } catch (e) {
        attempt++;
        print('API ATTEMPT $attempt failed for $url: $e');
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw Exception('Failed after $retries attempts');
  }

  Future<Map<String, dynamic>> fetchDiscover(
    String type,
    int page, {
    int? genreId,
    String? languageCode,
    String? region,
  }) async {
    String urlString = '$_baseUrl/discover/$type?api_key=$_apiKey&page=$page';
    if (genreId != null) {
      urlString += '&with_genres=$genreId';
    }
    if (languageCode != null && languageCode != 'en') {
      urlString += '&with_original_language=$languageCode';
    }
    if (region != null) {
      urlString += '&region=$region';
    }
    final url = Uri.parse(urlString);
    print('API REQUEST [fetchDiscover ($type)]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchTrending(
    String type,
    int page, {
    String timeWindow = 'day',
    String? languageCode,
  }) async {
    String urlString =
        '$_baseUrl/trending/$type/$timeWindow?api_key=$_apiKey&page=$page';
    if (languageCode != null && languageCode != 'en') {
      // Trending API does not directly support with_original_language in discover sense
      // but we can use discover for language specific "trending" or just use discover
    }
    final url = Uri.parse(urlString);
    print('API REQUEST [fetchTrending ($type/$timeWindow)]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchDetails(String type, int id) async {
    final url = Uri.parse('$_baseUrl/$type/$id?api_key=$_apiKey');
    print('API REQUEST [fetchDetails ($type)]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchVideos(String type, int id) async {
    final url = Uri.parse('$_baseUrl/$type/$id/videos?api_key=$_apiKey');
    print('API REQUEST [fetchVideos ($type)]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchSeasonDetails(
    int tvId,
    int seasonNumber,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=$_apiKey',
    );
    print('API REQUEST [fetchSeasonDetails]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchEpisodeDetails(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/tv/$tvId/season/$seasonNumber/episode/$episodeNumber?api_key=$_apiKey',
    );
    print('API REQUEST [fetchEpisodeDetails]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchEpisodeImages(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/tv/$tvId/season/$seasonNumber/episode/$episodeNumber/images?api_key=$_apiKey',
    );
    print('API REQUEST [fetchEpisodeImages]: $url');
    return _getWithRetry(url);
  }

  Future<Map<String, dynamic>> fetchGenres(String type) async {
    final url = Uri.parse('$_baseUrl/genre/$type/list?api_key=$_apiKey');
    print('API REQUEST [fetchGenres ($type)]: $url');
    return _getWithRetry(url);
  }
}
