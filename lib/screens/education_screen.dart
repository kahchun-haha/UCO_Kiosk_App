// lib/screens/education_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  // State variables
  bool _isLoading = true;
  bool _videoWatched = false;
  bool _quizCompleted = false;
  
  // Get current user and their document reference
  final user = FirebaseAuth.instance.currentUser;
  late final DocumentReference userDoc;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      _loadUserProgress();
    }
  }

  // Load progress from Firestore
  Future<void> _loadUserProgress() async {
    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _videoWatched = data['educationVideoWatched'] ?? false;
          _quizCompleted = data['educationQuizCompleted'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user progress: $e");
      setState(() => _isLoading = false);
    }
  }

  // Award points and update Firestore
  Future<void> _addPoints(int value) async {
    if (user != null) {
      await userDoc.update({'points': FieldValue.increment(value)});
    }
  }

  // Mark video as watched
  void _completeVideo() async {
    if (!_videoWatched) {
      await _addPoints(10);
      await userDoc.update({'educationVideoWatched': true});
      setState(() => _videoWatched = true);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Video completed. +10 points!")),
        );
      }
    }
  }

  // Navigate to quiz and wait for the result
  void _completeQuiz() async {
    // Navigate and wait for a result (true if completed, false/null otherwise)
    final result = await Navigator.pushNamed(context, '/education_quiz');

    if (result == true) {
      // If quiz was completed, update the state and Firestore
      await userDoc.update({'educationQuizCompleted': true});
      setState(() => _quizCompleted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Educational Module")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  const Text(
                    "🎬 Watch a UCO recycling educational video",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _videoWatched ? null : _completeVideo,
                    child: Text(_videoWatched ? "Watched" : "Mark as Watched"),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "📝 Take a quick quiz",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _quizCompleted ? null : _completeQuiz,
                    child: Text(_quizCompleted ? "Completed" : "Start Quiz"),
                  ),
                  const SizedBox(height: 40),
                  if (_videoWatched && _quizCompleted)
                    const Center(
                      child: Text(
                        "✅ All activities completed!",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    )
                ],
              ),
            ),
    );
  }
}