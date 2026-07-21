import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'firebase_service.dart';

class EpisodeDetailScreen extends StatefulWidget {
  final int tvId;
  final int seasonNumber;
  final int episodeNumber;

  const EpisodeDetailScreen({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _episodeDetails;
  List<dynamic> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await _apiService.fetchEpisodeDetails(
        widget.tvId,
        widget.seasonNumber,
        widget.episodeNumber,
      );
      final imagesData = await _apiService.fetchEpisodeImages(
        widget.tvId,
        widget.seasonNumber,
        widget.episodeNumber,
      );

      if (mounted) {
        setState(() {
          _episodeDetails = details;
          _images = imagesData['stills'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTrailer() async {
    // Add to 'watching' collection
    if (_episodeDetails != null) {
      _firebaseService.addToWatching(
        id: _episodeDetails!['id'] ?? 0,
        type: 'episode',
        details: _episodeDetails!,
      );
    }

    try {
      final data = await _apiService.fetchVideos('tv', widget.tvId);
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
          : _episodeDetails == null
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
                    onPressed: _fetchData,
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
                        _buildMetadataRow(),
                        const SizedBox(height: 15),
                        Text(
                          _episodeDetails!['overview'] ??
                              'No overview available.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (_images.isNotEmpty) _buildImageGallery(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    final stillPath = _episodeDetails!['still_path'];
    return SliverAppBar(
      expandedHeight: 250,
      backgroundColor: Colors.black,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black54,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: StreamBuilder<bool>(
            stream: _firebaseService.isFavorited(_episodeDetails!['id'] ?? 0),
            builder: (context, snapshot) {
              final isFav = snapshot.data ?? false;
              return CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white,
                    size: 18,
                  ),
                  onPressed: () async {
                    _firebaseService.toggleFavorite(
                      id: _episodeDetails!['id'] ?? 0,
                      type: 'episode',
                      details: _episodeDetails ?? {},
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
            if (stillPath != null)
              Image.network(
                'https://image.tmdb.org/t/p/original$stillPath',
                fit: BoxFit.cover,
              )
            else
              Container(color: Colors.grey[900]),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Text(
      "${_episodeDetails!['episode_number']}. ${_episodeDetails!['name']}"
          .toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildActionButtons() {
    return StreamBuilder<bool>(
      stream: _firebaseService.isWatching(_episodeDetails?['id'] ?? 0),
      builder: (context, snapshot) {
        final isWatching = snapshot.data ?? false;

        if (isWatching) {
          return SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_episodeDetails != null) {
                  await _firebaseService.markAsCompleted(
                    id: _episodeDetails!['id'] ?? 0,
                    type: 'episode',
                    details: _episodeDetails!,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              icon: const Icon(
                Icons.check_circle,
                color: Colors.black,
                size: 24,
              ),
              label: const Text(
                'Completed',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _loadTrailer,
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 28,
                      ),
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
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _loadTrailer,
                      icon: const Icon(
                        Icons.video_library,
                        color: Colors.black,
                        size: 24,
                      ),
                      label: const Text(
                        'Trailer',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: StreamBuilder<bool>(
                stream: _firebaseService.isWatchlisted(
                  _episodeDetails?['id'] ?? 0,
                ),
                builder: (context, snapshot) {
                  final inWatchlist = snapshot.data ?? false;
                  return ElevatedButton.icon(
                    onPressed: () {
                      _firebaseService.toggleWatchlist(
                        id: _episodeDetails!['id'] ?? 0,
                        type: 'episode',
                        details: _episodeDetails ?? {},
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
      },
    );
  }

  Widget _buildMetadataRow() {
    final airDate = _episodeDetails!['air_date']?.split('-')[0] ?? 'N/A';
    final vote = _episodeDetails!['vote_average']?.toStringAsFixed(1) ?? '0.0';
    return Row(
      children: [
        Text(
          'Season ${widget.seasonNumber}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 15),
        Text(
          airDate,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 15),
        if (_episodeDetails!['runtime'] != null)
          Text(
            "${_episodeDetails!['runtime']}m",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STILLS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  'https://image.tmdb.org/t/p/w300${_images[index]['file_path']}',
                  width: 200,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
