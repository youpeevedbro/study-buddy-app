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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFFFF0C9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontFamily: 'BrittanySignature',
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          Semantics(
                            label: 'Study Buddy mascot (profile image)',
                            image: true,
                            child: const CircleAvatar(
                              radius: 110,
                              backgroundColor: Colors.transparent,
                              backgroundImage: AssetImage("assets/images/elbee.png"),
                            ),
                          ),


                          const SizedBox(height: 28),

                          // Info fields card
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Account Info",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Display Name
                                TextField(
                                  enabled: false,
                                  controller: _displayNameController,
                                  decoration: InputDecoration(
                                    labelText: "Display Name",
                                    filled: true,
                                    fillColor: Colors.white,
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Handle
                                TextField(
                                  enabled: false,
                                  controller: _handleController,
                                  decoration: InputDecoration(
                                    labelText: "Handle",
                                    prefixText: '@ ',
                                    filled: true,
                                    fillColor: Colors.white,
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Email
                                TextField
                                  (
                                  controller: _emailController,
                                  enabled: false,
                                  decoration: InputDecoration(
                                    labelText: "Email",
                                    filled: true,
                                    fillColor: Colors.white,
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Edit Account button
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      final result =
                                          await Navigator.push<Map<String, String>>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditProfilePage(
                                            initialDisplayName:
                                                _displayNameController.text,
                                            initialHandle:
                                                _handleController.text,
                                          ),
                                        ),
                                      );

                                      if (result != null) {
                                        setState(() {
                                          _displayNameController.text =
                                              result['displayName'] ??
                                                  _displayNameController.text;
                                          _handleController.text =
                                              result['handle'] ??
                                                  _handleController.text;
                                        });
                                      }
                                    },
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: theme.primaryColor,
                                      size: 20,
                                    ),
                                    label: Text(
                                      "Edit Account",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Logout button (primary action)
                          GradientButton(
                            width: double.infinity,
                            height: 52,
                            borderRadius: BorderRadius.circular(14.0),
                            onPressed: _logout,
                            child: const Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
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
  bool _deleting = false;

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

  Future<void> _confirmDeleteAccount() async {
    if (_deleting) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFFFFF8E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Delete Account",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A3024),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This will permanently delete your Study Buddy account and profile data. "
                  "This action cannot be undone.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8C7A5A),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8C7A5A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() => _deleting = true);

    try {
      // 1) Delete Firestore + Auth user
      await UserService.instance.deleteCurrentUserAccount();

      // 2) Extra safety: ensure client is fully signed out
      await AuthService.instance.signOut();

      if (!mounted) return;

      // 3) Clear navigation stack and go to landing/auth gate
      Navigator.of(context).pushNamedAndRemoveUntil('/landing', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFFFF0C9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontFamily: 'BrittanySignature',
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EB),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Account",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 24),
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
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Delete account 
                  TextButton.icon(
                    onPressed: _deleting ? null : _confirmDeleteAccount,
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: Color(0xFFD32F2F),
                      size: 20,
                    ),
                    label: const Text(
                      "Delete Account",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD32F2F),
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
