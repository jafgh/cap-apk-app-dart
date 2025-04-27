import 'package:flutter/services.dart'; // For rootBundle
import 'package:onnxruntime_flutter/onnxruntime_flutter.dart'; // ONNX Runtime package
import 'package:image/image.dart' as img; // Image processing package
import 'dart:typed_data';

class OnnxService {
  static const String _modelPath = 'assets/ml/holako_bag.onnx'; // Path in assets
  static const int _inputWidth = 224;
  static const int _inputHeight = 224;
  // ONNX Runtime session - lazy loaded
  OrtSession? _session;

  // Character set mapping (must match the model's training)
  static const String _charsetName = '0123456789abcdefghijklmnopqrstuvwxyz';
  static final Map<int, String> _idx2char = {
    for (int i = 0; i < _charsetName.length; i++) i: _charsetName[i]
  };
  static const int _numClasses = 36; // Length of _charsetName
  static const int _numPositions = 5; // Number of characters in captcha

  // Lazy load the ONNX session
  Future<OrtSession> _getSession() async {
    if (_session == null) {
      final sessionOptions = OrtSessionOptions();
      // Consider options like optimization level if needed
      // sessionOptions.setIntraOpNumThreads(1); 
      // sessionOptions.setGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      
      _session = await OrtSession.fromAsset(_modelPath, sessionOptions);
      print("ONNX model loaded successfully from $_modelPath");
    }
    return _session!;
  }

  // Preprocess the image for the ONNX model
  // Takes a binary image (black and white) from image_processor
  Future<List<List<List<List<double>>>>> preprocessImage(img.Image binaryImage) async {
    // 1. Resize the image
    img.Image resizedImage = img.copyResize(binaryImage, width: _inputWidth, height: _inputHeight, interpolation: img.Interpolation.linear);

    // 2. Convert to Float32List and normalize (0-255 -> -1 to 1)
    // The model expects 3 channels (RGB), even if input is grayscale. We replicate the gray channel.
    // ONNX Runtime Flutter often expects input shape [BatchSize, Channels, Height, Width] or [BatchSize, Height, Width, Channels]
    // Let's assume [1, 3, 224, 224] NCHW format for this example (adjust if your model differs)
    
    var inputTensor = List.generate(
        1, // Batch size
        (_) => List.generate(
            3, // Channels (R, G, B)
            (_) => List.generate(
                _inputHeight, // Height
                (_) => List.filled(_inputWidth, 0.0), // Width
                growable: false),
            growable: false),
        growable: false);

    for (int y = 0; y < _inputHeight; y++) {
      for (int x = 0; x < _inputWidth; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // Get luminance (grayscale value) - assuming binary image has R=G=B
        // Normalize from [0, 255] to [-1, 1] using mean=0.5, std=0.5
        // normalized = (pixel_value / 255.0 - 0.5) / 0.5 = (pixel_value / 127.5) - 1.0
        double normalizedValue = (img.getLuminance(pixel) / 127.5) - 1.0; 

        // Assign to all 3 channels (R, G, B)
        inputTensor[0][0][y][x] = normalizedValue; // Red
        inputTensor[0][1][y][x] = normalizedValue; // Green
        inputTensor[0][2][y][x] = normalizedValue; // Blue
      }
    }
    
    return inputTensor;
  }

  // Run inference on the preprocessed image data
  Future<String?> predict(List<List<List<List<double>>>> inputTensor) async {
    try {
      final session = await _getSession();
      
      // Create the ONNX tensor (adjust shape/type if needed)
      final inputOrt = OrtValueTensor.createTensorValueFromList(inputTensor, [1, 3, _inputHeight, _inputWidth]);
      
      // Define input/output names (check your model using Netron or similar tool)
      // Assuming 'input' is the input name and 'output' is the output name
      final inputName = session.inputNames.first; // Or specify directly 'input'
      final outputName = session.outputNames.first; // Or specify directly 'output'

      final runOptions = OrtRunOptions(); // Can configure run options if needed
      final inputs = {inputName: inputOrt};

      print("Running ONNX inference...");
      final startTime = DateTime.now();

      // Run the model
      final outputs = await session.runAsync(runOptions, inputs);
      
      final duration = DateTime.now().difference(startTime);
      print("ONNX inference completed in ${duration.inMilliseconds} ms");


      // Process the output
      final outputValue = outputs[outputName];
      if (outputValue == null) {
        print("Error: Output tensor is null.");
        return null;
      }

      // Output shape is expected to be [BatchSize, NumPositions, NumClasses] e.g., [1, 5, 36]
      // Get the output data as a List
      final outputList = outputValue.value as List; // May need casting based on exact type
      
      // Example assuming output is List<List<List<double>>> or similar nested structure
      if (outputList.isEmpty || outputList[0].isEmpty) {
         print("Error: Output list is empty or invalid structure.");
         return null;
      }

      final batchOutput = outputList[0] as List; // Get the first batch item
      
      String predictedCaptcha = '';
      for (int pos = 0; pos < _numPositions; pos++) {
          // Get the scores for the current position
          final scores = batchOutput[pos] as List; // Should be List<double> of length NumClasses

          // Find the index with the highest score
          double maxScore = -double.infinity;
          int bestIndex = -1;
          for(int i = 0; i < scores.length; i++){
              if (scores[i] is double && scores[i] > maxScore){
                  maxScore = scores[i];
                  bestIndex = i;
              } else if (scores[i] is int && scores[i].toDouble() > maxScore) { 
                  // Handle if output is int for some reason
                   maxScore = scores[i].toDouble();
                   bestIndex = i;
              }
          }
          
          if(bestIndex != -1 && _idx2char.containsKey(bestIndex)) {
              predictedCaptcha += _idx2char[bestIndex]!;
          } else {
              predictedCaptcha += '?'; // Placeholder for unknown character
              print("Warning: Could not find character for index $bestIndex at position $pos");
          }
      }

      outputValue.release(); // Release the output OrtValue
      inputOrt.release();    // Release the input OrtValue
      outputs.values.forEach((element) => element?.release()); // Release all outputs just in case
      print("Predicted Captcha: $predictedCaptcha");
      return predictedCaptcha;

    } catch (e) {
      print('Error during ONNX prediction: $e');
      return null;
    }
  }

  // Dispose the session when done (e.g., in main app dispose)
  void dispose() {
    _session?.release();
    _session = null;
    print("ONNX session released.");
  }
}
