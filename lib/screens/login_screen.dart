import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGuestMode = true;
  String _selectedAvatar = '🦊';
  final List<String> _avatars = ['🦊', '🐶', '🐷', '🐱', '🐰', '🐼'];
  final AuthService _authService = AuthService();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isGuestMode) {
        // Use username-based Quick Start login (handles both new and existing users)
        await _authService.signInWithUsername(
          username: _nameController.text.trim(),
          avatar: _selectedAvatar,
        );
      } else {
        // Sign in with email and password
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFFF6B6B)),
              SizedBox(width: 10),
              Text(
                'Error',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4FF),
              Color(0xFFE8F0FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorations
              Positioned(
                top: 30,
                right: 30,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFE4B5).withValues(alpha: 0.5),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                left: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Color(0xFF87CEEB).withValues(alpha: 0.3),
                  ),
                ),
              ),
              Positioned(
                top: 200,
                right: 50,
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.orange.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 250,
                left: 40,
                child: Text(
                  '=',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.green.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    padding: EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Calculator icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Color(0xFF5B9EF3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calculate,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ready for more math adventures?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 20),

                          // Mode Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isGuestMode = true;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isGuestMode ? Color(0xFF7ED321) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Quick Start',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _isGuestMode ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isGuestMode = false;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_isGuestMode ? Color(0xFF5B9EF3) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Account Login',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !_isGuestMode ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),

                          if (_isGuestMode) ...[
                            // Quick start explanation
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFF0F8FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFF7ED321).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF7ED321), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Enter your username to continue your learning journey!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),
                            // Avatar selection for guest mode
                            Text(
                              'Choose your character',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            SizedBox(height: 15),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _avatars.length,
                                itemBuilder: (context, index) {
                                  final avatar = _avatars[index];
                                  final isSelected = avatar == _selectedAvatar;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedAvatar = avatar;
                                      });
                                    },
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: 8),
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? Color(0xFF7ED321) : Colors.grey[100],
                                        border: isSelected 
                                          ? Border.all(color: Color(0xFF7ED321), width: 3)
                                          : null,
                                        boxShadow: isSelected ? [
                                          BoxShadow(
                                            color: Color(0xFF7ED321).withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: Offset(0, 5),
                                          ),
                                        ] : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          avatar,
                                          style: TextStyle(fontSize: 30),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 20),
                            
                            // Username input for quick start mode
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Enter your username',
                                prefixIcon: Icon(Icons.person, color: Colors.grey[600]),
                                filled: true,
                                fillColor: Color(0xFFF7F9FC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF7ED321), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your username';
                                }
                                if (value.trim().length < 2) {
                                  return 'Username must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12),
                            // Username suggestions
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need ideas? Try these:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: _authService.getSuggestedUsernames().map((username) {
                                      return GestureDetector(
                                        onTap: () {
                                          _nameController.text = username;
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFE8F5E8),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Color(0xFF7ED321).withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            username,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF2C3E50),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Email and password for account login
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: Icon(Icons.email, color: Colors.grey[600]),
                                filled: true,
                                fillColor: Color(0xFFF7F9FC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF5B9EF3), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 15),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                                filled: true,
                                fillColor: Color(0xFFF7F9FC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFFE1E8ED)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF5B9EF3), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ],
                          
                          SizedBox(height: 30),
                          // Login button
                          GestureDetector(
                            onTap: _isLoading ? null : _login,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _isLoading ? Colors.grey[400] : (_isGuestMode ? Color(0xFF7ED321) : Color(0xFF5B9EF3)),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isLoading ? null : [
                                  BoxShadow(
                                    color: (_isGuestMode ? Color(0xFF7ED321) : Color(0xFF5B9EF3)).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isGuestMode ? Icons.star : Icons.rocket_launch, 
                                            color: Colors.white, 
                                            size: 20
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            _isGuestMode ? "Let's Start!" : "Login",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          // Sign up link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                                  );
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Color(0xFF5B9EF3),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          // Ask for help
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.help_outline, size: 16, color: Colors.grey[500]),
                              SizedBox(width: 5),
                              Text(
                                'Ask a grown-up for help',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}