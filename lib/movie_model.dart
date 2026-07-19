class Movie {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final String overview;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    required this.voteAverage,
    required this.overview,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // TMDB uses 'title' for movies and 'name' for TV series
    String title = json['title'] ?? json['name'] ?? 'Unknown';
    
    // TMDB uses 'release_date' for movies and 'first_air_date' for TV series
    String? date = json['release_date'] ?? json['first_air_date'];

    return Movie(
      id: json['id'] ?? 0,
      title: title,
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: date,
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      overview: json['overview'] ?? '',
    );
  }

  String get posterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : 'https://via.placeholder.com/500x750?text=No+Image';
}
