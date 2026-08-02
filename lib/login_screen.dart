import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'dashboard_screen.dart';
import 'firebase_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController1;
  late ScrollController _scrollController2;
  late ScrollController _scrollController3;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isLoading = false;
  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();

  List<String> _trendingPosters = [];
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController1 = ScrollController();
    _scrollController2 = ScrollController();
    _scrollController3 = ScrollController();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    
    _fetchTrendingPosters();
    _fadeController.forward();

    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  Future<void> _fetchTrendingPosters() async {
    try {
      final data = await _apiService.fetchTrending('movie', 1);
      final List results = data['results'] ?? [];
      if (mounted) {
        setState(() {
          _trendingPosters = results
              .map((m) => 'https://image.tmdb.org/t/p/w342${m['poster_path']}')
              .where((url) => !url.contains('null'))
              .toList();
        });
        if (_trendingPosters.length >= 18) {
           _startAutoScroll();
        }
      }
    } catch (e) {
      debugPrint('Error fetching login posters: $e');
    }
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController1.hasClients) {
        _scrollController1.animateTo(_scrollController1.offset + 1, duration: const Duration(milliseconds: 50), curve: Curves.linear);
        if (_scrollController1.offset >= _scrollController1.position.maxScrollExtent) _scrollController1.jumpTo(0);
      }
      if (_scrollController2.hasClients) {
        _scrollController2.animateTo(_scrollController2.offset + 1.5, duration: const Duration(milliseconds: 50), curve: Curves.linear);
        if (_scrollController2.offset >= _scrollController2.position.maxScrollExtent) _scrollController2.jumpTo(0);
      }
      if (_scrollController3.hasClients) {
        _scrollController3.animateTo(_scrollController3.offset + 0.8, duration: const Duration(milliseconds: 50), curve: Curves.linear);
        if (_scrollController3.offset >= _scrollController3.position.maxScrollExtent) _scrollController3.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _fadeController.dispose();
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final userData = await _firebaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _firebaseService.saveUserData(userData);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_trendingPosters.length >= 18)
            Row(
              children: [
                Expanded(child: _buildScrollColumn(_scrollController1, _trendingPosters.sublist(0, 6))),
                Expanded(child: _buildScrollColumn(_scrollController2, _trendingPosters.sublist(6, 12))),
                Expanded(child: _buildScrollColumn(_scrollController3, _trendingPosters.sublist(12, 18))),
              ],
            ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 0.8, 1.0],
                colors: [
                  Colors.black.withAlpha(120), // Reduced opacity for clarity
                  Colors.black.withAlpha(80),  // Reduced opacity for clarity
                  Colors.black.withAlpha(180),
                  Colors.black,
                ],
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Reduced blur from 10 to 3
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Column(
                          children: [
                            const Text(
                              'MY MOVIE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w300,
                                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                              ),
                            ),
                            const Text(
                              'HUB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 72,
                                height: 1.0,
                                letterSpacing: -2,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 20),
                                  Shadow(color: Colors.amber, blurRadius: 40, offset: Offset(0, 0)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 40,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [BoxShadow(color: Colors.amber.withAlpha(200), blurRadius: 15, spreadRadius: 3)],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 60),
                        
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(220), // Increased card opacity to compensate for clearer background
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 40, spreadRadius: 10),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildLuxuryTextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                hintText: 'Access Email',
                                icon: Icons.alternate_email_rounded,
                                validator: (val) => val == null || val.isEmpty ? 'Email required' : null,
                              ),
                              const SizedBox(height: 20),
                              _buildLuxuryTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                hintText: 'Secure Password',
                                icon: Icons.lock_open_rounded,
                                isPassword: true,
                                validator: (val) => val == null || val.isEmpty ? 'Password required' : null,
                              ),
                              const SizedBox(height: 35),
                              _buildExploreButton(),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
                          child: RichText(
                            text: const TextSpan(
                              text: "DON'T HAVE ACCESS? ",
                              style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                              children: [
                                TextSpan(
                                  text: "JOIN NOW",
                                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollColumn(ScrollController controller, List<String> posters) {
    final displayPosters = [...posters, ...posters, ...posters];
    return ListView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayPosters.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(6.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(displayPosters[index], fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildExploreButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.amber.withAlpha(40), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withAlpha(200)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('EXPLORE HUB', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    bool isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isFocused ? Colors.black.withAlpha(240) : Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused ? Colors.amber.withAlpha(200) : Colors.white.withAlpha(60),
          width: 1.5,
        ),
        boxShadow: isFocused ? [BoxShadow(color: Colors.amber.withAlpha(60), blurRadius: 20)] : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isFocused ? Colors.amber : Colors.white70, size: 22),
          hintText: hintText.toUpperCase(),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}
