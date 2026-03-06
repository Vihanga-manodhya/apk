import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// 🛑 PASTE YOUR GEMINI API KEY HERE 🛑
const String apiKey = 'AIzaSyD4I4p15HALHiGrSR_A61qPKmq3bfkTT7Q';

void main() {
  runApp(const ExpiryScannerApp());
}

class ExpiryScannerApp extends StatelessWidget {
  const ExpiryScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Label Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
  bool _isScanning = false;

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  // --- THE NEW GENERATIVE AI BRAIN ---
  Future<void> _analyzeTextWithAI(String rawText) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => _extractedText = '⚠️ ERROR: Please add your Gemini API Key in the code.');
      return;
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    // This is the prompt. We tell the AI exactly what your rules are.
    final prompt = '''
    You are an expert pharmaceutical label reader. Extract the following data from the OCR text below:
    
    1. Batch Number: Look for Batch No, Bno, Lot No, B.No., Lot, Btach.No, B/No, LOT, B.NO, BATCH NO, BN, Lt, or related typos.
    2. Manufacturing Date: Look for MFG, Mfg, manucatudate, MFD, Mfd, mfg.date, MFG Date, D/ Mfg, MF, PROD, or related typos.
    3. Expiry Date: Look for EXP, exp, expd, exp date, expiry date, Exp. date, EX, or related typos.
    
    Clean up the dates if necessary. 
    You MUST return ONLY a raw JSON object. Do not use markdown blocks. Do not add any other text.
    Format exactly like this: {"batch": "value", "mfg": "value", "exp": "value"}
    If a value is truly missing, output "Not found".
    
    OCR TEXT:
    $rawText
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      
      // Clean up the AI's response just in case it added markdown ticks (```json)
      String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Convert the JSON string into Dart variables
      final Map<String, dynamic> data = jsonDecode(cleanJson);

      setState(() {
        _batchNo = data['batch'] ?? 'Not found';
        _mfgDate = data['mfg'] ?? 'Not found';
        _expDate = data['exp'] ?? 'Not found';
      });

    } catch (e) {
      setState(() {
        _extractedText = 'AI Parsing Error: $e\n\nRaw Text was:\n$rawText';
      });
    }
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _isScanning = true;
      _extractedText = 'Step 1: Reading image...';
      _batchNo = '...';
      _mfgDate = '...';
      _expDate = '...';
    });

    try {
      // Step 1: Extract raw text with ML Kit
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      String rawText = recognizedText.text;
      
      setState(() {
        _extractedText = 'Step 2: AI is analyzing data...';
      });
      
      // Step 2: Pass raw text to Gemini AI to figure out the mess
      await _analyzeTextWithAI(rawText);
      
      setState(() {
        _extractedText = rawText; // Show the raw text in the debug drawer later
      });
      
    } catch (e) {
      setState(() {
        _extractedText = 'Error reading image: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ... (The build method and _buildResultRow remain exactly the same as the previous code)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Label Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              color: Colors.grey[200],
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.contain)
                  : const Center(
                      child: Text('No image selected.\nTap a button below to start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54)),
                    ),
            ),
            if (_isScanning)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_extractedText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (!_isScanning && _image != null)
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('AI Extracted Data', 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      const Divider(height: 30, thickness: 2),
                      _buildResultRow(Icons.numbers, 'Batch / Lot No.', _batchNo),
                      const Divider(),
                      _buildResultRow(Icons.precision_manufacturing, 'MFG Date', _mfgDate),
                      const Divider(),
                      _buildResultRow(Icons.event_busy, 'EXP Date', _expDate),
                    ],
                  ),
                ),
              ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ExpansionTile(
                  title: const Text('Show Raw OCR Text (For Debugging)', style: TextStyle(color: Colors.grey)),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.grey[100],
                      width: double.infinity,
                      child: SelectableText(_extractedText, style: const TextStyle(fontFamily: 'monospace')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "gallery",
            onPressed: () => _processImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "camera",
            onPressed: () => _processImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value) {
    Color valueColor = value == 'Not found' ? Colors.red : Colors.black87;
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}