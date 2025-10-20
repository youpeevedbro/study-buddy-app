import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email';
    final email = v.trim().toLowerCase();
    final validFormat = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[A-Za-z]{2,}$').hasMatch(email);
    if (!validFormat) return 'Enter a valid email';
    if (!email.endsWith(AppConfig.allowedDomain)) {
      return 'Use your ${AppConfig.allowedDomain} email';
    }
    return null;
  }

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      await AuthService.instance.sendPasswordResetEmail(_emailCtrl.text.trim());

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Reset Link Sent!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            content: Text(
              'We\'ve sent a password reset link to ${_emailCtrl.text.trim()}. '
                  'Please check your inbox.',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFFFFC72A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      final msg = _mapResetError(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _mapResetError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid_email_domain') ||
        lower.contains('forbidden_domain') ||
        lower.contains(AppConfig.allowedDomain.toLowerCase()) == false) {
      return 'Please use your ${AppConfig.allowedDomain} email.';
    }
    if (lower.contains('too_many_requests')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    if (lower.contains('network') || lower.contains('timed out') || lower.contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Could not send reset link. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 32,
                right: 32,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
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
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter your ${AppConfig.allowedDomain} email and we’ll send a link.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 40),

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: InputBorder.none,
                            enabledBorder: border,
                            focusedBorder: border.copyWith(
                              borderSide: const BorderSide(color: Color(0xFFFFC72A)),
                            ),
                          ),
                          validator: _emailValidator,
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _handlePasswordReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC72A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _sending
                                ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Send Reset Link',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            'Back to Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFFFC72A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }
}
