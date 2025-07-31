import 'package:fitd25/screens/admin_content_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AdminContentScreen(user: snapshot.data!);
        }
        return const LoginScreen();
      },
    );
  }
}