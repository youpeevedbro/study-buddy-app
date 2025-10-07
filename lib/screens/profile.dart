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
              Navigator.pop(ctx);
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
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0.0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context), // back to Dashboard
        ),
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
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

              Center(
                child: InkWell(
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
              ),

              const SizedBox(height: 15),

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
    Navigator.pop(context, _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Transform.translate(
            offset: const Offset(3.0, 0.0),
            child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Study Buddy"),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          fontFamily: 'BrittanySignature',
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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
    );
  }
}
