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
  Map<String, dynamic>? _watchProviders;
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
      final providers = await _apiService.fetchWatchProviders(
        'tv',
        widget.tvId,
      );

      debugPrint('WATCH PROVIDERS API DATA (EPISODE/TV): $providers');

      if (mounted) {
        setState(() {
          _episodeDetails = details;
          _images = imagesData['stills'] ?? [];
          _watchProviders = providers['results']?['IN'];
          _isLoading = false;
        });
        debugPrint('WATCH PROVIDERS FOR IN (EPISODE/TV): $_watchProviders');
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
                        const SizedBox(height: 20),
                        _buildWatchProviders(),
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
      stream: _firebaseService.isCompleted(_episodeDetails?['id'] ?? 0),
      builder: (context, completedSnapshot) {
        final isCompleted = completedSnapshot.data ?? false;

        if (isCompleted) {
          return Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(40),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.greenAccent.withAlpha(100)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                SizedBox(width: 10),
                Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        }

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
                          onPressed: () async {
                            if (_episodeDetails != null) {
                              await _firebaseService.addToWatching(
                                id: _episodeDetails!['id'] ?? 0,
                                type: 'episode',
                                details: _episodeDetails!,
                              );
                            }
                          },
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
                          inWatchlist
                              ? 'Added to Bucket List'
                              : 'My Bucket List',
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

  Widget _buildWatchProviders() {
    if (_watchProviders == null) return const SizedBox.shrink();

    final List<dynamic> flatrate = _watchProviders!['flatrate'] ?? [];
    final List<dynamic> rent = _watchProviders!['rent'] ?? [];
    final List<dynamic> buy = _watchProviders!['buy'] ?? [];

    if (flatrate.isEmpty && rent.isEmpty && buy.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'WHERE TO WATCH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (flatrate.isNotEmpty)
          _buildProviderRow('Available on Streaming', flatrate),
        if (rent.isNotEmpty) _buildProviderRow('Rent', rent),
        if (buy.isNotEmpty) _buildProviderRow('Buy', buy),
        const SizedBox(height: 10),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _buildProviderRow(String label, List<dynamic> providers) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50, // Adjusted height to accommodate 35h image + padding
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: providers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = providers[index];
                return GestureDetector(
                  onTap: () async {
                    if (_watchProviders?['link'] != null) {
                      final Uri url = Uri.parse(_watchProviders!['link']);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 150, // Updated width to 150w
                    height: 35, // Updated height to 35h
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Tooltip(
                      message: p['provider_name'],
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://image.tmdb.org/t/p/w154${p['logo_path']}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.tv, color: Colors.white24),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha(80),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
