
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitd25/screens/login_screen.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Admin'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                )
              ],
            ),
            body: const Center(
              child: Text('Admin Screen'),
            ),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
