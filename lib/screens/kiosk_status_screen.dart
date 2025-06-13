import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class KioskStatusScreen extends StatelessWidget {
  KioskStatusScreen({super.key});

  final DocumentReference _docRef =
      FirebaseFirestore.instance.collection('kiosk').doc('status');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiosk Status'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _docRef.snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> data =
                snapshot.data!.data() as Map<String, dynamic>;

            int fillLevel = data['fillLevel'] ?? 0;
            double weight = (data['weight'] ?? 0.0).toDouble();
            int points = data['points'] ?? 0;
            int liquidHeight = data['liquidHeight'] ?? 0;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildStatusCard('Fill Level', '$fillLevel %', Icons.opacity),
                  const SizedBox(height: 20),
                  _buildStatusCard('Weight', '${weight.round()} g', Icons.scale_outlined),
                  const SizedBox(height: 20),
                  _buildStatusCard('Points', '$points pts', Icons.star),
                  const SizedBox(height: 20),
                  _buildStatusCard('Liquid Height', '$liquidHeight cm', Icons.height),
                ],
              ),
            );
          }

          return const Center(child: Text("Waiting for data from kiosk..."));
        },
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 24, color: Colors.black87),
        ),
      ),
    );
  }
}