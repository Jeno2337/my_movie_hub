import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'firebase_service.dart';
import 'movie_detail_screen.dart';
import 'movie_model.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _discoverScrollController = ScrollController();

  final List<Movie> _movies = [];
  List<Movie> _trendingMovies = [];
  final List<Movie> _discoverMovies = [];
  List<dynamic> _genres = [];

  int _currentPage = 1;
  int _discoverPage = 1;
  int _totalMoviesCount = 0;
  int _totalSeriesCount = 0;
  int? _selectedGenreId;

  bool _isLoading = false;
  bool _isTrendingLoading = false;
  bool _isDiscoverLoading = false;
  bool _isGenresLoading = false;

  bool _hasMore = true;
  bool _discoverHasMore = true;

  String _homeType = 'movie';
  String _libraryType = 'movie';
  String _discoverType = 'movie';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_onScroll);
    _discoverScrollController.addListener(_onDiscoverScroll);
    _initializeData();
  }

  Future<void> _initializeData() async {
    final language = await _firebaseService.getLanguage();
    setState(() {
      _isLoading = true;
      _isTrendingLoading = true;
      _isDiscoverLoading = true;
      _movies.clear();
      _trendingMovies.clear();
      _discoverMovies.clear();
      _currentPage = 1;
      _discoverPage = 1;
    });

    _fetchGenres();
    _fetchTrending(languageCode: language);
    _fetchDiscover(languageCode: language);
    _fetchDiscoverTab(languageCode: language);
  }

  Future<void> _fetchGenres() async {
    if (mounted) setState(() => _isGenresLoading = true);
    try {
      debugPrint('API TASK: Fetching Genres for $_discoverType');
      final data = await _apiService.fetchGenres(_discoverType);
      if (mounted) {
        setState(() {
          _genres = data['genres'] ?? [];
          _isGenresLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch genres: $e');
      if (mounted) setState(() => _isGenresLoading = false);
    }
  }

  Future<void> _fetchTrending({String? languageCode}) async {
    final lang = languageCode ?? await _firebaseService.getLanguage();
    if (mounted) setState(() => _isTrendingLoading = true);

    try {
      final timeWindow = _homeType == 'tv' ? 'week' : 'day';
      debugPrint('API TASK: Fetching Trending ($_homeType) for lang: $lang');

      Map<String, dynamic> data;
      if (lang == 'en') {
        data = await _apiService.fetchTrending(
          _homeType,
          1,
          timeWindow: timeWindow,
        );
      } else {
        data = await _apiService.fetchDiscover(
          _homeType,
          1,
          languageCode: lang,
        );
      }

      final List<dynamic> results = data['results'] ?? [];
      final List<Movie> newMovies = results
          .map((json) => Movie.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _trendingMovies = newMovies;
          _isTrendingLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch trending: $e');
      if (mounted) {
        setState(() => _isTrendingLoading = false);
      }
    }
  }

  Future<void> _fetchDiscover({String? languageCode}) async {
    final lang = languageCode ?? await _firebaseService.getLanguage();
    // Removed the guard that was incorrectly blocking the initial fetch
    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint(
        'API TASK: Fetching Library All (Discover $_libraryType) for lang: $lang, Region: IN',
      );
      final data = await _apiService.fetchDiscover(
        _libraryType,
        _currentPage,
        languageCode: lang,
        region: 'IN', // Added region filter for India
      );
      final List<dynamic> results = data['results'] ?? [];
      final List<Movie> newMovies = results
          .map((json) => Movie.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _movies.addAll(newMovies);
          _currentPage++;
          if (_libraryType == 'movie') {
            _totalMoviesCount = data['total_results'] ?? 0;
          } else {
            _totalSeriesCount = data['total_results'] ?? 0;
          }
          _hasMore = _currentPage <= (data['total_pages'] ?? 0);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch library discover: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load library content.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _fetchDiscover(languageCode: languageCode),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchDiscoverTab({String? languageCode}) async {
    final lang = languageCode ?? await _firebaseService.getLanguage();
    if (mounted) setState(() => _isDiscoverLoading = true);

    try {
      debugPrint(
        'API TASK: Fetching Discover Tab ($_discoverType) for lang: $lang, Page: $_discoverPage',
      );
      final data = await _apiService.fetchDiscover(
        _discoverType,
        _discoverPage,
        genreId: _selectedGenreId,
        languageCode: lang,
      );
      final List<dynamic> results = data['results'] ?? [];
      final List<Movie> newMovies = results
          .map((json) => Movie.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _discoverMovies.addAll(newMovies);
          _discoverPage++;
          _discoverHasMore = _discoverPage <= (data['total_pages'] ?? 0);
          _isDiscoverLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch discover tab: $e');
      if (mounted) setState(() => _isDiscoverLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _discoverScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoading &&
        _hasMore) {
      _fetchDiscover();
    }
  }

  void _onDiscoverScroll() {
    if (_discoverScrollController.position.pixels >=
            _discoverScrollController.position.maxScrollExtent - 400 &&
        !_isDiscoverLoading &&
        _discoverHasMore) {
      _fetchDiscoverTab();
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBodyContent()),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_rounded),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildLibraryTab();
      case 2:
        return _buildDiscoverTab();
      case 3:
        return _buildStatsTab();
      default:
        return const Center(
          child: Text('Coming Soon', style: TextStyle(color: Colors.white)),
        );
    }
  }

  Widget _buildHomeTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _firebaseService.getLibraryStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                _buildStatsRow(stats),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TRENDING THIS WEEK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    _buildTypeDropdown(_homeType, (val) {
                      if (val != null) {
                        setState(() {
                          _homeType = val;
                          _trendingMovies.clear();
                        });
                        _fetchTrending();
                      }
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTrendingGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildTypeDropdown(_libraryType, (val) {
                    if (val != null) {
                      setState(() {
                        _libraryType = val;
                        _movies.clear();
                        _currentPage = 1;
                        _hasMore = true;
                      });
                      _fetchDiscover();
                    }
                  }),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              Column(
                children: [
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    tabs: const [
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('All'),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Watching'),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Completed'),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Bucket List'),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Favorite'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMovieGrid(
            movies: _movies,
            controller: _scrollController,
            type: _libraryType,
          ),
          _buildFirestoreStreamGrid(
            _firebaseService.getWatchingStream(),
            'No watching items',
          ),
          _buildFirestoreStreamGrid(
            _firebaseService.getCompletedStream(),
            'No completed items',
          ),
          _buildFirestoreStreamGrid(
            _firebaseService.getWatchlistStream(),
            'No bucket list items',
          ),
          _buildFavoritesTab(),
        ],
      ),
    );
  }

  Widget _buildFirestoreStreamGrid(
    Stream<QuerySnapshot> stream,
    String emptyMessage,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildPlaceholder(emptyMessage);
        }
        final docs = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final movie = Movie(
              id: data['id'],
              title: data['title'] ?? data['name'] ?? 'Unknown',
              posterPath: data['poster_path'] ?? data['still_path'] ?? '',
              releaseDate: '',
              voteAverage: 0,
              overview: '',
            );
            final type = data['type'] ?? 'movie';
            return _buildMovieCard(movie, type);
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getFavoritesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildPlaceholder('No favorites yet');
        }
        final favDocs = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: favDocs.length,
          itemBuilder: (context, index) {
            final data = favDocs[index].data() as Map<String, dynamic>;
            final movie = Movie(
              id: data['id'],
              title: data['title'] ?? data['name'] ?? 'Unknown',
              posterPath: data['poster_path'] ?? data['still_path'] ?? '',
              releaseDate: '',
              voteAverage: 0,
              overview: '',
            );
            final type = data['type'] ?? 'movie';
            return Stack(
              children: [
                _buildMovieCard(movie, type),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () {
                      _firebaseService.toggleFavorite(
                        id: movie.id,
                        type: type,
                        details: data,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildTypeDropdown(_discoverType, (val) {
                if (val != null) {
                  setState(() {
                    _discoverType = val;
                    _discoverMovies.clear();
                    _discoverPage = 1;
                    _discoverHasMore = true;
                    _selectedGenreId = null;
                  });
                  _fetchGenres();
                  _fetchDiscoverTab();
                }
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search shows & Movies',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        _buildGenreTabBar(),
        const SizedBox(height: 10),
        Expanded(
          child: _buildMovieGrid(
            movies: _discoverMovies,
            controller: _discoverScrollController,
            type: _discoverType,
            isLoading: _isDiscoverLoading,
            hasMore: _discoverHasMore,
          ),
        ),
      ],
    );
  }

  Widget _buildGenreTabBar() {
    if (_isGenresLoading) return const SizedBox(height: 35);
    return SizedBox(
      height: 35,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bool isAll = index == 0;
          final genre = isAll ? null : _genres[index - 1];
          final bool isSelected = isAll
              ? _selectedGenreId == null
              : _selectedGenreId == genre['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedGenreId = isAll ? null : genre['id'];
                _discoverMovies.clear();
                _discoverPage = 1;
                _discoverHasMore = true;
              });
              _fetchDiscoverTab();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: Colors.white24),
              ),
              child: Center(
                child: Text(
                  isAll ? 'All' : genre['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeDropdown(String value, Function(String?) onChanged) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1E1E1E),
        underline: const SizedBox(),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white54,
          size: 18,
        ),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        onChanged: onChanged,
        items: const [
          DropdownMenuItem(value: 'movie', child: Text('Movies')),
          DropdownMenuItem(value: 'tv', child: Text('Series')),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _firebaseService.getLibraryStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Stats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              _buildMainWatchTimeCard(stats['watchTimeHrs'] ?? '0.0'),
              const SizedBox(height: 25),
              _buildWatchTimeBreakdown(
                stats['movieMinutes'] ?? 0,
                stats['tvMinutes'] ?? 0,
              ),
              const SizedBox(height: 25),
              _buildCompletionCard(stats['completionRate'] ?? 0.0),
              const SizedBox(height: 30),
              _buildSectionTitle('Movie Insights'),
              _buildSmallStatCard(
                stats['movies']?.toString() ?? '0',
                'Movies Finished',
              ),
              _buildGenreReport(
                stats['topMovieGenres'] as List?,
                'Top Movie Genres',
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('TV Series Insights'),
              _buildSmallStatCard(
                stats['shows']?.toString() ?? '0',
                'Series Finished',
              ),
              _buildGenreReport(stats['topTvGenres'] as List?, 'Top TV Genres'),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMainWatchTimeCard(String watchTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(10), Colors.white.withAlpha(5)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            '$watchTime hrs',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'TOTAL TIME WATCHED',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchTimeBreakdown(int movieMins, int tvMins) {
    final total = movieMins + tvMins;
    final moviePct = total == 0 ? 0.0 : movieMins / total;
    final tvPct = total == 0 ? 0.0 : tvMins / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Watch Time Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: (moviePct * 100).toInt().clamp(1, 100),
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: (tvPct * 100).toInt().clamp(1, 100),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(
                'Movies',
                Colors.white,
                '${(moviePct * 100).toInt()}%',
              ),
              _buildLegendItem(
                'Series',
                Colors.white.withAlpha(50),
                '${(tvPct * 100).toInt()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard(double rate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  color: Colors.greenAccent,
                ),
              ),
              Text(
                '${(rate * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library Efficiency',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Percentage of your watchlist items that you have finished.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreReport(List? topGenres, String title) {
    if (topGenres == null || topGenres.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...topGenres.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      g['name'],
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(g['percentage'] * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: g['percentage'],
                  backgroundColor: Colors.white10,
                  color: Colors.white,
                  minHeight: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(String value, String label) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _firebaseService.getUserData(),
      builder: (context, snapshot) {
        final name = snapshot.data?['name'] ?? 'Alex Morgan';
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello,',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                _initializeData();
              },
              child: const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white12,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(stats['movies']?.toString() ?? '0', 'Movies'),
          _buildDivider(),
          _buildStatItem(stats['shows']?.toString() ?? '0', 'Series'),
          _buildDivider(),
          _buildStatItem(stats['watchTimeHrs'] ?? '0.0', 'Hrs Watch'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.white10);
  }

  Widget _buildTrendingGrid() {
    if (_isTrendingLoading)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    if (_trendingMovies.isEmpty)
      return _buildPlaceholder('No Trending Content');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _trendingMovies.length > 6 ? 6 : _trendingMovies.length,
      itemBuilder: (context, index) =>
          _buildMovieCard(_trendingMovies[index], _homeType),
    );
  }

  Widget _buildMovieGrid({
    List<Movie>? movies,
    ScrollController? controller,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    required String type,
    bool? isLoading,
    bool? hasMore,
  }) {
    final loading = isLoading ?? _isLoading;
    final more = hasMore ?? _hasMore;
    if (movies == null || movies.isEmpty) {
      if (loading)
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      return _buildPlaceholder('No Content Found');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: movies.length + (more ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == movies.length)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        return _buildMovieCard(movies[index], type);
      },
    );
  }

  Widget _buildMovieCard(Movie movie, String type) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MovieDetailScreen(movieId: movie.id, contentType: type),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: const Color(0xFF1E1E1E),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            movie.posterUrl,
            fit: BoxFit.cover,
            cacheWidth: 300,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.white10,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white24,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.movie, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(text, style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this.widget);
  final Widget widget;
  @override
  double get minExtent => 75;
  @override
  double get maxExtent => 75;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: Colors.black,
    height: 75,
    alignment: Alignment.center,
    child: widget,
  );
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
