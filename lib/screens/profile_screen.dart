import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/progression_service.dart';
import '../services/image_service.dart';
import '../widgets/difficulty_reset_widget.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  
  const ProfileScreen({super.key, this.onBackPressed});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImageService _imageService = ImageService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _soundEffects = true;
  bool _backgroundMusic = false;

  String get _userName => _userData?['name'] ?? _authService.getUserDisplayName() ?? 'Guest';
  String get _userAvatar => _userData?['avatar'] ?? '👧';
  int get _badgesEarned => _userData?['badgesEarned'] ?? 12;
  String get _gradeLevel => _userData?['gradeLevel'] ?? 'Grade 2 Student';
  int? get _userAge => _userData?['age'];
  String get _userSchool => _userData?['school'] ?? '';
  String get _userBio => _userData?['bio'] ?? '';

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
      print('ProfileScreen: Error loading user data: $e');
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
                              gradient: _imageService.isImageUrl(_userAvatar)
                                ? null
                                : LinearGradient(
                                    colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                                  ),
                              color: _imageService.isImageUrl(_userAvatar) ? Colors.white : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF7ED321).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _imageService.isImageUrl(_userAvatar)
                                ? Image.network(
                                    _userAvatar,
                                    fit: BoxFit.cover,
                                    width: 70,
                                    height: 70,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF7ED321), Color(0xFF9ACD32)],
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.person,
                                            size: 35,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      _userAvatar,
                                      style: TextStyle(fontSize: 35),
                                    ),
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
                                  _userAge != null
                                    ? '$_gradeLevel • Age $_userAge'
                                    : _gradeLevel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_userSchool.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    _userSchool,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
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
                    
                    // Edit Profile
                    _buildSettingCard(
                      icon: Icons.edit,
                      iconColor: Color(0xFF5B9EF3),
                      title: 'Edit Profile',
                      subtitle: 'Name, age & info',
                      onTap: () {
                        _showEditProfileDialog();
                      },
                    ),

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
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.restart_alt,
                    color: Colors.purple,
                  ),
                ),
                title: Text('Reset Progress'),
                subtitle: Text('Start math lessons from the beginning'),
                onTap: () {
                  Navigator.pop(context);
                  _showProgressResetDialog();
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
    TextEditingController ageController = TextEditingController(text: _userAge?.toString() ?? '');
    TextEditingController schoolController = TextEditingController(text: _userSchool);
    TextEditingController bioController = TextEditingController(text: _userBio);
    String tempAvatar = _userAvatar;
    String tempGradeLevel = _gradeLevel;

    final List<String> avatars = ['👧', '👦', '🦊', '🐶', '🐷', '🐱', '🐰', '🐼'];
    final List<String> gradeLevels = [
      'Pre-K Student',
      'Kindergarten Student',
      'Grade 1 Student',
      'Grade 2 Student',
      'Grade 3 Student',
      'Grade 4 Student',
      'Grade 5 Student',
      'Grade 6 Student'
    ];

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
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person, color: Color(0xFF5B9EF3)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF5B9EF3)),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Age Field
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.cake, color: Color(0xFF7ED321)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF7ED321)),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Grade Level Dropdown
                    Text(
                      'Grade Level',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C3E50),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tempGradeLevel,
                          isExpanded: true,
                          icon: Icon(Icons.school, color: Color(0xFFFFA500)),
                          items: gradeLevels.map((String grade) {
                            return DropdownMenuItem<String>(
                              value: grade,
                              child: Text(grade),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              tempGradeLevel = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // School Field
                    TextField(
                      controller: schoolController,
                      decoration: InputDecoration(
                        labelText: 'School (Optional)',
                        prefixIcon: Icon(Icons.school, color: Color(0xFFFFA500)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFFFA500)),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Bio Field
                    TextField(
                      controller: bioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'About Me (Optional)',
                        prefixIcon: Icon(Icons.info, color: Color(0xFF9C27B0)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF9C27B0)),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Avatar Selection
                    Text(
                      'Choose Avatar',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C3E50),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Upload Photo Options
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final XFile? image = await _imageService.pickImageFromGallery();
                                if (image != null) {
                                  // Show loading indicator
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  // Upload image
                                  final imageUrl = await _imageService.uploadProfileImage(image);
                                  Navigator.pop(context); // Close loading

                                  setDialogState(() {
                                    tempAvatar = imageUrl;
                                  });
                                }
                              } catch (e) {
                                Navigator.of(context).pop(); // Close loading if open
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error uploading image: $e')),
                                );
                              }
                            },
                            icon: Icon(Icons.photo_library, size: 16),
                            label: Text('Gallery', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF5B9EF3),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final XFile? image = await _imageService.pickImageFromCamera();
                                if (image != null) {
                                  // Show loading indicator
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  // Upload image
                                  final imageUrl = await _imageService.uploadProfileImage(image);
                                  Navigator.pop(context); // Close loading

                                  setDialogState(() {
                                    tempAvatar = imageUrl;
                                  });
                                }
                              } catch (e) {
                                Navigator.of(context).pop(); // Close loading if open
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error taking photo: $e')),
                                );
                              }
                            },
                            icon: Icon(Icons.camera_alt, size: 16),
                            label: Text('Camera', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF7ED321),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // Current Avatar Preview
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: Color(0xFF7ED321), width: 2),
                        ),
                        child: ClipOval(
                          child: _imageService.isImageUrl(tempAvatar)
                            ? Image.network(
                                tempAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.person, size: 40, color: Colors.grey);
                                },
                              )
                            : Center(
                                child: Text(
                                  tempAvatar,
                                  style: TextStyle(fontSize: 35),
                                ),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),

                    // Emoji Avatar Options
                    Text(
                      'Or choose an emoji avatar:',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 50,
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
                              margin: EdgeInsets.only(right: 8),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? Color(0xFF7ED321).withValues(alpha: 0.2) : Colors.grey[100],
                                border: isSelected
                                  ? Border.all(color: Color(0xFF7ED321), width: 2)
                                  : Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  avatar,
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ],
                  ),
                ),
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
                    // Validate age input
                    int? age;
                    if (ageController.text.isNotEmpty) {
                      age = int.tryParse(ageController.text);
                      if (age == null || age < 3 || age > 18) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid age between 3 and 18')),
                        );
                        return;
                      }
                    }

                    // Validate name
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Name cannot be empty')),
                      );
                      return;
                    }

                    try {
                      await _firestoreService.updateCurrentUserProfile(
                        name: nameController.text.trim(),
                        avatar: tempAvatar,
                        age: age,
                        gradeLevel: tempGradeLevel,
                        school: schoolController.text.trim(),
                        bio: bioController.text.trim(),
                      );
                      await _loadUserData();
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Profile updated successfully!'),
                            backgroundColor: Color(0xFF7ED321),
                          ),
                        );
                      }
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

  void _showProgressResetDialog() async {
    final progressionService = ProgressionService.instance;
    
    // Check if user has any progress first
    bool hasProgress = await progressionService.hasAnyProgress();
    
    if (!hasProgress) {
      // Show info that no progress exists to reset
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF5B9EF3)),
                  SizedBox(width: 8),
                  Text('No Progress Found'),
                ],
              ),
              content: Text(
                'You haven\'t made any progress yet! Start with Addition to begin your math journey.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Color(0xFF5B9EF3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    // Show confirmation dialog
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Reset Progress?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('• Remove all perfect scores'),
                Text('• Lock all topics except Addition'),
                Text('• Reset all stars and progress'),
                SizedBox(height: 12),
                Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Reset Progress',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        try {
          // Reset the progression
          await progressionService.resetToBeginning();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Progress reset successfully! You can start fresh.'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Failed to reset progress. Please try again.'),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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