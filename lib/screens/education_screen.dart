// lib/screens/education_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
// ⛔ removed: import 'package:uco_kiosk_app/screens/partners_screen.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  bool _isLoading = true;
  bool _videoWatched = false;
  bool _quizCompleted = false;

  final user = FirebaseAuth.instance.currentUser;
  DocumentReference? userDoc;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      _loadUserProgress();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadUserProgress() async {
    if (userDoc == null) return;
    try {
      final snapshot = await userDoc!.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _videoWatched = data['educationVideoWatched'] ?? false;
          _quizCompleted = data['educationQuizCompleted'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user progress: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPoints(int value) async {
    if (userDoc != null) {
      await userDoc!.update({'points': FieldValue.increment(value)});
    }
  }

  // Open the video and then ask user if they completed it
  Future<void> _completeVideo() async {
    if (userDoc == null || _videoWatched) return;

    final uri = Uri.parse(
      'https://www.youtube.com/watch?v=zAHH7swMRoU',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching video URL: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open video.")),
      );
      return;
    }

    if (!mounted) return;

    final finished = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video completed?'),
        content: const Text(
          'After watching the video, tap "Yes" to confirm and earn points.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, I finished'),
          ),
        ],
      ),
    );

    if (finished == true) {
      await _addPoints(10);
      await userDoc!.update({'educationVideoWatched': true});
      setState(() => _videoWatched = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Video completed. +10 points!")),
        );
      }
    }
  }

  void _completeQuiz() async {
    if (userDoc == null) return;

    final result = await Navigator.pushNamed(context, '/education_quiz');

    if (result == true) {
      await userDoc!.update({'educationQuizCompleted': true});
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
                    "Learn about Used Cooking Oil (UCO)",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Proper UCO management supports SDG 12: Responsible Consumption "
                    "and Production, and helps protect our environment.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SDG 12 card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "🌍 SDG 12: Responsible Consumption and Production",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "SDG 12 encourages us to reduce waste, use resources efficiently, "
                            "and ensure that what we consume can be reused or recycled. "
                            "By recycling used cooking oil instead of throwing it away, "
                            "you are directly contributing to SDG 12.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Circular economy card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "♻️ Circular Economy",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "In a linear economy, we take resources, make products, and throw them away. "
                            "In a circular economy, waste is reduced by keeping materials in use for as long "
                            "as possible. UCO can be filtered and transformed into biodiesel or eco-friendly "
                            "soap instead of being poured into the sink.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Video section
                  const Text(
                    "🎬 Watch a UCO recycling educational video",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _videoWatched ? null : _completeVideo,
                    child: Text(
                      _videoWatched
                          ? "Completed (10 pts earned)"
                          : "Watch Video & Earn Points",
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Quiz section
                  const Text(
                    "📝 Take a quick quiz",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _quizCompleted ? null : _completeQuiz,
                    child: Text(
                      _quizCompleted ? "Completed" : "Start Quiz",
                    ),
                  ),

                  const SizedBox(height: 40),

                  if (_videoWatched && _quizCompleted)
                    const Center(
                      child: Text(
                        "✅ All activities completed!",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
