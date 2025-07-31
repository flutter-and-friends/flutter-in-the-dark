import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final googleAuthProider = GoogleAuthProvider();
  User? _user;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: _user == null
            ? OutlinedButton(
                child: Text('Sign in with Google'),
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
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Signed in as ${_user!.displayName}'),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
      ),
    );
  }
}
