import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import "package:makerere_clean/main.dart";

import 'pdf.dart';

class PresentationListScreen extends StatefulWidget {
  const PresentationListScreen({super.key});

  @override
  State<PresentationListScreen> createState() => _PresentationListScreenState();
}

class _PresentationListScreenState extends State<PresentationListScreen> {
  bool _isLoading = false;

  Future<void> openPDF(
    BuildContext context,
    String storageUrl,
    String fileName,
  ) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final localFile = File(filePath);

      // If file is missing or zero-length, (re)download
      if (!localFile.existsSync() || localFile.lengthSync() == 0) {
        if (localFile.existsSync() && localFile.lengthSync() == 0) {
          // clean up bad cache file
          localFile.deleteSync();
        }
        await _downloadPDF(storageUrl, localFile);
      }

      // Validate again after download
      if (!localFile.existsSync() || localFile.lengthSync() == 0) {
        throw Exception("File is missing or invalid after download.");
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => PDFScreen(path: filePath)),
      );
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPDF(String storageUrl, File localFile) async {
    try {
      // Ensure parent dir exists
      final dir = localFile.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Stream the file directly to disk (avoids memory blow-ups)
      final ref = FirebaseStorage.instance.refFromURL(storageUrl);
      final downloadTask = ref.writeToFile(localFile);

      // Optionally, listen for progress:
      // downloadTask.snapshotEvents.listen((taskSnapshot) {
      //   // You can surface progress if you want
      // });

      await downloadTask;

      // Sanity check
      if (!localFile.existsSync() || localFile.lengthSync() == 0) {
        // Clean up any bad file and error out
        if (localFile.existsSync()) {
          localFile.deleteSync();
        }
        throw Exception("Downloaded file is empty.");
      }
    } on FileSystemException catch (e) {
      // Clean up on failures
      if (localFile.existsSync() && localFile.lengthSync() == 0) {
        localFile.deleteSync();
      }
      throw Exception("Failed to write PDF to local storage: ${e.message}");
    } catch (e) {
      if (localFile.existsSync() && localFile.lengthSync() == 0) {
        localFile.deleteSync();
      }
      throw Exception("Download failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                "Tap a presentation to view the PDF",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('presentations')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No presentations available',
                        style: TextStyle(color: Colors.black),
                      ),
                    );
                  }

                  // Group docs by category, sort categories and items
                  final docs = snapshot.data!.docs;

                  final Map<String, List<QueryDocumentSnapshot>> grouped = {};
                  for (final d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final catRaw = (data['category'] as String?)?.trim();
                    final category = (catRaw == null || catRaw.isEmpty)
                        ? 'Uncategorized'
                        : catRaw;

                    grouped.putIfAbsent(category, () => []).add(d);
                  }

                  final categories = grouped.keys.toList()
                    ..sort(
                      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                    );

                  // Sort items within each category by title
                  for (final k in categories) {
                    grouped[k]!.sort((a, b) {
                      final da = a.data() as Map<String, dynamic>;
                      final db = b.data() as Map<String, dynamic>;
                      final ta = (da['title'] as String?) ?? '';
                      final tb = (db['title'] as String?) ?? '';
                      return ta.toLowerCase().compareTo(tb.toLowerCase());
                    });
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, idx) {
                      final category = categories[idx];
                      final items = grouped[category]!;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        elevation: 4,
                        child: Theme(
                          // Make the expansion tile chevron consistent with your app theme if desired
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 2.0,
                            ),
                            title: Text(
                              category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: items.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final title =
                                  (data['title'] as String?) ?? 'Untitled';
                              final storageUrl = data['url'] as String;

                              return ListTile(
                                leading: const Icon(Icons.picture_as_pdf),
                                title: Text(title),
                                trailing: const Icon(Icons.chevron_right),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onTap: () {
                                  // safer, unique filename
                                  openPDF(context, storageUrl, '${doc.id}.pdf');
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}




/* import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makerere_app/models/lectures.dart';
import 'package:makerere_app/screens/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class PresentationListScreen extends StatelessWidget {
  const PresentationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Lecture> lectures = [
      Lecture(title: "Anasplasma", fileName: "anaplasma.pdf"),
      Lecture(title: "Bioterror", fileName: "bioterror.pdf"),
      Lecture(title: "Frostbite", fileName: "frostbite.pdf"),
      Lecture(title: "Mycobacterium abscessus", fileName: "m_abscessus.pdf"),
      Lecture(title: "Neurosyphilis", fileName: "neurosyphilis.pdf"),
    ];

    Future<void> openPDF(BuildContext context, String fileName) async {
      try {
        print("Attempting to load PDF: $fileName from assets...");

        // Get the app's documents directory
        String path = (await getApplicationDocumentsDirectory()).path;
        String assetPath = 'assets/pdfs/$fileName';
        String filePath = '$path/$fileName';

        print("Asset path: $assetPath");
        print("File path in app directory: $filePath");

        // Check if the file already exists in the local directory
        if (!File(filePath).existsSync()) {
          print("File does not exist. Loading PDF from assets...");
          // Load PDF from assets
          ByteData data = await rootBundle.load(assetPath);
          print("Loaded PDF from assets: $fileName");

          // Convert ByteData to list of bytes
          List<int> bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

          // Write the PDF to the app's document directory
          print("Writing PDF to app's document directory...");
          await File(filePath).writeAsBytes(bytes);
          print("PDF written to $filePath");
        } else {
          print("File already exists in app's document directory.");
        }

        // Ensure the context is still mounted before navigation
        if (!context.mounted) return;

        // Navigate to PDF viewer screen
        print("Navigating to PDF viewer...");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PDFScreen(path: filePath)),
        );
      } catch (e) {
        print("Error opening PDF: $e");

        // Show an error message in case of failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open PDF: $e')),
        );
      }
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Tap a lecture to view the PDF",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            SizedBox(
              height: 600,
              child: ListView.builder(
                  itemCount: lectures.length,
                  itemBuilder: (context, index) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                          color: Colors.black,
                        ),
                      ),
                      elevation: 16,
                      shadowColor: Colors.red,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: Colors.redAccent,
                        horizontalTitleGap: 20,
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(lectures[index].title),
                        onTap: () {
                          openPDF(context, lectures[index].fileName);
                        },
                      ),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
 */