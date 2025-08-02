import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:csv/csv.dart';
import 'attendance_detail_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<QueryDocumentSnapshot> lectures = [];

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-'); // MM-DD-YYYY
      if (parts.length != 3) return DateTime(1900);
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return DateTime(1900);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .get();

    setState(() {
      lectures = snapshot.docs;
      lectures.sort((a, b) {
        final aDate = _parseDate(a['date']);
        final bDate = _parseDate(b['date']);
        return bDate.compareTo(aDate); // Most recent first
      });
    });
  }

  Future<void> _exportAttendance() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .get();

    final List<List<dynamic>> csvRows = [
      ['Lecture Title', 'Date', 'Attended', 'Not Attended'],
    ];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = data['lectureTitle'] ?? '';
      final date = data['date'] ?? '';
      final attended =
          (data['attendance']?['attended'] as List<dynamic>?)?.join('; ') ?? '';
      final notAttended =
          (data['attendance']?['not_attended'] as List<dynamic>?)?.join('; ') ??
          '';

      csvRows.add([title, date, attended, notAttended]);
    }

    final csv = const ListToCsvConverter().convert(csvRows);

    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Attendance Records'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Enter your email'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseFunctions.instance
                      .httpsCallable('sendReviewEmailWithMailgun')
                      .call({'email': email, 'csv': csv});
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email sent successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send email: $e')),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Records")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _exportAttendance,
              child: const Text('Export all attendance'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: lectures.length,
              itemBuilder: (context, index) {
                final doc = lectures[index];
                final data = doc.data() as Map<String, dynamic>;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.black),
                  ),
                  elevation: 10,
                  child: ListTile(
                    title: Text(data['lectureTitle'] ?? 'Unknown Lecture'),
                    subtitle: Text(data['date'] ?? 'Unknown Date'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceDetailScreen(
                          lectureTitle: data['lectureTitle'] ?? '',
                          date: data['date'] ?? '',
                          attended: List<String>.from(
                            data['attendance']?['attended'] ?? [],
                          ),
                          notAttended: List<String>.from(
                            data['attendance']?['not_attended'] ?? [],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
