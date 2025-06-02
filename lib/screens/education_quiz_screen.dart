// File: lib/screens/education_quiz_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EducationQuizScreen extends StatefulWidget {
  const EducationQuizScreen({super.key});

  @override
  State<EducationQuizScreen> createState() => _EducationQuizScreenState();
}

class _EducationQuizScreenState extends State<EducationQuizScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final Random random = Random();

  late final List<Map<String, dynamic>> questions;
  int currentQuestion = 0;
  int score = 0;
  bool answered = false;
  int? selectedAnswer;

  final List<Map<String, dynamic>> allQuestions = [
    {'question': 'When should you dispose of used cooking oil?', 'options': ['After it cools down', 'Immediately when hot', 'While cooking', 'After a week'], 'answer': 0},
    {'question': 'Where should you take used cooking oil for recycling?', 'options': ['Public trash can', 'Your backyard', 'Nearby river', 'Designated recycling center'], 'answer': 3},
    {'question': 'Why should you avoid pouring UCO down the sink?', 'options': ['It clogs drains', 'It creates fertilizer', 'It cleans the pipes', 'It makes cooking faster'], 'answer': 0},
    {'question': 'How can UCO be repurposed?', 'options': ['Paint', 'Cooking gas', 'Drinking water', 'Biodiesel'], 'answer': 3},
    {'question': 'How to store UCO before recycling?', 'options': ['Open container', 'In the toilet', 'In a sealed bottle', 'In a paper bag'], 'answer': 2},
    {'question': 'Which bin is typically used for UCO collection?', 'options': ['Red bin', 'Green bin', 'Yellow bin', 'Blue bin'], 'answer': 2},
    {'question': 'Why is UCO harmful to the environment?', 'options': ['Grows flowers', 'Absorbs waste', 'Feeds animals', 'Causes water pollution'], 'answer': 3},
    {'question': 'Which product can be made from UCO?', 'options': ['Glass', 'Plastic', 'Electronics', 'Soap'], 'answer': 3},
    {'question': 'What should you avoid mixing with UCO?', 'options': ['Salt', 'Air', 'Light', 'Water'], 'answer': 3},
    {'question': 'Who usually manages UCO collection?', 'options': ['Students', 'Supermarket staff', 'Mail carriers', 'Certified recyclers'], 'answer': 3},
    {'question': 'How can you contribute to UCO recycling efforts?', 'options': ['Bring oil to collection centers', 'Boil it repeatedly', 'Store indefinitely', 'Share it on social media'], 'answer': 0},
    {'question': 'Which of these organizations promotes UCO recycling?', 'options': ['Department of Environment Malaysia', "McDonald's", 'Meteorological Department', 'Tourism Malaysia'], 'answer': 0},
    {'question': 'What is UCO?', 'options': ['Universal Carbon Output', 'Used Cooking Oil', 'Unfiltered Clean Oil', 'Urban Collection Oil'], 'answer': 1},
    {'question': 'What is one common use of recycled UCO?', 'options': ['Fueling airplanes', 'Making biodiesel', 'Making glue', 'Feeding pets'], 'answer': 1},
    {'question': 'What happens if UCO is poured into the sink?', 'options': ['It nourishes wildlife', 'It clogs pipes and pollutes water', 'It helps filter sewage', 'It cleans grease'], 'answer': 1},
    {'question': 'Who should be responsible for disposing of used cooking oil properly?', 'options': ['Everyone', 'Only restaurants', 'Only the government', 'Only chefs'], 'answer': 0},
    {'question': 'Who collects UCO for recycling in some communities?', 'options': ['Certified recyclers', 'Children', 'Police', 'Taxi drivers'], 'answer': 0},
    {'question': 'Who can benefit from UCO recycling programs?', 'options': ['Communities', 'Only factories', 'Only rich people', 'Tourists'], 'answer': 0},
    {'question': 'What should you do before pouring oil into a recycling bottle?', 'options': ['Let it cool', 'Add water', 'Freeze it', 'Boil it again'], 'answer': 0},
    {'question': 'What should not be done with used cooking oil?', 'options': ['Recycle it', 'Pour into drain', 'Store in bottles', 'Send to collection point'], 'answer': 1},
    {'question': 'What is one risk of not recycling UCO?', 'options': ['Environmental pollution', 'It smells nice', 'Increased plant growth', 'More insects'], 'answer': 0},
    {'question': 'When is the best time to prepare UCO for recycling?', 'options': ['After it cools', 'Before cooking', 'During frying', 'After one month'], 'answer': 0},
    {'question': 'When should restaurants arrange UCO pickup?', 'options': ['When container is full', 'Every year', 'Every day', 'Never'], 'answer': 0},
    {'question': 'Where should UCO be kept before collection?', 'options': ['In sealed container', 'In sink', 'In garden', 'On the stove'], 'answer': 0},
    {'question': 'Where should UCO never be poured?', 'options': ['Into rivers', 'Into a bottle', 'Into collection tank', 'Into recycling kiosk'], 'answer': 0},
    {'question': 'Why is UCO recycling important?', 'options': ['Reduces pollution', 'Wastes oil', 'Increases cooking', 'Makes oil cheaper'], 'answer': 0},
    {'question': "Why shouldn't you throw UCO in general trash?", 'options': ['It causes contamination', "It's fun", 'It’s clean', 'It saves time'], 'answer': 0},
    {'question': 'How do you know UCO is ready to recycle?', 'options': ['Cool and stored properly', 'Still hot', 'Foamy', 'Mixed with food'], 'answer': 0},
    {'question': 'How can students support UCO recycling?', 'options': ['Join recycling programs', 'Ignore it', 'Use more oil', 'Burn it at home'], 'answer': 0},
    {'question': 'What is a safe practice when disposing of used cooking oil?', 'options': ['Cool and store in sealed container', 'Pour into toilet', 'Mix with detergent', 'Throw in plastic bag'], 'answer': 0},
  ];

  @override
  void initState() {
    super.initState();
    allQuestions.shuffle();
    questions = allQuestions.take(10).toList();
  }

  void answerQuestion(int selectedIndex) {
    setState(() {
      answered = true;
      selectedAnswer = selectedIndex;
    });

    final correctIndex = questions[currentQuestion]['answer'] as int;
    final isCorrect = selectedIndex == correctIndex;
    if (isCorrect) score += 2;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCorrect ? "Correct!" : "Wrong"),
        content: isCorrect
            ? const Text("Good job!")
            : Text("The correct answer is: ${questions[currentQuestion]['options'][correctIndex]}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (currentQuestion < questions.length - 1) {
                setState(() {
                  currentQuestion++;
                  answered = false;
                  selectedAnswer = null;
                });
              } else {
                _finishQuiz();
              }
            },
            child: const Text("Next"),
          )
        ],
      ),
    );
  }

  Future<void> _finishQuiz() async {
    if (user != null && score > 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'points': FieldValue.increment(score)});
    }

    final bool fullScore = score == questions.length * 2;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Quiz Completed"),
        content: Text(fullScore
            ? "Congratulations! You scored $score points. You have a solid understanding of used cooking oil (UCO) recycling!"
            : "You scored $score points. Great effort — keep learning and growing your knowledge about UCO recycling!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/education')),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = questions[currentQuestion];
    final correctAnswer = question['answer'] as int;

    return Scaffold(
      appBar: AppBar(title: Text("Question ${currentQuestion + 1} of ${questions.length}")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...List.generate((question['options'] as List).length, (index) {
              final option = question['options'][index];
              final isCorrect = index == correctAnswer;
              final isSelected = index == selectedAnswer;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: answered && isCorrect
                        ? Colors.green
                        : answered && isSelected
                        ? Colors.red
                        : null,
                  ),
                  onPressed: answered ? null : () => answerQuestion(index),
                  child: Text(option),
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}
