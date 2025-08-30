import 'package:flutter/material.dart';

class FlutterFriendList extends StatefulWidget {
  static const path = "/crazyList";

  const FlutterFriendList({super.key});

  @override
  State<StatefulWidget> createState() => _FlutterFriendListState();
}

class _FlutterFriendListState extends State<FlutterFriendList> {
  bool isRevered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: const Text("Flutter Friend List"),
        centerTitle: true,
      ),
      body: ListView.separated(
        itemBuilder: (context, index) => ListTile(
          title: Padding(
            padding: EdgeInsets.only(left: index.toDouble() * 10),
            child: Text(
              "Friend ${index + 1}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        reverse: isRevered,
        separatorBuilder: (_, __) => const Divider(),
        itemCount: 35,
      ),
      floatingActionButton: FloatingActionButton(
        // Bonus point for icon
        child: const Icon(Icons.compare_arrows),
        onPressed: () => setState(() {
          isRevered = !isRevered;
        }),
      ),
    );
  }
}
