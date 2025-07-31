import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: OutlinedButton(
          child: const Text('Sign in with Google'),
          onPressed: () async {
            try {
              GoogleAuthProvider googleProvider = GoogleAuthProvider();
              await FirebaseAuth.instance.signInWithPopup(googleProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to sign in with Google: $e'),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}