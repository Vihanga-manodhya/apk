import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart'; 

// 🛑 PASTE YOUR SECURE GEMINI API KEY HERE 🛑
// DO NOT use the one you pasted in the chat earlier, as it is now public.
const String apiKey = 'AIzaSyArhwwlC3EdE4kE_yfyOyVXB7D7soh6gzg';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

  // --- SAVE TO TXT FUNCTION ---
  Future<void> _saveToTxtFile() async {
    if (_batchNo == 'Not found' && _mfgDate == 'Not found' && _expDate == 'Not found') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan a label first before saving!')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/scanned_labels.txt');
      
      final timestamp = DateTime.now().toString().split('.')[0];
      final dataToSave = '--- Scan at $timestamp ---\nBatch: $_batchNo\nMFG: $_mfgDate\nEXP: $_expDate\n\n';
      
      await file.writeAsString(dataToSave, mode: FileMode.append);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Saved successfully to TXT file!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error saving file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- THE BULLETPROOF GENERATIVE AI BRAIN ---
  Future<void> _analyzeTextWithAI(String rawText) async {
    if (apiKey == 'AIzaSyArhwwlC3EdE4kE_yfyOyVXB7D7soh6gzg' || apiKey.isEmpty) {
      setState(() {
        _extractedText = '⚠️ ERROR: You forgot to paste your Gemini API Key at the top of the code!';
        _batchNo = 'API Key Missing';
        _mfgDate = 'API Key Missing';
        _expDate = 'API Key Missing';
      });
      return;
    }

    // This config FORCES the AI to only output JSON, preventing parsing crashes
    final model = GenerativeModel(
      model: 'gemini-1.5-flash', 
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', 
      ),
    );

    final prompt = '''
    Extract the pharmaceutical label data from the OCR text below.
    Return ONLY a JSON object with exactly these three keys: "batch", "mfg", "exp".
    If a value is missing, use the string "Not found".
    
    RULES:
    1. Batch ("batch"): Look for Batch No, Bno, Lot No, B.No., Lot, Btach.No, B/No, LOT, B.NO, BATCH NO, BN, Lt, etc.
    2. Manufacturing Date ("mfg"): Look for MFG, Mfg, manucatudate, MFD, Mfd, mfg.date, MFG Date, D/ Mfg, MF, PROD.
    3. Expiry Date ("exp"): Look for EXP, exp, expd, exp date, expiry date, Exp. date, EX.

    OCR TEXT:
    $rawText
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      
      // Because we forced JSON mode, we decode directly
      final Map<String, dynamic> data = jsonDecode(response.text!);

      setState(() {
        _batchNo = data['batch']?.toString() ?? 'Not found';
        _mfgDate = data['mfg']?.toString() ?? 'Not found';
        _expDate = data['exp']?.toString() ?? 'Not found';
      });
      
    } catch (e) {
      setState(() {
        _extractedText = 'CRITICAL ERROR: $e\n\nRaw Text was:\n$rawText';
        _batchNo = 'Error';
        _mfgDate = 'Error';
        _expDate = 'Error';
      });
    }
  }

  // --- THE SCANNING PROCESS ---
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
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      String rawText = recognizedText.text;
      
      setState(() {
        _extractedText = 'Step 2: AI is analyzing data...';
      });
      
      await _analyzeTextWithAI(rawText);
      
      setState(() {
        _extractedText = rawText; 
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

  // --- THE UI ---
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
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveToTxtFile,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Data to TXT File', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.deepPurple[100],
                          ),
                        ),
                      )
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
    Color valueColor = (value == 'Not found' || value == 'Error' || value == 'API Key Missing') 
        ? Colors.red : Colors.black87;
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