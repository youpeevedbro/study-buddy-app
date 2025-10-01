import 'package:flutter/material.dart';
//import 'profile.dart'; // your profile page
import '../components/grad_button.dart'; // your gradient button
import 'forgotpassword.dart';
import 'dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Buddy',
      theme: ThemeData(
        // Define the primary color scheme based on #e7c144
        primaryColor: const Color(0xFFE7C144),
        hintColor: const Color(0xFFF0D689), // A lighter shade for hints
        scaffoldBackgroundColor: Colors.white, // White background 
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() {
    // sign-in logic need later !!!!! 
    // just print the entered credentials for now but need oauth laterrrrr
    print('Email: ${_emailController.text}');
    print('Password: ${_passwordController.text}');
    // Navigate to UserProfilePage after "login", for testing purposes, please delete later
    Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const Dashboard()),
  );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    //final screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth = 400.0; // Max width for the login form

    return Scaffold(
      body: Center( // Center the content horizontally
        child: ConstrainedBox( // Constrain the maximum width of the content
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0, // Fixed horizontal padding for consistent look
                vertical: 40.0,   // Adjusted vertical padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back arrow icon
                  IconButton(
                    icon: Transform.translate(
                      offset: const Offset(3.0, 0.0), 
                      child: Icon(Icons.arrow_back_ios, color: Colors.grey[700]),
                    ),
                    onPressed: () {
                      // Implement navigation back or other action
                      print('Back button pressed');
                    },
                  ),
                  const SizedBox(height: 100.0), // Spacing after back arrow

                  // Study Buddy Title
                  Center(
                    child: Text(
                      'Study Buddy',
                      style: TextStyle(
                        fontFamily: 'BrittanySignature', // Use your custom font family name here
                        fontSize: maxContentWidth * 0.15, // Font size relative to max content width
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60.0), // Spacing after title

                  // Email Input Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: Colors.grey[100], // Light grey background for input fields
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0), // Rounded corners
                        borderSide: BorderSide.none, // No border line
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0), // Highlight on focus
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 20.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0), // Spacing between fields

                  // Password Input Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true, // Hide password text
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 20.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0), // Spacing before forgot password

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor, // Use the main color
                          fontSize: 15.0, // Fixed font size for readability
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35.0), // Spacing before sign in button

                  // Sign In Button
                  GradientButton(
                    width: double.infinity,
                    height: 50,
                    borderRadius: BorderRadius.circular(12.0),
                    onPressed: _signIn,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.0, // Fixed font size for button text
                      fontWeight: FontWeight.bold,
                      ),
                      ),
                    ),
                  const SizedBox(height: 15.0), // Spacing before create account
                  // Create New Account
                  Center(
                    child: TextButton(
                      onPressed: () {
                        print('Create new account pressed');
                        // Navigate to create account screen
                      },
                      child: Text(
                        'Create new account',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 18.0, // Fixed font size
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
  }
}
