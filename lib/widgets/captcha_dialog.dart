import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // Image package
import '../models/account.dart';
import '../models/process_info.dart';
import '../services/api_service.dart';
import '../services/onnx_service.dart';
import '../utils/image_processor.dart'; // Import image processor

class CaptchaDialog extends StatefulWidget {
  final String base64Captcha;
  final Account account;
  final ProcessInfo processInfo;
  final ApiService apiService;
  final Function(String message, Color color) onResult; // Callback for result

  const CaptchaDialog({
    super.key,
    required this.base64Captcha,
    required this.account,
    required this.processInfo,
    required this.apiService,
    required this.onResult,
  });

  @override
  State<CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<CaptchaDialog> {
  final OnnxService _onnxService = OnnxService();
  img.Image? _processedImage; // Processed image (binary) for ONNX
  Uint8List? _displayImageBytes; // Raw bytes for display
  String? _predictedSolution;
  String _status = "Processing image...";
  bool _isLoading = true;
  double _preprocessTime = 0;
  double _predictTime = 0;

  @override
  void initState() {
    super.initState();
    _processAndPredict();
  }

  @override
  void dispose() {
     // Avoid disposing the shared ONNX service here unless it's truly dialog-specific
     // _onnxService.dispose(); 
    super.dispose();
  }

  Future<void> _processAndPredict() async {
     if (!mounted) return;
    setState(() { _isLoading = true; _status = "Processing image..."; });

    // --- Image Processing ---
    final startTimePreprocess = DateTime.now();
    _processedImage = ImageProcessor.processCaptchaImage(widget.base64Captcha);
    final durationPreprocess = DateTime.now().difference(startTimePreprocess);
    _preprocessTime = durationPreprocess.inMilliseconds.toDouble();

    if (_processedImage == null) {
       if (mounted) setState(() { _status = "Error: Could not process image."; _isLoading = false; });
      return;
    }

    // Prepare display bytes (optional, can display processed or original)
    // Let's display the processed (binary) image for verification
    _displayImageBytes = Uint8List.fromList(img.encodePng(_processedImage!)); 
    if (mounted) setState(() { _status = "Image processed. Predicting..."; });


    // --- ONNX Prediction ---
    try {
       // Preprocess for ONNX model input
       final inputTensor = await _onnxService.preprocessImage(_processedImage!);
       
       // Run prediction
       final startTimePredict = DateTime.now();
       _predictedSolution = await _onnxService.predict(inputTensor);
       final durationPredict = DateTime.now().difference(startTimePredict);
       _predictTime = durationPredict.inMilliseconds.toDouble();


       if (mounted) {
         setState(() {
           if (_predictedSolution != null) {
             _status = "Predicted: $_predictedSolution\nSubmitting...";
             _submitSolution(_predictedSolution!);
           } else {
             _status = "Error: Prediction failed.";
             _isLoading = false;
           }
         });
       }

    } catch(e) {
       if (mounted) setState(() { _status = "Error during prediction: $e"; _isLoading = false; });
    }
  }

  Future<void> _submitSolution(String solution) async {
    final result = await widget.apiService.submitCaptcha(widget.processInfo.processId, solution);
    
    if (mounted) {
       setState(() {
         _isLoading = false;
         _status = "Submit Response (${result['statusCode']}):\n${result['body']}";
       });
       // Use the callback to notify HomeScreen
       widget.onResult(
          "Submit Status for ${widget.processInfo.centerName}: ${result['success'] ? 'Success' : 'Failed'} (${result['statusCode']})", 
          result['success'] ? Colors.green : Colors.red
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Captcha for ${widget.processInfo.centerName}'),
      content: SingleChildScrollView( // Allow scrolling if content is large
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            if (_displayImageBytes != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                // Display the processed binary image
                child: Image.memory(_displayImageBytes!, gaplessPlayback: true), 
              ),
            Text(_status),
             if (!_isLoading && (_preprocessTime > 0 || _predictTime > 0))
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(
                   'Preprocess: ${_preprocessTime.toStringAsFixed(1)} ms | Predict: ${_predictTime.toStringAsFixed(1)} ms',
                   style: Theme.of(context).textTheme.bodySmall,
                 ),
               ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // Only allow closing if not loading
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
