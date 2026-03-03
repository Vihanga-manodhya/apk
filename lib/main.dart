import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const SmartProductScannerApp());
}

class SmartProductScannerApp extends StatelessWidget {
  const SmartProductScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Product Scanner',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const AIScannerScreen(),
    );
  }
}

class AIScannerScreen extends StatefulWidget {
  const AIScannerScreen({super.key});

  @override
  State<AIScannerScreen> createState() => _AIScannerScreenState();
}

class _AIScannerScreenState extends State<AIScannerScreen> {
  // --- Your Exact API Key is officially linked here! ---
  static const String _apiKey = 'AIzaSyD4I4p15HALHiGrSR_A61qPKmq3bfkTT7Q'; 
  
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  bool _isProcessing = false;
  String _accumulatedText = ''; // Holds text from the photos
  int _scanCount = 0;
  
  // Parsed Details to show on screen
  String _productName = 'Not found';
  String _batchNo = 'Not found';
  String _mfgDate = 'Not found';
  String _expDate = 'Not found';

  /// 1. Take a picture and read the messy text
  Future<void> _scanSide() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      setState(() {
        _accumulatedText += '\n--- Scan ${++_scanCount} ---\n';
        _accumulatedText += recognizedText.text;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo scanned! Take another photo, or click Analyze.')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading photo: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 2. Send the messy text to Gemini AI to find the Batch and Expiry data
  Future<void> _analyzeWithAI() async {
    if (_accumulatedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take at least one photo first.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Connecting to your Gemini AI model
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      
      final prompt = '''
      You are a helpful data extraction assistant. I am giving you messy text read from a product package. 
      Extract the Product Name, Batch Number (often B/N, Lot), Manufacturing Date (MFD/MFG), and Expiry Date (EXP).
      
      Return ONLY a valid JSON object matching this exact format. If something is missing, write "Not found":
      {"productName": "", "batchNo": "", "mfgDate": "", "expDate": ""}
      
      Here is the text from the package:
      $_accumulatedText
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';
      
      // Clean up the AI's response so Flutter can read it safely
      final jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      setState(() {
        _productName = data['productName'] ?? 'Not found';
        _batchNo = data['batchNo'] ?? 'Not found';
        _mfgDate = data['mfgDate'] ?? 'Not found';
        _expDate = data['expDate'] ?? 'Not found';
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Analysis failed: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 3. Clear the screen to scan a new product
  void _clearScans() {
    setState(() {
      _accumulatedText = '';
      _scanCount = 0;
      _productName = 'Not found';
      _batchNo = 'Not found';
      _mfgDate = 'Not found';
      _expDate = 'Not found';
    });
  }

  /// 4. Save the perfect details to a local text file
  Future<void> _saveToTxt() async {
    if (_batchNo == 'Not found' && _expDate == 'Not found') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No useful data to save yet. Scan and Analyze first!')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/product_db.txt');

      final dataToSave = '''
--- Product Scan (${DateTime.now()}) ---
Product: $_productName
Batch: $_batchNo
MFG: $_mfgDate
EXP: $_expDate
--------------------
\n''';

      await file.writeAsString(dataToSave, mode: FileMode.append);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally to: ${file.path}')),
        );
        _clearScans(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart AI Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_a_photo),
                    label: Text('Take Photo ($_scanCount)'),
                    onPressed: _isProcessing ? null : _scanSide,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  onPressed: _clearScans,
                  tooltip: 'Clear Data',
                )
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analyze with AI'),
              onPressed: _isProcessing || _scanCount == 0 ? null : _analyzeWithAI,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_isProcessing) 
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text('AI Extracted Details:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Product Name: $_productName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      Text('Batch No: $_batchNo'),
                      Text('MFG Date: $_mfgDate'),
                      Text('EXP Date: $_expDate'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save to Local TXT'),
                onPressed: _saveToTxt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16)
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}