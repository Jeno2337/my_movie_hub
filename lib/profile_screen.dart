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
    if (mounted) setState(() => _selectedLanguage = lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _firebaseService.getUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(userData),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('ACCOUNT SETTINGS'),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          Icons.person_outline,
                          'Name',
                          userData?['name'] ?? 'User',
                        ),
                        _buildSettingsTile(
                          Icons.phone_iphone_rounded,
                          'Mobile',
                          userData?['mobile'] ?? 'N/A',
                        ),
                        _buildSettingsTile(
                          Icons.alternate_email_rounded,
                          'Email',
                          userData?['email'] ?? 'N/A',
                        ),
                      ]),
                      const SizedBox(height: 30),
                      _buildSectionHeader('PREFERENCES'),
                      _buildSettingsCard([_buildLanguageSelector()]),
                      const SizedBox(height: 30),
                      _buildSectionHeader('APP INFORMATION'),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          Icons.info_outline,
                          'Version',
                          '1.0.0',
                        ),
                      ]),
                      const SizedBox(height: 40),
                      _buildLogoutAction(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic>? userData) {
    return SliverAppBar(
      expandedHeight: 280,
      backgroundColor: Colors.black,
      pinned: true,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withAlpha(100),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withAlpha(50),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF1E1E1E),
                    child: Icon(Icons.person, size: 60, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  (userData?['name'] ?? 'USER').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  userData?['email'] ?? 'access@hub.com',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String label,
    String value, {
    bool isAction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.withAlpha(200), size: 22),
          const SizedBox(width: 15),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isAction ? Colors.amber : Colors.white24,
              fontSize: 14,
              fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isAction)
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.amber,
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Icon(
                Icons.translate_rounded,
                color: Colors.amber.withAlpha(200),
                size: 22,
              ),
              const SizedBox(width: 15),
              const Text(
                'Content Language',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _languages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final lang = _languages[index];
              final isSelected = _selectedLanguage == lang['code'];
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedLanguage = lang['code']!);
                  await _firebaseService.setLanguage(lang['code']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      lang['name']!,
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
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildLogoutAction() {
    return GestureDetector(
      onTap: () async {
        await _firebaseService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withAlpha(40)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 10),
            Text(
              'LOGOUT ACCOUNT',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
