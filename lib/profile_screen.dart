import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedLanguage = 'en';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en'},
    {'name': 'Tamil', 'code': 'ta'},
    {'name': 'Telugu', 'code': 'te'},
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Malayalam', 'code': 'ml'},
    {'name': 'Kannada', 'code': 'kn'},
    {'name': 'Korean', 'code': 'ko'},
    {'name': 'Japanese', 'code': 'ja'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'German', 'code': 'de'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final lang = await _firebaseService.getLanguage();
    if (mounted) {
      setState(() {
        _selectedLanguage = lang;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _firebaseService.getUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(userData),
                const SizedBox(height: 40),
                const Text(
                  'Content Language',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                _buildLanguageGrid(),
                const SizedBox(height: 40),
                _buildLogoutButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(Map<String, dynamic>? userData) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white12,
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userData?['name'] ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              userData?['email'] ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: _languages.length,
      itemBuilder: (context, index) {
        final lang = _languages[index];
        final isSelected = _selectedLanguage == lang['code'];
        return GestureDetector(
          onTap: () async {
            setState(() {
              _selectedLanguage = lang['code']!;
            });
            await _firebaseService.setLanguage(lang['code']!);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? null : Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                lang['name']!,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await _firebaseService.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
