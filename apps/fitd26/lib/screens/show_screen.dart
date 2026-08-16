import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd26/data/challenge.dart';
import 'package:fitd26/data/challenger.dart';
import 'package:fitd26/data/show_state.dart';
import 'package:fitd26/mixins/current_challenge_mixin.dart';
import 'package:fitd26/screens/home_screen.dart';
import 'package:fitd26/screens/waiting_for_challenge.dart';
import 'package:fitd26/widgets/countdown_overlay.dart';
import 'package:flutter/material.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key});

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> with CurrentChallengeMixin {
  ShowState _showState = ShowState.initial;
  List<Player> _players = const [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _showStateSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _playersSubscription;

  @override
  void initState() {
    super.initState();
    _showStateSubscription = FirebaseFirestore.instance
        .doc('/fitd/state')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _showState = ShowState.fromData(snapshot.data());
          });
        });
    _playersSubscription = FirebaseFirestore.instance
        .collection('fitd')
        .doc('state')
        .collection('challengers')
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _players = snapshot.docs
                .map(Player.fromFirestore)
                .nonNulls
                .toList(growable: false);
          });
        });
  }

  @override
  void dispose() {
    _showStateSubscription?.cancel();
    _playersSubscription?.cancel();
    super.dispose();
  }

  @override
  void onChallengeStart() {
    setState(() {});
  }

  @override
  void onChallengeEnd() {}

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;

    if (challenge == null) {
      return const HomeScreen();
    }

    if (challenge.isInTheFuture) {
      return WaitingForChallenge(challenge: challenge);
    }

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBody(challenge),
          Positioned(
            top: 50,
            child: Timeago(
              refreshRate: const Duration(milliseconds: 100),
              date: challenge.endTime,
              allowFromNow: true,
              builder: (context, time) {
                final remainingTime = challenge.endTime.difference(
                  DateTime.now(),
                );
                if (remainingTime.isNegative) {
                  return const Text(
                    'Time over!',
                    style: TextStyle(fontSize: 48, color: Colors.red),
                  );
                }

                if (remainingTime.inSeconds > 10) {
                  return Text(
                    'Time remaining: $time',
                    style: const TextStyle(
                      fontSize: 48,
                      backgroundColor: Colors.black54,
                      color: Colors.white,
                    ),
                  );
                }

                return Container();
              },
            ),
          ),
          Timeago(
            refreshRate: const Duration(milliseconds: 100),
            date: challenge.endTime,
            allowFromNow: true,
            builder: (context, time) {
              final remainingTime = challenge.endTime.difference(
                DateTime.now(),
              );

              if (remainingTime.isNegative || remainingTime.inSeconds > 10) {
                return Container();
              }

              return CountdownOverlay(duration: remainingTime);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Challenge challenge) {
    final challengePane = challenge.jsonWidgetData.build(context: context);

    return switch (_showState.viewMode) {
      ViewMode.challengeOnly => challengePane,
      ViewMode.allWithChallenge => Row(
        children: [
          Expanded(flex: 2, child: challengePane),
          Expanded(flex: 3, child: PlayerPromptGrid(players: _players)),
        ],
      ),
      ViewMode.allPlayers => PlayerPromptGrid(players: _players),
      ViewMode.singlePlayer => _buildSinglePlayer(),
    };
  }

  Widget _buildSinglePlayer() {
    final focusedId = _showState.focusedPlayerId;
    final player = _players.where((p) => p.id == focusedId).firstOrNull;
    if (player == null) {
      return const Center(
        child: Text(
          'No player focused',
          style: TextStyle(color: Colors.white54, fontSize: 32),
        ),
      );
    }
    return PlayerPromptCard(player: player, expanded: true);
  }
}

/// Responsive grid of live per-player prompt cards.
class PlayerPromptGrid extends StatelessWidget {
  const PlayerPromptGrid({super.key, required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for players…',
          style: TextStyle(color: Colors.white38, fontSize: 28),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (players.length) {
          1 => 1,
          2 => 2,
          <= 4 => 2,
          <= 9 => 3,
          _ => 4,
        };
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: constraints.maxWidth / constraints.maxHeight,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final player in players)
              PlayerPromptCard(key: ValueKey(player.id), player: player),
          ],
        );
      },
    );
  }
}

/// One live prompt pane on the audience screen: player name header + live
/// mono prompt text with a subtle "last update" pulse on the border.
class PlayerPromptCard extends StatefulWidget {
  const PlayerPromptCard({super.key, required this.player, this.expanded = false});

  final Player player;
  final bool expanded;

  @override
  State<PlayerPromptCard> createState() => _PlayerPromptCardState();
}

class _PlayerPromptCardState extends State<PlayerPromptCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(PlayerPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.prompt != oldWidget.player.prompt) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.expanded ? 28.0 : 16.0;
    final prompt = widget.player.prompt;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1 - _pulseController.value;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF30363D),
                const Color(0xFF58A6FF),
                _pulseController.isAnimating ? pulse : 0,
              )!,
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text(
              widget.player.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.expanded ? 36 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: prompt.isEmpty
                  ? Text(
                      'Thinking in the dark…',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: fontSize,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : SingleChildScrollView(
                      reverse: true,
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: const Color(0xFFE6EDF3),
                          fontSize: fontSize,
                          height: 1.5,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
