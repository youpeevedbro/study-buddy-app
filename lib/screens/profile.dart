import 'package:flutter/material.dart';
import '../components/grad_button.dart';
import '../services/auth_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String userName = "John_Doe";
  String userEmail = "johndoe@student.csulb.edu";
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: userName);
    _emailController = TextEditingController(text: userEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/landing', (_) => false);
  }

  void _disableAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Disable"),
        content: const Text("Are you sure you want to disable your account?"),
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
              onPressed: () {
                // TODO: hook to your backend if you actually disable accounts
                //Navigator.pop(ctx);
                Navigator.pushNamed(context, '/landing'); 
                showDialog(
                  context: context,
                  builder: (innerCtx) => AlertDialog(
                    title: const Text("Account Disabled"),
                    content: const Text("Your account is disabled"),
                    actionsAlignment: MainAxisAlignment.center,
                    actionsPadding: const EdgeInsets.only(bottom: 12),
                    actions: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(innerCtx),
                        icon: const Icon(Icons.waving_hand, color: Color(0xFFE7C144)),
                        label: const Text("See you!"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Disable"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        child: Stack(
          children: [
            // Main content column
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 60),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      enabled: false,
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _emailController,
                      enabled: false,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    const SizedBox(height: 30),

                    InkWell(
                      onTap: () async {
                        final newName = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(initialName: _nameController.text),
                          ),
                        );
                        if (newName != null && newName.isNotEmpty) {
                          setState(() {
                            userName = newName;
                            _nameController.text = newName;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              "Edit Account",
                              style: TextStyle(fontSize: 18, color: theme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Logout 
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: theme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              "Logout",
                              style: TextStyle(fontSize: 18, color: theme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Disable Account Button
                    GradientButton(
                      width: double.infinity,
                      height: 50,
                      borderRadius: BorderRadius.circular(12.0),
                      onPressed: () => _disableAccount(context),
                      child: const Text(
                        'Disable Account',
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
          ],
        ),
      ),
    );
  }
}

// ---------------- EDIT PAGE -----------------
class EditProfilePage extends StatefulWidget {
  final String initialName;
  const EditProfilePage({super.key, required this.initialName});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    // TODO: Add validation and backend update logic here
    Navigator.pop(context, _nameController.text);
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
          onPressed: () => Navigator.pop(context), // back to Dashboard
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
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  const SizedBox(height: 30),
                  GradientButton(
                    width: double.infinity,
                    height: 50,
                    borderRadius: BorderRadius.circular(12.0),
                    onPressed: _saveChanges,
                    child: const Text(
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
          ],
        ),
      ),
    );
  }
}
