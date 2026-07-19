import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'episode_detail_screen.dart';
import 'firebase_service.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String contentType;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.contentType = 'movie',
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _movieDetails;
  List<dynamic> _episodes = [];
  int _selectedSeason = 1;
  bool _isLoading = true;
  bool _isEpisodesLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetails());
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await _apiService.fetchDetails(
        widget.contentType,
        widget.movieId,
      );
      if (mounted) {
        setState(() {
          _movieDetails = details;
          _isLoading = false;
        });
        if (widget.contentType == 'tv') {
          final seasons = details['seasons'] as List?;
          if (seasons != null && seasons.isNotEmpty) {
            final firstSeason = seasons.firstWhere(
              (s) => s['season_number'] != 0,
              orElse: () => seasons.first,
            );
            _fetchSeasonDetails(firstSeason['season_number']);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSeasonDetails(int seasonNumber) async {
    if (!mounted) return;
    setState(() {
      _isEpisodesLoading = true;
      _selectedSeason = seasonNumber;
    });

    try {
      final data = await _apiService.fetchSeasonDetails(
        widget.movieId,
        seasonNumber,
      );
      if (mounted) {
        setState(() {
          _episodes = data['episodes'] ?? [];
          _isEpisodesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEpisodesLoading = false;
        });
      }
    }
  }

  Future<void> _loadTrailer() async {
    try {
      final data = await _apiService.fetchVideos(
        widget.contentType,
        widget.movieId,
      );
      final List results = data['results'];
      if (results.isNotEmpty) {
        final video = results.firstWhere(
          (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
          orElse: () => results.first,
        );

        String youtubeUrl = "https://www.youtube.com/watch?v=${video['key']}";
        final Uri url = Uri.parse(youtubeUrl);

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Something went wrong. Please try again.'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No trailer available.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _movieDetails == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white24,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Something went wrong. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _fetchDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 15),
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                        _buildGenres(),
                        _buildMetadataRow(),
                        const SizedBox(height: 15),
                        Text(
                          _movieDetails!['overview'] ??
                              'No overview available.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildCastAndCredits(),
                        const SizedBox(height: 30),
                        if (widget.contentType == 'tv') ...[
                          _buildSeasonPicker(),
                          const SizedBox(height: 20),
                          _buildEpisodeList(),
                        ] else ...[
                          _buildDetailedStats(),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    final backdropPath = _movieDetails!['backdrop_path'];
    return SliverAppBar(
      expandedHeight: 450,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: StreamBuilder<bool>(
            stream: _firebaseService.isFavorited(widget.movieId),
            builder: (context, snapshot) {
              final isFav = snapshot.data ?? false;
              return CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    _firebaseService.toggleFavorite(
                      widget.movieId,
                      widget.contentType,
                      _movieDetails!['title'] ??
                          _movieDetails!['name'] ??
                          'Unknown',
                      _movieDetails!['poster_path'] ?? '',
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropPath != null)
              Image.network(
                'https://image.tmdb.org/t/p/original$backdropPath',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey[900]),
              )
            else
              Container(color: Colors.grey[900]),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Colors.black.withAlpha(150),
                    Colors.transparent,
                    Colors.black.withAlpha(200),
                    Colors.black,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    String title =
        _movieDetails!['title'] ?? _movieDetails!['name'] ?? 'Unknown';
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.contentType == 'tv') {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: _loadTrailer,
            icon: const Icon(Icons.play_arrow, color: Colors.black, size: 28),
            label: const Text(
              'Play',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: StreamBuilder<bool>(
            stream: _firebaseService.isWatchlisted(widget.movieId),
            builder: (context, snapshot) {
              final inWatchlist = snapshot.data ?? false;
              return ElevatedButton.icon(
                onPressed: () {
                  _firebaseService.toggleWatchlist(
                    widget.movieId,
                    widget.contentType,
                    _movieDetails!['title'] ??
                        _movieDetails!['name'] ??
                        'Unknown',
                    _movieDetails!['poster_path'] ?? '',
                  );
                },
                icon: Icon(
                  inWatchlist ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  inWatchlist ? 'Added to List' : 'My List',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: inWatchlist
                      ? Colors.white.withAlpha(60)
                      : Colors.white.withAlpha(30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenres() {
    final genres = _movieDetails!['genres'] as List?;
    if (genres == null || genres.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: genres.map<Widget>((genre) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              genre['name'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetadataRow() {
    final year =
        (_movieDetails!['release_date'] ?? _movieDetails!['first_air_date'])
            ?.split('-')[0] ??
        'N/A';
    final vote = _movieDetails!['vote_average']?.toStringAsFixed(1) ?? '0.0';
    return Row(
      children: [
        Text(
          year,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Text(
            '18+',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 15),
        if (widget.contentType == 'tv')
          Text(
            '${_movieDetails!['number_of_seasons'] ?? 1} ${_movieDetails!['number_of_seasons'] == 1 ? 'Season' : 'Seasons'}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            '${_movieDetails!['runtime'] ?? 0}m',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(width: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Text(
            'HD',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          vote,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCastAndCredits() {
    final creators = _movieDetails!['created_by'] as List?;
    final networks = _movieDetails!['networks'] as List?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (creators != null && creators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                text: 'Creators: ',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                children: creators
                    .map(
                      (c) => TextSpan(
                        text:
                            '${c['name']}${creators.indexOf(c) == creators.length - 1 ? '' : ', '}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        if (networks != null && networks.isNotEmpty)
          RichText(
            text: TextSpan(
              text: 'Network: ',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              children: networks
                  .map(
                    (n) => TextSpan(
                      text:
                          '${n['name']}${networks.indexOf(n) == networks.length - 1 ? '' : ', '}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSeasonPicker() {
    final seasonsList = _movieDetails!['seasons'] as List?;
    if (seasonsList == null || seasonsList.isEmpty)
      return const SizedBox.shrink();
    final seasons = seasonsList.where((s) => s['season_number'] != 0).toList();
    if (seasons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12, thickness: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Episodes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<int>(
                value: _selectedSeason,
                dropdownColor: const Color(0xFF1E1E1E),
                underline: const SizedBox(),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (val) {
                  if (val != null) _fetchSeasonDetails(val);
                },
                items: seasons.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem<int>(
                    value: s['season_number'],
                    child: Text('Season ${s['season_number']}'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    if (_isEpisodesLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    if (_episodes.isEmpty)
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          'No episodes found for this season.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final ep = _episodes[index];
        final stillPath = ep['still_path'];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EpisodeDetailScreen(
                  tvId: widget.movieId,
                  seasonNumber: _selectedSeason,
                  episodeNumber: ep['episode_number'],
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 130,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                      image: stillPath != null
                          ? DecorationImage(
                              image: NetworkImage(
                                'https://image.tmdb.org/t/p/w300$stillPath',
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: stillPath == null
                        ? const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ep['episode_number']}. ${ep['name']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${ep['runtime'] ?? 0}m',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ep['overview'] ?? 'No description available.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailedStats() {
    final budget = _movieDetails!['budget'] ?? 0;
    final tagline = _movieDetails!['tagline'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tagline != null && tagline.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              tagline,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem('Status', _movieDetails!['status'] ?? 'N/A'),
            _buildStatItem(
              'Language',
              _movieDetails!['original_language']?.toUpperCase() ?? 'N/A',
            ),
            if (widget.contentType == 'movie')
              _buildStatItem(
                'Budget',
                budget > 0
                    ? '\$${(budget / 1000000).toStringAsFixed(1)}M'
                    : 'N/A',
              )
            else
              _buildStatItem(
                'Episodes',
                '${_movieDetails!['number_of_episodes'] ?? 'N/A'}',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
