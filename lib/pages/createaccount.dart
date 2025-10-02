import 'package:flutter/material.dart';
import '../components/grad_button.dart'; // Make sure this path is correct
import 'home_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _email = '';
  String _password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
                      offset: const Offset(3.0, 0.0), 
                      child: Icon(Icons.arrow_back_ios, color: Colors.black),
                    ),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        ),
        centerTitle: false,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFDE59), Color(0xFFFF914D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: const Text(
            'Create Account',
            style: TextStyle(
              fontFamily: 'BrittanySignature',
              fontSize: 28,
              color: Colors.white, // This color is overridden by gradient
            ),
          ),
        ),
      ),
      body: buildFormContent(),
    );
  }

  Widget buildFormContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person),
              ),
              onSaved: (value) => _name = value!.trim(),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'CSULB Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              onSaved: (value) => _email = value!.trim(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your email';
                } else if (!RegExp(
                  r'^[\w\-\.]+\.student@csulb\.edu$',
                ).hasMatch(value)) {
                  return 'Enter a valid CSULB email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onSaved: (value) => _password = value!.trim(),
              validator: (value) => value == null || value.length < 6
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 24),
            GradientButton(
              onPressed: _submitForm,
              borderRadius: BorderRadius.circular(8),
              height: 50,
              width: double.infinity,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFDE59), Color(0xFFFF914D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    final form = _formKey.currentState;
    if (form != null && form.validate()) {
      form.save();

      // Simulate account creation (TODO: Connect to Firebase or API)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      // Debug output (optional)
      debugPrint('Name: $_name, Email: $_email, Password: $_password');
    }
  }
}
