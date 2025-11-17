import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_buddy/services/auth_service.dart';

import '../../services/user_service.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();

  bool _checkingHandle = false;
  bool _handleAvailable = true;
  String? _handleError;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;

    // Prefill display name with SSO default (optional)
    _displayNameController.text = user?.displayName ?? '';
    _handleController.addListener(_validateHandleFormat);
  }

  /// Validates local handle format before checking uniqueness.
  void _validateHandleFormat() {
    final handle = _handleController.text.trim();

    // Basic validation rules
    final valid = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(handle);

    setState(() {
      if (!valid) {
        _handleAvailable = false;
        _handleError = "Only letters, numbers, and underscores (3–20 chars)";
      } else {
        _handleError = null;
      }
    });
  }

  /// Check Firestore to see if handle is taken.
  Future<void> _checkHandleUniqueness() async {
    final handle = _handleController.text.trim();

    if (_handleError != null) return; // invalid format

    setState(() {
      _checkingHandle = true;
    });

    final available = await UserService.instance.isHandleAvailable(handle);

    setState(() {
      _checkingHandle = false;
      _handleAvailable = available;
      if (!available) {
        _handleError = "Handle already taken. Try another.";
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final handle = _handleController.text.trim();
    final displayName = _displayNameController.text.trim();

    // Last check before saving
    await _checkHandleUniqueness();
    if (!_handleAvailable) return;

    try {
      await UserService.instance.createCurrentUserProfile(
        handle: handle,
        displayName: displayName,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Your Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome to Study Buddy 👋",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Before you begin, create your public profile. "
                "Your handle and display name will be visible to other students.",
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 25),

              // DISPLAY NAME
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: "Display Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Display name required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // HANDLE
              TextFormField(
                controller: _handleController,
                decoration: InputDecoration(
                  labelText: "Handle (unique username)",
                  border: const OutlineInputBorder(),
                  prefixText: '@ ',
                  suffixIcon: _checkingHandle
                      ? const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  errorText: _handleError,
                ),
                onChanged: (_) {
                  // Clear error when typing again
                  setState(() => _handleError = null);
                },
                onEditingComplete: _checkHandleUniqueness,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Handle required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
