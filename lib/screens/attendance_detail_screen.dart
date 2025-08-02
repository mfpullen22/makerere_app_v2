import 'package:flutter/material.dart';

class AttendanceDetailScreen extends StatelessWidget {
  final String lectureTitle;
  final String date;
  final List<String> attended;
  final List<String> notAttended;

  const AttendanceDetailScreen({
    super.key,
    required this.lectureTitle,
    required this.date,
    required this.attended,
    required this.notAttended,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lecture Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Text(
                  lectureTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Divider(height: 32, thickness: 1),
                const Text(
                  'Attended',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...attended.map((name) => ListTile(title: Text(name))),
                const SizedBox(height: 16),
                const Text(
                  'Did not attend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...notAttended.map((name) => ListTile(title: Text(name))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
