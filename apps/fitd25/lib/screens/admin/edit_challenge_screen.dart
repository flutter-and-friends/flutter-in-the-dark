import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitd25/data/challenge.dart';
import 'package:flutter/material.dart';

class EditChallengeScreen extends StatefulWidget {
  final ChallengeBase? challenge;

  const EditChallengeScreen({super.key, this.challenge});

  @override
  State<EditChallengeScreen> createState() => _EditChallengeScreenState();
}

class _EditChallengeScreenState extends State<EditChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dartPadIdController;
  late TextEditingController _widgetJsonController;
  late TextEditingController _challengeIdController;
  late List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.challenge?.name ?? '');
    _dartPadIdController = TextEditingController(
      text: widget.challenge?.dartPadId ?? '',
    );
    _widgetJsonController = TextEditingController(
      text: widget.challenge?.widgetJson != null
          ? const JsonEncoder.withIndent(
              '  ',
            ).convert(widget.challenge!.widgetJson)
          : '',
    );
    _challengeIdController = TextEditingController(
      text: widget.challenge?.challengeId ?? '',
    );
    _imageUrls = List<String>.from(widget.challenge?.imageUrls ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.challenge == null ? 'Create Challenge' : 'Edit Challenge',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _challengeIdController,
                decoration: const InputDecoration(labelText: 'Challenge ID'),
                readOnly: widget.challenge != null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a challenge ID';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dartPadIdController,
                decoration: const InputDecoration(labelText: 'DartPad ID'),
              ),
              TextFormField(
                controller: _widgetJsonController,
                decoration: const InputDecoration(labelText: 'Widget JSON'),
                maxLines: 10,
              ),
              const SizedBox(height: 20),
              const Text('Image URLs'),
              ..._imageUrls.map(
                (url) => ListTile(
                  title: Text(url),
                  trailing: IconButton(
                    tooltip: 'Remove image URL',
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () {
                      setState(() {
                        _imageUrls.remove(url);
                      });
                    },
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Add Image URL',
                      ),
                      onFieldSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _imageUrls.add(value);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChallenge,
                child: const Text('Save Challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChallenge() async {
    if (_formKey.currentState!.validate()) {
      final challenge = ChallengeBase(
        name: _nameController.text,
        dartPadId: _dartPadIdController.text,
        challengeId: _challengeIdController.text,
        imageUrls: _imageUrls,
        widgetJson: jsonDecode(_widgetJsonController.text),
      );

      await FirebaseFirestore.instance
          .doc('/fitd/state/challenges/${challenge.challengeId}')
          .set(challenge.toJson());

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
