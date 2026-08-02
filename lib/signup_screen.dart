import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'firebase_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController1;
  late ScrollController _scrollController2;
  late ScrollController _scrollController3;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _mobileFocus = FocusNode();
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

    _nameFocus.addListener(() => setState(() {}));
    _mobileFocus.addListener(() => setState(() {}));
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
        if (_trendingPosters.length >= 18) _startAutoScroll();
      }
    } catch (e) {
      debugPrint('Error fetching signup posters: $e');
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
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _mobileFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await _firebaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created! Please login.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
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
                stops: const [0.0, 0.3, 0.7, 1.0],
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
                        const Text(
                          'JOIN THE HUB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 10),
                              Shadow(color: Colors.amber, blurRadius: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 40, height: 2,
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(1)),
                        ),
                        const SizedBox(height: 50),
                        
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(220), // Increased card opacity
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 40, spreadRadius: 10),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildLuxuryTextField(controller: _nameController, focusNode: _nameFocus, hintText: 'Your Name', icon: Icons.person_outline_rounded),
                              const SizedBox(height: 15),
                              _buildLuxuryTextField(controller: _mobileController, focusNode: _mobileFocus, hintText: 'Mobile No', icon: Icons.phone_iphone_rounded, keyboardType: TextInputType.phone),
                              const SizedBox(height: 15),
                              _buildLuxuryTextField(controller: _emailController, focusNode: _emailFocus, hintText: 'Email ID', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 15),
                              _buildLuxuryTextField(controller: _passwordController, focusNode: _passwordFocus, hintText: 'Password', icon: Icons.lock_open_rounded, isPassword: true),
                              const SizedBox(height: 30),
                              _buildJoinButton(),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: const TextSpan(
                              text: "ALREADY A MEMBER? ",
                              style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1.5, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                              children: [TextSpan(text: "LOGIN", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900))],
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
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.all(6.0),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(displayPosters[index], fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildJoinButton() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.amber.withAlpha(40), blurRadius: 20, offset: const Offset(0, 10))],
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFEEEEEE)]),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.black, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
            : const Text('CREATE ACCOUNT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildLuxuryTextField({required TextEditingController controller, required FocusNode focusNode, required String hintText, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    bool isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isFocused ? Colors.black.withAlpha(240) : Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFocused ? Colors.amber.withAlpha(200) : Colors.white.withAlpha(40), width: 1.5),
        boxShadow: isFocused ? [BoxShadow(color: Colors.amber.withAlpha(60), blurRadius: 20)] : [],
      ),
      child: TextFormField(
        controller: controller, focusNode: focusNode, obscureText: isPassword, keyboardType: keyboardType,
        validator: validator ?? (val) => val == null || val.isEmpty ? '$hintText required' : null,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isFocused ? Colors.amber : Colors.white70, size: 22),
          hintText: hintText.toUpperCase(),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1.5),
          filled: false, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}
