import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/screens/admin_content_screen.dart';
import 'package:fitd25/screens/login_screen.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.isAnonymous) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'You are logged in as a guest. Please log in to access admin features.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
            }
            return AdminContentScreen(user: snapshot.data!);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
