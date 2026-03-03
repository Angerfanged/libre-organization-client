import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libre_organization_client/credentials.dart';
import 'package:libre_organization_client/socket_client.dart';

import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();
  final TextEditingController registrationUsertagController =
      TextEditingController();
  final TextEditingController registrationUsernameController =
      TextEditingController();
  final TextEditingController registrationEmailController =
      TextEditingController();
  final TextEditingController registrationPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _currentForm = 0; // 0 for login form, and 1 for registration form
  bool _isLoading = false;
  bool _showForm = true; // Track if we should show the form or loading

  final String _mainServerUrl = 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  /// Try to automatically login with stored credentials
  Future<void> _tryAutoLogin() async {
    final storage = FlutterSecureStorage();

    try {
      String? email = await storage.read(key: 'email');
      String? password = await storage.read(key: 'password');

      if (email != null && password != null) {
        setState(() {
          _isLoading = true;
          _showForm = false;
        });

        // Set credentials
        Credentials().email = email;
        Credentials().password = password;

        // Attempt auto-login
        await _performLogin(email, password);
      }
    } catch (e) {
      print('Auto-login error: $e');
      setState(() {
        _showForm = true;
      });
    }
  }

  // Perfrom registration with usertag, email, and password
  Future<void> _performRegistration(
    String usertag,
    String username,
    String email,
    String password,
  ) async {
    try {
      // Connect to server
      SocketClient().initMainConnection(_mainServerUrl);
      try {
        await SocketClient().waitForConnection(SocketClient().mainSocket);
      } catch (e) {
        print('Connection timeout: $e');
      }

      if (SocketClient().isMainConnected()) {
        // Set up listener for response
        SocketClient().onMainEvent('registerResponse', (data) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          if (data['success'] == true) {
            _performLogin(email, password);
          } else {
            setState(() {
              _showForm = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration failed: ${data['message']}'),
              ),
            );
          }
        });

        // Send login
        SocketClient().sendToMain('register', {
          'user_tag': usertag,
          'default_name': username,
          'email': email,
          'password': Credentials().hashedPassword,
        });
      } else {
        setState(() {
          _isLoading = false;
          _showForm = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not connect to server. Please try again later.',
            ),
          ),
        );
        //Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showForm = true;
      });
      print('Login error: $e');
    }
  }

  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _showForm = false;
      });

      final storage = FlutterSecureStorage();

      // Save credentials securely
      await storage.write(
        key: 'email',
        value: registrationEmailController.text,
      );
      await storage.write(
        key: 'password',
        value: registrationPasswordController.text,
      );

      // Set login data
      Credentials().email = registrationEmailController.text;
      Credentials().password = registrationPasswordController.text;

      await _performRegistration(
        registrationUsertagController.text,
        registrationUsernameController.text,
        registrationEmailController.text,
        registrationPasswordController.text,
      );
    }
  }

  /// Perform the actual login with email and password
  Future<void> _performLogin(String email, String password) async {
    try {
      // Connect to server
      SocketClient().initMainConnection(_mainServerUrl);
      try {
        await SocketClient().waitForConnection(SocketClient().mainSocket);
      } catch (e) {
        print('Connection timeout: $e');
      }

      if (SocketClient().isMainConnected()) {
        // Set up listener for response
        SocketClient().onMainEvent('loginResponse', (data) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          if (data['success'] == true) {
            Credentials().userId = data['user_id'];
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            setState(() {
              _showForm = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: ${data['message']}')),
            );
          }
        });

        // Send login
        SocketClient().sendToMain('login', {
          'email': email,
          'password': Credentials().hashedPassword,
        });
      } else {
        setState(() {
          _isLoading = false;
          _showForm = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not connect to server. Please try again later.',
            ),
          ),
        );
        //Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showForm = true;
      });
      print('Login error: $e');
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _showForm = false;
      });

      final storage = FlutterSecureStorage();

      // Save credentials securely
      storage.write(key: 'email', value: loginEmailController.text);
      storage.write(key: 'password', value: loginPasswordController.text);

      // Set login data
      Credentials().email = loginEmailController.text;
      Credentials().password = loginPasswordController.text;

      await _performLogin(
        loginEmailController.text,
        loginPasswordController.text,
      );
    }
  }

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen during auto-login
    if (!_showForm) {
      switch (_currentForm) {
        case 0:
          return Scaffold(
            //appBar: AppBar(title: const Text('Login'), centerTitle: true),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Logging in...'),
                ],
              ),
            ),
          );
        case 1:
          return Scaffold(
            //appBar: AppBar(title: const Text('Login'), centerTitle: true),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Registering...'),
                ],
              ),
            ),
          );
        default:
          return Scaffold(
            //appBar: AppBar(title: const Text('Login'), centerTitle: true),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
      }
    }

    switch (_currentForm) {
      case 0:
        return Scaffold(
          //appBar: AppBar(title: const Text('Login'), centerTitle: true),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Icon(
                        Icons.person,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        'Libre Organization',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 32),

                      Text(
                        'Please login to continue',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentForm = 1;
                          });
                        },
                        child: Text('Click Here to register'),
                      ),

                      Padding(padding: EdgeInsetsGeometry.all(2.5)),
                      // Email Field
                      TextFormField(
                        controller: loginEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: loginPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case 1:
        return Scaffold(
          //appBar: AppBar(title: const Text('Login'), centerTitle: true),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Icon(
                        Icons.person,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        'Libre Organization',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 32),

                      Text(
                        'Please register to continue',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentForm = 0;
                          });
                        },
                        child: Text('Click Here to login'),
                      ),

                      Padding(padding: EdgeInsetsGeometry.all(2.5)),

                      // User Tag Field
                      TextFormField(
                        controller: registrationUsertagController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Usertag',
                          hintText: 'Enter a name to be tagged with',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name to be tagged with';
                          }
                          if (!RegExp('[a-zA-Z0-9_-]').hasMatch(value)) {
                            return 'Please enter a valid usertag';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // User Name Field
                      TextFormField(
                        controller: registrationUsernameController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter a name to be called',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name to be called';
                          }
                          if (!RegExp('[a-zA-Z0-9_-]').hasMatch(value)) {
                            return 'Please enter a valid username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: registrationEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: registrationPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter a password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegistration,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        return Scaffold(
          //appBar: AppBar(title: const Text('Login'), centerTitle: true),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        );
    }
  }
}
