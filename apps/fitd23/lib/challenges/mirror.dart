import 'package:flutter/material.dart';

class Mirror extends StatelessWidget {
  static const String path = "/mirror";

  const Mirror({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hi, I'm chat"),
        backgroundColor: Colors.brown,
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              "Wanna grab a beer 🍻?",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const Divider(color: Colors.black, height: 10),
          Transform.scale(
            scaleX: -1,
            child: const ListTile(
              title: Text(
                "Yes! When?",
                style: TextStyle(
                    fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(color: Colors.black, height: 10),
          const ListTile(
            title: Text(
              "Tomorrow morning?",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const Divider(color: Colors.black, height: 10),
          Transform.scale(
            scaleX: -1,
            child: const ListTile(
              title: Text(
                "Nah, I'm good.",
                style: TextStyle(
                    fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(color: Colors.black, height: 10),
          const Center(
            child: Text(
              "End of chat",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}
