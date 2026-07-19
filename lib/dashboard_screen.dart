import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'firebase_service.dart';
import 'movie_detail_screen.dart';
import 'movie_model.dart';

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
    await _fetchTrending();
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _fetchDiscover();
      await Future.delayed(const Duration(milliseconds: 300));
      _fetchGenres();
      _fetchDiscoverTab();
    }
  }

  Future<void> _fetchGenres() async {
    if (mounted) setState(() => _isGenresLoading = true);
    try {
      final data = await _apiService.fetchGenres(_discoverType);
      if (mounted) {
        setState(() {
          _genres = data['genres'] ?? [];
          _isGenresLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isGenresLoading = false);
    }
  }

  Future<void> _fetchTrending() async {
    if (_isTrendingLoading) return;
    if (mounted) setState(() => _isTrendingLoading = true);

    try {
      final timeWindow = _homeType == 'tv' ? 'week' : 'day';
      final data = await _apiService.fetchTrending(
        _homeType,
        1,
        timeWindow: timeWindow,
      );
      final List<dynamic> results = data['results'];
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
      if (mounted) {
        setState(() {
          _isTrendingLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchTrending,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchDiscover() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final data = await _apiService.fetchDiscover(_libraryType, _currentPage);
      final List<dynamic> results = data['results'];
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchDiscover,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchDiscoverTab() async {
    if (_isDiscoverLoading) return;
    if (mounted) setState(() => _isDiscoverLoading = true);

    try {
      final data = await _apiService.fetchDiscover(
        _discoverType,
        _discoverPage,
        genreId: _selectedGenreId,
      );
      final List<dynamic> results = data['results'];
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
      if (mounted) {
        setState(() {
          _isDiscoverLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _fetchDiscoverTab,
              textColor: Colors.white,
            ),
          ),
        );
      }
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
            label: 'Statistic',
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
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            _buildStatsRow(),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TRENDING THIS WEEK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                _buildTypeDropdown(_homeType, (val) {
                  if (val != null) {
                    setState(() {
                      _homeType = val;
                      _trendingMovies = [];
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
  }

  Widget _buildLibraryTab() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
                  if (_tabController.index != 4)
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    onTap: (index) => setState(() {}),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.white.withAlpha(51),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    tabs: const [
                      Tab(
                        height: 35,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('All'),
                        ),
                      ),
                      Tab(
                        height: 35,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Watching'),
                        ),
                      ),
                      Tab(
                        height: 35,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Completed'),
                        ),
                      ),
                      Tab(
                        height: 35,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Watchlist'),
                        ),
                      ),
                      Tab(
                        height: 35,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Favorite'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
          _buildPlaceholder('Watching'),
          _buildPlaceholder('Completed'),
          _buildPlaceholder('Watchlist'),
          _buildFavoritesTab(),
        ],
      ),
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
              title: data['title'],
              posterPath: data['poster_path'],
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
                        movie.id,
                        type,
                        movie.title,
                        movie.posterPath ?? '',
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
    if (_isGenresLoading) {
      return const SizedBox(height: 35);
    }
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
          Center(
            child: Container(
              width: 350,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '840 hrs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Total Watch Time',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            children: [
              _buildSmallStatCard('2,450', 'Episodes'),
              _buildSmallStatCard(_formatCount(_totalSeriesCount), 'Shows'),
              _buildSmallStatCard(_formatCount(_totalMoviesCount), 'Movies'),
              _buildSmallStatCard('18', 'Favorite'),
              _buildSmallStatCard('5', 'Watching'),
              _buildSmallStatCard('112', 'Completed'),
            ],
          ),
          _buildGenreReport(),
        ],
      ),
    );
  }

  Widget _buildGenreReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          'Top Genres',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildGenreRow('Action', 0.85, '85%'),
              _buildGenreRow('Drama', 0.65, '65%'),
              _buildGenreRow('Comedy', 0.45, '45%'),
              _buildGenreRow('Sci-Fi', 0.30, '30%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenreRow(String genre, double percentage, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(genre, style: const TextStyle(color: Colors.white70)),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.white12,
            color: Colors.white,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String value, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
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
            const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white12,
              child: ClipOval(
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

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(_formatCount(_totalMoviesCount), 'Movies'),
          _buildDivider(),
          _buildStatItem(_formatCount(_totalSeriesCount), 'Series'),
          _buildDivider(),
          _buildStatItem('840', 'Hrs Watch'),
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
      if (loading) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
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
        if (index == movies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        }
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
  double get minExtent => 54;
  @override
  double get maxExtent => 54;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(
    color: Colors.black,
    height: 54,
    alignment: Alignment.center,
    child: widget,
  );
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
