import 'package:beyond_borders/main.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:beyond_borders/pages/destinations.dart';
import 'package:beyond_borders/authentication/registration.dart';
import 'package:beyond_borders/authentication/custom_auth_appbar.dart';
import 'package:beyond_borders/authentication/forgot_password.dart';
import 'package:beyond_borders/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import this for specific error codes

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  // Add this variable to track password visibility
  bool _obscurePassword = true;

  // Error message strings
  String? _emailError;
  String? _passwordError;
  String? _generalError; // Added for network or general errors

  // Create instance of AuthService
  final AuthService _authService = AuthService();

  // Validation function
  String? _validateField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // ...existing code...
  void _submitForm() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
        });

        await _authService.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        _showSuccessDialog(context);
      } catch (e) {
        print("Login error: $e");

        // Use the exception message directly for clarity
        String errorMsg = e is Exception ? e.toString() : e.toString();

        // Map known messages to specific fields
        if (errorMsg.contains('No user found')) {
          setState(() {
            _emailError = 'No account found with this email';
          });
        } else if (errorMsg.contains('incorrect') ||
            errorMsg.contains('wrong password')) {
          setState(() {
            _passwordError = 'Wrong password';
          });
        } else if (errorMsg.contains('not valid')) {
          setState(() {
            _emailError = 'Invalid email address';
          });
        } else if (errorMsg.contains('disabled')) {
          setState(() {
            _emailError = 'This account has been disabled';
          });
        } else if (errorMsg.contains('Too many unsuccessful')) {
          setState(() {
            _generalError = 'Too many failed attempts. Please try again later.';
          });
        } else {
          // Fallback for any other error
          setState(() {
            _generalError = errorMsg.replaceFirst('Exception: ', '');
          });
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      // Wrap the body with a SafeArea for proper padding
      body: SafeArea(
        // Add SingleChildScrollView to handle overflow when keyboard appears
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lottie animation - add flexibility to resize
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Lottie.asset(
                              "assets/animations/beyond_borders_main.json",
                              height: MediaQuery.of(context).size.height *
                                  0.2, // Responsive height
                              width: double.infinity,
                              fit: BoxFit.fitHeight,
                            ),
                          ),
                        ),

                        // Welcome text
                        Text(
                          'Welcome to Beyond Borders',
                          style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),

                        // General error message (if any)
                        if (_generalError != null)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              _generalError!,
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Email Text Field with validation
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Enter your email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                                // Add red border if there's an error
                                enabledBorder: _emailError != null
                                    ? OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      )
                                    : null,
                                focusedBorder: _emailError != null
                                    ? OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      )
                                    : null,
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                                // Remove the default error text (we'll show it separately below)
                                errorStyle: TextStyle(height: 0, fontSize: 0),
                              ),
                              validator: (value) =>
                                  _validateField(value, 'Email'),
                            ),
                            // Show error message if exists
                            if (_emailError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 8.0),
                                child: Text(
                                  _emailError!,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Password Text Field with validation and toggle visibility
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              obscureText:
                                  _obscurePassword, // Use our toggle variable here
                              decoration: InputDecoration(
                                labelText: 'Enter your password',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                                // Add red border if there's an error
                                enabledBorder: _passwordError != null
                                    ? OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      )
                                    : null,
                                focusedBorder: _passwordError != null
                                    ? OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      )
                                    : null,
                                errorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red),
                                ),
                                // Remove the default error text (we'll show it separately below)
                                errorStyle: TextStyle(height: 0, fontSize: 0),
                                // Add suffix icon button to toggle password visibility
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    // Change the icon based on the state
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    // Toggle password visibility state
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) =>
                                  _validateField(value, 'Password'),
                            ),
                            // Show error message if exists
                            if (_passwordError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 8.0),
                                child: Text(
                                  _passwordError!,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Forgot password link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen()),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Onboard button with validation
                        ElevatedButton(
                          onPressed: _submitForm,
                          child: Text('Sign In'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        // Register now section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account yet? "),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Registration()),
                                );
                              },
                              child: Text(
                                "Register now",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Add extra padding at the bottom to ensure content is visible with keyboard
                        SizedBox(
                            height: MediaQuery.of(context).viewInsets.bottom > 0
                                ? 20
                                : 0),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      // Add resizeToAvoidBottomInset property to prevent bottom overflow
      resizeToAvoidBottomInset: true,
    );
  }

  // Show Success Dialog
  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Prevents excessive height
            children: [
              // Lottie Animation
              SizedBox(
                height: 150, // Adjust as needed
                child: Lottie.asset(
                  "assets/animations/success.json",
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 16), // Space between animation & text
              Text(
                "Welcome to Beyond Borders",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeWithDrawer()),
                  );
                },
                child: Text(
                  "OK",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}