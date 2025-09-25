import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedAvatar = '🦊';
  final List<String> _avatars = ['🦊', '🐶', '🐷', '🐱', '🐰', '🐼'];
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Add listeners to update password match indicator in real-time
    _passwordController.addListener(_updatePasswordMatch);
    _confirmPasswordController.addListener(_updatePasswordMatch);
  }

  void _updatePasswordMatch() {
    setState(() {
      // This will trigger a rebuild to update the password match indicator
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Always create a full account for signup
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        avatar: _selectedAvatar,
      );

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
              // Math symbols
              Positioned(
                top: 180,
                right: 50,
                child: Text(
                  'x',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.purple.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 220,
                left: 40,
                child: Text(
                  '÷',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.blue.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Back button
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF5B9EF3),
                      size: 20,
                    ),
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
                          // Header
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Color(0xFF7ED321),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_add,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Join us for amazing math adventures!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 20),
                          
                          SizedBox(height: 20),
                          
                          // Avatar selection
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
                          
                          // Name input
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              hintText: 'Enter your name',
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
                                return 'Please enter your name';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 15),
                          // Email input
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
                                borderSide: BorderSide(color: Color(0xFF7ED321), width: 2),
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
                          // Password input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Create a password',
                              prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
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
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 15),
                          // Confirm Password input
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              hintText: 'Confirm your password',
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
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
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          
                          // Password match indicator
                          if (_passwordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _passwordController.text == _confirmPasswordController.text 
                                    ? Color(0xFFE8F5E8) 
                                    : Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _passwordController.text == _confirmPasswordController.text 
                                      ? Color(0xFF7ED321).withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _passwordController.text == _confirmPasswordController.text 
                                        ? Icons.check_circle_outline 
                                        : Icons.error_outline,
                                    color: _passwordController.text == _confirmPasswordController.text 
                                        ? Color(0xFF7ED321) 
                                        : Colors.red,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _passwordController.text == _confirmPasswordController.text 
                                        ? 'Passwords match!' 
                                        : 'Passwords do not match',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _passwordController.text == _confirmPasswordController.text 
                                          ? Color(0xFF2C3E50) 
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          SizedBox(height: 30),
                          // Sign up button
                          GestureDetector(
                            onTap: _isLoading ? null : _signUp,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _isLoading ? Colors.grey[400] : Color(0xFF7ED321),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isLoading ? null : [
                                  BoxShadow(
                                    color: Color(0xFF7ED321).withValues(alpha: 0.3),
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
                                          Icon(Icons.star, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            "Create Account!",
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
                          // Login link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF7ED321),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}