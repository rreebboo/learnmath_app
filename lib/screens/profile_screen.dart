import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/difficulty_reset_widget.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  
  const ProfileScreen({super.key, this.onBackPressed});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _soundEffects = true;
  bool _backgroundMusic = false;

  String get _userName => _userData?['name'] ?? _authService.getUserDisplayName() ?? 'Guest';
  String get _userAvatar => _userData?['avatar'] ?? '👧';
  int get _badgesEarned => _userData?['badgesEarned'] ?? 12;
  String get _gradeLevel => _userData?['gradeLevel'] ?? 'Grade 2 Student';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _firestoreService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B9EF3)),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Just let it pop normally, don't do anything special
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: SafeArea(
        child: Column(
          children: [
            // Header with wave design
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF5B9EF3),
                          Color(0xFF3F7FDB),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: WavePainter(),
                      child: Container(),
                    ),
                  ),
                  // Top bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                            onPressed: () {
                              if (widget.onBackPressed != null) {
                                widget.onBackPressed!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Text(
                            'My Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              _showSettingsDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Profile Card
                  Positioned(
                    bottom: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF7ED321).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _userAvatar,
                                style: TextStyle(fontSize: 35),
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _gradeLevel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Badges Card
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFFFA500),
                    Color(0xFFFF6B6B),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFFA500).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Badges',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_badgesEarned earned',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
            
            // Settings List
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 15),
                    
                    // Learning Style
                    _buildSettingCard(
                      icon: Icons.palette,
                      iconColor: Color(0xFF7ED321),
                      title: 'Learning Style',
                      subtitle: null,
                      onTap: () {
                        // Navigate to learning style
                      },
                    ),
                    
                    // Sound & Music
                    _buildSoundSettingCard(),
                    
                    // Difficulty Level
                    _buildSettingCard(
                      icon: Icons.speed,
                      iconColor: Color(0xFF5B9EF3),
                      title: 'Difficulty Level',
                      subtitle: 'Easy Mode',
                      onTap: () {
                        _showDifficultyDialog();
                      },
                    ),
                    
                    // Notifications
                    _buildSettingCard(
                      icon: Icons.notifications,
                      iconColor: Color(0xFF9C27B0),
                      title: 'Notifications',
                      subtitle: 'Parent Controls',
                      onTap: () {
                        // Navigate to notifications
                      },
                    ),
                    
                    SizedBox(height: 20),
                    Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 15),
                    
                    // How to Play
                    _buildSettingCard(
                      icon: Icons.play_circle_outline,
                      iconColor: Colors.grey[600]!,
                      title: 'How to Play',
                      subtitle: null,
                      onTap: () {
                        // Show tutorial
                      },
                    ),
                    
                    // Contact Support
                    _buildSettingCard(
                      icon: Icons.headset_mic,
                      iconColor: Colors.grey[600]!,
                      title: 'Contact Support',
                      subtitle: null,
                      onTap: () {
                        // Contact support
                      },
                    ),
                    
                    // Privacy & Safety
                    _buildSettingCard(
                      icon: Icons.security,
                      iconColor: Colors.red,
                      title: 'Privacy & Safety',
                      subtitle: null,
                      onTap: () {
                        // Privacy settings
                      },
                    ),
                    
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundSettingCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFFFFA500).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.music_note,
                  color: Color(0xFFFFA500),
                  size: 20,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Text(
                  'Sound & Music',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Sound Effects Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sound Effects',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Switch(
                value: _soundEffects,
                onChanged: (value) {
                  setState(() {
                    _soundEffects = value;
                  });
                },
                activeThumbColor: Color(0xFF7ED321),
              ),
            ],
          ),
          // Background Music Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Background Music',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Switch(
                value: _backgroundMusic,
                onChanged: (value) {
                  setState(() {
                    _backgroundMusic = value;
                  });
                },
                activeThumbColor: Color(0xFF7ED321),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedDifficulty = 'Easy';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Difficulty Level',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text('Easy'),
                    subtitle: Text('1-digit numbers'),
                    value: 'Easy',
                    groupValue: selectedDifficulty,
                    activeColor: Color(0xFF7ED321),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Medium'),
                    subtitle: Text('2-3 digit numbers'),
                    value: 'Medium',
                    groupValue: selectedDifficulty,
                    activeColor: Color(0xFFFFA500),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Hard'),
                    subtitle: Text('4+ digit numbers'),
                    value: 'Hard',
                    groupValue: selectedDifficulty,
                    activeColor: Color(0xFFFF6B6B),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDifficulty = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Save difficulty
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5B9EF3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Quick Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF5B9EF3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Color(0xFF5B9EF3),
                  ),
                ),
                title: Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditProfileDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.orange,
                  ),
                ),
                title: Text('Reset Difficulty'),
                subtitle: Text('Change your difficulty level'),
                onTap: () {
                  Navigator.pop(context);
                  _showDifficultyResetDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF7ED321).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Color(0xFF7ED321),
                  ),
                ),
                title: Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red,
                  ),
                ),
                title: Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(text: _userName);
    String tempAvatar = _userAvatar;
    final List<String> avatars = ['👧', '👦', '🦊', '🐶', '🐷', '🐱', '🐰', '🐼'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Edit Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Choose Avatar',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: avatars.length,
                      itemBuilder: (context, index) {
                        final avatar = avatars[index];
                        final isSelected = avatar == tempAvatar;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempAvatar = avatar;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 10),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Color(0xFF7ED321) : Colors.grey[200],
                              border: isSelected 
                                ? Border.all(color: Color(0xFF7ED321), width: 2)
                                : null,
                            ),
                            child: Center(
                              child: Text(
                                avatar,
                                style: TextStyle(fontSize: 25),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final userId = _authService.getUserId();
                      if (userId != null) {
                        await _firestoreService.updateUserProfile(
                          userId: userId,
                          name: nameController.text,
                          avatar: tempAvatar,
                        );
                        await _loadUserData();
                      }
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating profile: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7ED321),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7DD3FC), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '📚',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'About LearnMath',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          content: Text(
            'LearnMath is a fun and interactive app designed to help young learners master basic math skills through engaging games and exercises.\n\nVersion: 1.0.0\nDeveloped with Flutter & Firebase',
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5B9EF3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error signing out: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDifficultyResetDialog() async {
    final result = await DifficultyResetDialog.show(context);
    if (result == true) {
      // Reload user data if reset was successful
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Difficulty level has been reset successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// Custom Wave Painter for the header design
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.55,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}