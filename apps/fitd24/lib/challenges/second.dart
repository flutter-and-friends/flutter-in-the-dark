import 'package:flutter/material.dart';

class Second extends StatelessWidget {
  const Second({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Row(
        children: [
          Drawer(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: const [
                ListTile(
                  title: Text(
                    'Recent',
                    style: TextStyle(fontSize: 28),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.search, size: 16),
                      ),
                      SizedBox(width: 8),
                      CircleAvatar(
                        radius: 16,
                        child: Icon(
                          Icons.add,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Contact(
                  name: 'Lukas Klingsbo',
                  image: lukas,
                  previewString: 'I sent you the nu...',
                  timeSinceLastMessage: '5 minutes ago',
                ),
                Contact(
                  name: 'Alek Åström',
                  image: alek,
                  previewString: 'The logo looks nice!',
                  timeSinceLastMessage: 'Yesterday',
                ),
                Contact(
                  name: 'Johannes Pietilä Löhnn',
                  image: johannes,
                  previewString: '🤷',
                  timeSinceLastMessage: 'Thursday',
                ),
                Contact(
                  name: 'Dash',
                  image: dash,
                  previewString: 'Hi!',
                  timeSinceLastMessage: 'Dec. 2013',
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(size: 100),
                  const SizedBox(height: 12),
                  Text(
                    'Flutter Chat',
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Contact extends StatelessWidget {
  final String name;
  final AssetImage image;
  final String previewString;
  final String timeSinceLastMessage;

  const Contact({
    super.key,
    required this.name,
    required this.image,
    required this.previewString,
    required this.timeSinceLastMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {},
      leading: CircleAvatar(
        foregroundImage: image,
      ),
      title: Text(name),
      subtitle: Row(
        children: [
          Expanded(child: Text(previewString)),
          Text(timeSinceLastMessage),
        ],
      ),
    );
  }
}

const alek = AssetImage('assets/photos/alek.png');
const lukas = AssetImage('assets/photos/lukas.png');
const johannes = AssetImage('assets/photos/johannes.png');
const dash = AssetImage('assets/photos/dash.png');
