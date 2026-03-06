import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  runApp(const ExpiryScannerApp());
}

class ExpiryScannerApp extends StatelessWidget {
  const ExpiryScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batch & Expiry Scanner',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const ScannerHomePage(),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  File? _image;
  String _extractedText = '';
  String _batchNo = 'Not found';
  String _mfgDate = 'Not found';
  String _expDate = 'Not found';

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  // This acts as our "Memory" for patterns. 
  // We teach the app to look for variations of Batch, Mfg, and Exp.
  void _analyzeText(String text) {
    // Regex for Batch Number (e.g., BATCH, LOT, B.NO followed by letters/numbers)
    RegExp batchPattern = RegExp(r'(?:BATCH|B\.NO|LOT|B)\s*[:.-]?\s*([A-Z0-9]+)', caseSensitive: false);
    
    // Regex for Dates (e.g., MFG, EXP, PROD followed by dates like 12/24, 12-2024, etc.)
    RegExp mfgPattern = RegExp(r'(?:MFG|M|PROD)\s*[:.-]?\s*([0-9]{2}[/-][0-9]{2,4}|[A-Z]{3}\s*[0-9]{2,4})', caseSensitive: false);
    RegExp expPattern = RegExp(r'(?:EXP|E)\s*[:.-]?\s*([0-9]{2}[/-][0-9]{2,4}|[A-Z]{3}\s*[0-9]{2,4})', caseSensitive: false);

    setState(() {
      _batchNo = batchPattern.firstMatch(text)?.group(1) ?? 'Not found';
      _mfgDate = mfgPattern.firstMatch(text)?.group(1) ?? 'Not found';
      _expDate = expPattern.firstMatch(text)?.group(1) ?? 'Not found';
    });
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _extractedText = 'Scanning...';
    });

    final inputImage = InputImage.fromFilePath(pickedFile.path);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    String rawText = recognizedText.text;
    
    setState(() {
      _extractedText = rawText;
    });
    
    // Pass the raw text to our pattern recognizer
    _analyzeText(rawText);
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pattern Scanner')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_image != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(_image!, height: 250),
              )
            else
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No image selected', style: TextStyle(fontSize: 18)),
              ),
            
            // Display Identified Data
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Identified Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ListTile(
                      title: const Text('Batch Number'),
                      trailing: Text(_batchNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('MFG Date'),
                      trailing: Text(_mfgDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    ListTile(
                      title: const Text('EXP Date'),
                      trailing: Text(_expDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),

            // Display Raw Extracted Text (For Debugging/Learning)
            ExpansionTile(
              title: const Text('Show Raw Extracted Text'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_extractedText),
                ),
              ],
            )
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "gallery",
            onPressed: () => _processImage(ImageSource.gallery),
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "camera",
            onPressed: () => _processImage(ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}