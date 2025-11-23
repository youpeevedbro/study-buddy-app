// lib/screens/profile.dart
import 'package:flutter/material.dart';

import '../components/grad_button.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  late final TextEditingController _displayNameController;
  late final TextEditingController _handleController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _handleController = TextEditingController();
    _emailController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService.instance.getCurrentUserProfile();
      final fallbackEmail = AuthService.instance.currentUser?.email ?? '';

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _displayNameController.text = profile?.displayName ?? '';
        _handleController.text = profile?.handle ?? '';
        _emailController.text = profile?.email ?? fallbackEmail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;

    // Go back to the root (AuthGate as home); it will show Landing if user == null
    Navigator.of(context).pushNamedAndRemoveUntil('/landing', (_) => false);
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently delete your Study Buddy account and profile data. "
          "This action cannot be undone. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // close confirm dialog first

              try {
                // 1) Delete Firestore + Auth user
                await UserService.instance.deleteCurrentUserAccount();

                // 2) Extra safety: ensure client is fully signed out
                await AuthService.instance.signOut();

                if (!mounted) return;

                // 3) Clear navigation stack and go to landing/auth gate
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/landing', (_) => false);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: $e'),
                  ),
                );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context), // back to Dashboard
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 60),
              ),
              const SizedBox(height: 20),

              // Display Name
              TextField(
                enabled: false,
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: "Display Name",
                ),
              ),
              const SizedBox(height: 12),

              // Handle
              TextField(
                enabled: false,
                controller: _handleController,
                decoration: const InputDecoration(
                  labelText: "Handle",
                  prefixText: '@ ',
                ),
              ),
              const SizedBox(height: 12),

              // Email
              TextField(
                controller: _emailController,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),
              const SizedBox(height: 30),

              // Edit Account (display name + handle)
              InkWell(
                onTap: () async {
                  final result = await Navigator.push<Map<String, String>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfilePage(
                        initialDisplayName: _displayNameController.text,
                        initialHandle: _handleController.text,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      _displayNameController.text =
                          result['displayName'] ?? _displayNameController.text;
                      _handleController.text =
                          result['handle'] ?? _handleController.text;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Transform.translate( //transform was needed to align icon+text better
                    offset: const Offset(-10, 0), // ← adjust this number to shift the button LEFT/RIGHT
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          "Edit Account",
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Delete Account Button
              GradientButton(
                width: double.infinity,
                height: 50,
                borderRadius: BorderRadius.circular(12.0),
                onPressed: _logout,
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 100),

              // Delete Account
              InkWell(
                onTap: () => _deleteAccount(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Delete Account",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.red.shade700,
                        ),
                      ),
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
}

// ---------------- EDIT PAGE -----------------
class EditProfilePage extends StatefulWidget {
  final String initialDisplayName;
  final String initialHandle;

  const EditProfilePage({
    super.key,
    required this.initialDisplayName,
    required this.initialHandle,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _handleController;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.initialDisplayName);
    _handleController = TextEditingController(text: widget.initialHandle);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newDisplayName = _displayNameController.text.trim();
    final newHandle = _handleController.text.trim();

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await UserService.instance.updateDisplayNameAndHandle(
        newDisplayName: newDisplayName,
        newHandle: newHandle,
      );
      if (!mounted) return;

      Navigator.pop<Map<String, String>>(context, {
        'displayName': newDisplayName,
        'handle': newHandle,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        toolbarHeight: 100,
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
          child: Column(
            children: [
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: "Display Name",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _handleController,
                decoration: InputDecoration(
                  labelText: "Handle",
                  prefixText: '@ ',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 30),
              GradientButton(
                width: double.infinity,
                height: 50,
                borderRadius: BorderRadius.circular(12.0),
                onPressed: _saving ? null : _saveChanges,
                child: _saving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
