import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../components/grad_button.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _busy = false;

  Future<void> _doLogin() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.login();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard'); // <- HERE
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doSignup() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.signup();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard'); // <- HERE
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFFC72A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Study Buddy',
                style: TextStyle(
                  fontFamily: 'BrittanySignature',
                  fontSize: 48,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Log In
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: GradientButton(
                            width: double.infinity,
                            height: 56,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _busy ? null : _doLogin,
                            child: _busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Lock In',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
