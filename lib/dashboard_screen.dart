import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
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

  final List<Movie> _movies = [];
  List<Movie> _trendingMovies = [];
  final List<Movie> _discoverMovies = [];
  final List<Movie> _searchResults = [];
  List<dynamic> _genres = [];

  int _currentPage = 1;
  int _discoverPage = 1;
  int _searchPage = 1;
  int _totalMoviesCount = 0;
  int _totalSeriesCount = 0;
  int? _selectedGenreId;

  int _totalPages = 1;
  int _discoverTotalPages = 1;
  int _searchTotalPages = 1;

  bool _isLoading = false;
  bool _isTrendingLoading = false;
  bool _isDiscoverLoading = false;
  bool _isGenresLoading = false;
  bool _isSearchLoading = false;

  bool _isSearching = false;

  String _homeType = 'movie';
  String _libraryType = 'movie';
  String _discoverType = 'movie';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeData();
  }

  Future<void> _performSearch(String query, {int page = 1}) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
      _searchPage = page;
    });

    try {
      debugPrint('API TASK: Performing Multi-Search for "$query", Page: $page');
      final data = await _apiService.searchMulti(query, page);
      final List results = data['results'] ?? [];

      if (mounted) {
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(
            results
                .where(
                  (m) => m['media_type'] == 'movie' || m['media_type'] == 'tv',
                )
                .map((m) => Movie.fromJson(m))
                .toList(),
          );
          _searchTotalPages = data['total_pages'] ?? 1;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Search failed: $e');
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  Future<void> _initializeData() async {
    final language = await _firebaseService.getLanguage();
    setState(() {
      _isLoading = false;
      _isTrendingLoading = false;
      _isDiscoverLoading = false;
      _movies.clear();
      _trendingMovies.clear();
      _discoverMovies.clear();
      _currentPage = 1;
      _discoverPage = 1;
      _isSearching = false;
      _searchController.clear();
    });

    _fetchGenres();
    _fetchTrending(languageCode: language);
    _fetchDiscover(page: 1, languageCode: language);
    _fetchDiscoverTab(page: 1, languageCode: language);
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

  Future<void> _fetchDiscover({int page = 1, String? languageCode}) async {
    final lang = languageCode ?? await _firebaseService.getLanguage();
    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint('API TASK: Fetching Library All, Page: $page, Region: IN');
      final data = await _apiService.fetchDiscover(
        _libraryType,
        page,
        languageCode: lang,
        region: 'IN',
      );
      final List<dynamic> results = data['results'] ?? [];
      final List<Movie> newMovies = results
          .map((json) => Movie.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _movies.clear();
          _movies.addAll(newMovies);
          _currentPage = page;
          _totalPages = data['total_pages'] ?? 1;
          if (_libraryType == 'movie') {
            _totalMoviesCount = data['total_results'] ?? 0;
          } else {
            _totalSeriesCount = data['total_results'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch library discover: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDiscoverTab({int page = 1, String? languageCode}) async {
    final lang = languageCode ?? await _firebaseService.getLanguage();
    if (mounted) setState(() => _isDiscoverLoading = true);

    try {
      debugPrint('API TASK: Fetching Discover Tab, Page: $page');
      final data = await _apiService.fetchDiscover(
        _discoverType,
        page,
        genreId: _selectedGenreId,
        languageCode: lang,
      );
      final List<dynamic> results = data['results'] ?? [];
      final List<Movie> newMovies = results
          .map((json) => Movie.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _discoverMovies.clear();
          _discoverMovies.addAll(newMovies);
          _discoverPage = page;
          _discoverTotalPages = data['total_pages'] ?? 1;
          if (_discoverType == 'movie') {
            _totalMoviesCount = data['total_results'] ?? 0;
          } else {
            _totalSeriesCount = data['total_results'] ?? 0;
          }
          _isDiscoverLoading = false;
        });
      }
    } catch (e) {
      debugPrint('API ERROR: Failed to fetch discover tab: $e');
      if (mounted) {
        setState(() => _isDiscoverLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
                      });
                      _fetchDiscover(page: 1);
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
            type: _libraryType,
            isLoading: _isLoading,
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: (p) => _fetchDiscover(page: p),
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
        if (snapshot.hasError) {
          debugPrint('Firestore Stream Error: ${snapshot.error}');
          return _buildPlaceholder('Error loading data');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        // Manual filtering to avoid Firestore Index requirements
        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? 'movie';
          if (_libraryType == 'tv') {
            return type == 'tv' || type == 'episode';
          }
          return type == 'movie';
        }).toList();

        if (docs.isEmpty) {
          return _buildPlaceholder(emptyMessage);
        }

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
        if (snapshot.hasError) {
          debugPrint('Firestore Stream Error: ${snapshot.error}');
          return _buildPlaceholder('Error loading data');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        // Manual filtering to avoid Firestore Index requirements
        final allDocs = snapshot.data?.docs ?? [];
        final favDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? 'movie';
          if (_libraryType == 'tv') {
            return type == 'tv' || type == 'episode';
          }
          return type == 'movie';
        }).toList();

        if (favDocs.isEmpty) {
          return _buildPlaceholder('No favorites yet');
        }

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
              Text(
                _isSearching ? 'Results' : 'Discover',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isSearching)
                _buildTypeDropdown(_discoverType, (val) {
                  if (val != null) {
                    setState(() {
                      _discoverType = val;
                      _discoverMovies.clear();
                      _discoverPage = 1;
                      _selectedGenreId = null;
                    });
                    _fetchGenres();
                    _fetchDiscoverTab(page: 1);
                  }
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => _performSearch(val, page: 1),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search shows & Movies',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('', page: 1);
                      },
                    )
                  : null,
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
        if (!_isSearching) ...[const SizedBox(height: 15), _buildGenreTabBar()],
        const SizedBox(height: 10),
        Expanded(
          child: _isSearching
              ? _buildMovieGrid(
                  movies: _searchResults,
                  type: 'movie',
                  isLoading: _isSearchLoading,
                  currentPage: _searchPage,
                  totalPages: _searchTotalPages,
                  onPageChanged: (p) =>
                      _performSearch(_searchController.text, page: p),
                )
              : _buildMovieGrid(
                  movies: _discoverMovies,
                  type: _discoverType,
                  isLoading: _isDiscoverLoading,
                  currentPage: _discoverPage,
                  totalPages: _discoverTotalPages,
                  onPageChanged: (p) => _fetchDiscoverTab(page: p),
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
              });
              _fetchDiscoverTab(page: 1);
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
              const SizedBox(height: 35),

              _buildSectionTitle('Weekly Watch Trends'),
              _buildWeeklyLineChart(stats['weeklyData'] as Map<int, int>?),
              const SizedBox(height: 35),

              _buildSectionTitle('Monthly Activity'),
              _buildMonthlyBarChart(stats['monthlyData'] as Map<int, int>?),
              const SizedBox(height: 35),

              _buildSectionTitle('Bucket List Status'),
              _buildBucketListDashboard(stats),
              const SizedBox(height: 20),
              _buildBucketListChart(stats),
              const SizedBox(height: 35),

              _buildSectionTitle('Recently Favorited'),
              _buildRecentFavorites(stats['recentFavs'] as List?),
              const SizedBox(height: 35),

              _buildSectionTitle('Your Cinema DNA'),
              _buildCinemaArchetype(stats['allFavGenres'] as List?),
              const SizedBox(height: 15),
              _buildFavoriteRadarChart(stats['allFavGenres'] as List?),
              const SizedBox(height: 25),
              _buildGenreDNAChips(stats['allFavGenres'] as List?),
              const SizedBox(height: 35),

              _buildSectionTitle('Movie Genre Breakdown'),
              _buildFullGenreReport(stats['allMovieGenres'] as List?),
              const SizedBox(height: 35),

              _buildSectionTitle('Series Genre Breakdown'),
              _buildFullGenreReport(stats['allTvGenres'] as List?),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyLineChart(Map<int, int>? data) {
    if (data == null) return const SizedBox(height: 150);

    final List<FlSpot> spots = [];
    for (int i = 1; i <= 7; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i] ?? 0) / 60.0));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  if (val < 1 || val > 7) return const Text('');
                  return Text(
                    days[val.toInt() - 1],
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) => Text(
                  '${val.toInt()}h',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent.withAlpha(50),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBarChart(Map<int, int>? data) {
    if (data == null) return const SizedBox(height: 150);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  return Text(
                    'Week ${val.toInt()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [1, 2, 3, 4, 5]
              .map(
                (w) => BarChartGroupData(
                  x: w,
                  barRods: [
                    BarChartRodData(
                      toY: (data[w] ?? 0) / 60.0,
                      color: Colors.white,
                      width: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBucketListDashboard(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallStatCard(
            stats['watchlist']?.toString() ?? '0',
            'Pending in Bucket',
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSmallStatCard(
            '${((stats['completionRate'] ?? 0.0) * 100).toInt()}%',
            'Completion Velocity',
          ),
        ),
      ],
    );
  }

  Widget _buildBucketListChart(Map<String, dynamic> stats) {
    final int pending = stats['watchlist'] ?? 0;
    final int completed = stats['completed'] ?? 0;
    final int total = pending + completed;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(
                    value: pending.toDouble(),
                    title: '',
                    color: Colors.white.withAlpha(50),
                    radius: 12,
                  ),
                  PieChartSectionData(
                    value: completed.toDouble(),
                    title: '',
                    color: Colors.greenAccent,
                    radius: 15,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartLegend('Completed', Colors.greenAccent, completed),
                const SizedBox(height: 12),
                _buildChartLegend(
                  'Still in Bucket',
                  Colors.white.withAlpha(50),
                  pending,
                ),
                const Divider(height: 25, color: Colors.white12),
                Text(
                  'Total Managed: $total',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCinemaArchetype(List? genres) {
    if (genres == null || genres.isEmpty) return const SizedBox.shrink();

    final topGenre = genres[0]['name'];
    String archetype = "The Cinematic Explorer";
    String description =
        "You have a diverse taste and love exploring all kinds of stories.";

    switch (topGenre) {
      case 'Action':
        archetype = "The Action Aficionado";
        description =
            "Adrenaline is your middle name. You live for the thrills and big-screen spectacle.";
        break;
      case 'Comedy':
        archetype = "The Laughter Seeker";
        description =
            "You believe a day without laughter is a day wasted. Comedy is your escape.";
        break;
      case 'Drama':
        archetype = "The Soul Searcher";
        description =
            "You're drawn to deep, meaningful stories and complex characters that touch the heart.";
        break;
      case 'Science Fiction':
        archetype = "The Future Voyager";
        description =
            "Your mind is always in the stars. You love exploring the 'what ifs' of tomorrow.";
        break;
      case 'Horror':
        archetype = "The Thrill Chaser";
        description =
            "You love the edge-of-your-seat excitement that only a good scare can provide.";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withAlpha(40), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            archetype.toUpperCase(),
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGenreColor(String name) {
    switch (name) {
      case 'Action':
        return Colors.redAccent;
      case 'Comedy':
        return Colors.orangeAccent;
      case 'Drama':
        return Colors.blueAccent;
      case 'Science Fiction':
        return Colors.cyanAccent;
      case 'Horror':
        return Colors.deepPurpleAccent;
      case 'Adventure':
        return Colors.greenAccent;
      case 'Animation':
        return Colors.pinkAccent;
      case 'Crime':
        return Colors.grey;
      case 'Fantasy':
        return Colors.indigoAccent;
      case 'Thriller':
        return Colors.tealAccent;
      default:
        return Colors.amber;
    }
  }

  Widget _buildFavoriteRadarChart(List? genres) {
    if (genres == null || genres.length < 3) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Favorite at least 3 items to unlock Radar Chart',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
      );
    }

    // Take top 6 for the radar symmetry
    final topGenres = genres.take(6).toList();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(25),
      ),
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: Colors.amber.withAlpha(50),
              borderColor: Colors.amber,
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: topGenres
                  .map((e) => RadarEntry(value: (e['count'] as int).toDouble()))
                  .toList(),
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: const BorderSide(color: Colors.white10),
          titlePositionPercentageOffset: 0.2,
          titleTextStyle: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          getTitle: (index, angle) {
            return RadarChartTitle(
              text: topGenres[index]['name'],
              angle: angle,
            );
          },
          tickCount: 3,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          gridBorderData: const BorderSide(color: Colors.white10, width: 1),
        ),
      ),
    );
  }

  Widget _buildGenreDNAChips(List? genres) {
    if (genres == null || genres.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: genres.map((g) {
        final color = _getGenreColor(g['name']);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(100),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                g['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '×${g['count']}',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentFavorites(List? recentFavs) {
    if (recentFavs == null || recentFavs.isEmpty) {
      return const Text(
        'No favorites yet',
        style: TextStyle(color: Colors.white24),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentFavs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final fav = recentFavs[index];
          final type = fav['type'] ?? 'movie';
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailScreen(movieId: fav['id'], contentType: type),
              ),
            ),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(
                    'https://image.tmdb.org/t/p/w185${fav['poster_path'] ?? fav['still_path']}',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullGenreReport(List? genres) {
    if (genres == null || genres.isEmpty) {
      return const Text(
        'No genre data available',
        style: TextStyle(color: Colors.white24),
      );
    }
    return Column(
      children: genres
          .map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        g['name'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${g['count']} items (${(g['percentage'] * 100).toInt()}%)',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: g['percentage'],
                    backgroundColor: Colors.white.withAlpha(10),
                    color: Colors.white70,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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

  Widget _buildSmallStatCard(String value, String label) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
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
    if (_isTrendingLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (_trendingMovies.isEmpty) {
      return _buildPlaceholder('No Trending Content');
    }
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
    required String type,
    bool isLoading = false,
    required int currentPage,
    required int totalPages,
    required Function(int) onPageChanged,
  }) {
    if (movies == null || movies.isEmpty) {
      if (isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      return _buildPlaceholder('No Content Found');
    }

    return Column(
      children: [
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, index) =>
                      _buildMovieCard(movies[index], type),
                ),
        ),
        _buildNumberedPagination(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }

  Widget _buildNumberedPagination({
    required int currentPage,
    required int totalPages,
    required Function(int) onPageChanged,
  }) {
    if (totalPages <= 1) return const SizedBox.shrink();

    // Responsive: Show max 5 buttons on mobile
    List<int> pages = [];
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      if (currentPage <= 3) {
        pages = [1, 2, 3, 4, 5];
      } else if (currentPage >= totalPages - 2) {
        pages = [
          totalPages - 4,
          totalPages - 3,
          totalPages - 2,
          totalPages - 1,
          totalPages,
        ];
      } else {
        pages = [
          currentPage - 2,
          currentPage - 1,
          currentPage,
          currentPage + 1,
          currentPage + 2,
        ];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous
            _buildPageButton(
              label: 'Prev',
              onTap: currentPage > 1
                  ? () => onPageChanged(currentPage - 1)
                  : null,
              isActive: false,
            ),
            const SizedBox(width: 5),

            // Numbers
            ...pages.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildPageButton(
                  label: p.toString(),
                  onTap: () => onPageChanged(p),
                  isActive: p == currentPage,
                ),
              ),
            ),

            const SizedBox(width: 5),
            // Next
            _buildPageButton(
              label: 'Next',
              onTap: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              isActive: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageButton({
    required String label,
    VoidCallback? onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.white : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, String type) {
    return GestureDetector(
      onTap: () {
        // Correct navigation for search results which can be either movies or tv
        String effectiveType = type;
        if (_isSearching) {
          // If title is not empty, it's likely a movie in our current Movie model mapping
          // (TMDB 'name' maps to series, 'title' maps to movie)
          effectiveType = movie.title.isNotEmpty ? 'movie' : 'tv';
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(
              movieId: movie.id,
              contentType: effectiveType,
            ),
          ),
        );
      },
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
