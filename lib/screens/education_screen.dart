// File: lib/screens/education_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  bool watched = false;
  bool quizDone = false;
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _addPoints(int value) async {
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'points': FieldValue.increment(value)});
    }
  }

  void _completeVideo() async {
    if (!watched) {
      await _addPoints(10);
      setState(() => watched = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video completed. +10 points!")),
      );
    }
  }

  void _completeQuiz() {
    Navigator.pushNamed(context, '/education_quiz');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Educational Module")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text(
              "🎬 Watch a UCO recycling educational video",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: watched ? null : _completeVideo,
              child: Text(watched ? "Watched" : "Mark as Watched"),
            ),
            const SizedBox(height: 30),
            const Text(
              "📝 Take a quick quiz",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: quizDone ? null : _completeQuiz,
              child: Text(quizDone ? "Completed" : "Start Quiz"),
            ),
            const SizedBox(height: 20),
            if (watched && quizDone)
              const Text(
                "✅ All activities completed! Points earned.",
                style: TextStyle(color: Colors.green),
              )
          ],
        ),
      ),
    );
  }
}
