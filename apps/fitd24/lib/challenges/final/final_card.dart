import 'package:ff_card/ff_card.dart';
import 'package:fitd24/challenges/final/organiser_card.dart';
import 'package:flutter/material.dart';

class Final extends StatelessWidget {
  static const path = "/final";

  const Final({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Final 🎉"),
        centerTitle: true,
      ),
      body: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: const Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                elevation: 12,
                child: OrganiserCard(
                  host: Host(
                    name: 'Dash',
                    title: 'Hi 👋',
                    photo: 'dash.png',
                    socialText: '@FlutterDev',
                    socialUrl: 'https://twitter.com/FlutterDev',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
