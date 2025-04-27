import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessor {

  // Decodes Base64, decodes GIF, takes first frame, converts to grayscale, applies threshold
  static img.Image? processCaptchaImage(String base64Captcha) {
    try {
      // 1. Decode Base64
      // Remove data URI prefix if present (e.g., "data:image/gif;base64,")
      String base64Data = base64Captcha.split(',').last;
      Uint8List imageBytes = base64Decode(base64Data);

      // 2. Decode GIF
      img.Animation? animation = img.decodeGifAnimation(imageBytes);
      if (animation == null || animation.isEmpty) {
        // Try decoding as a static image (PNG, JPG) as fallback
        img.Image? staticImage = img.decodeImage(imageBytes);
        if (staticImage == null) {
          print("Error: Could not decode image data (not GIF or other known format).");
          return null;
        }
         print("Decoded as static image (not GIF). Using it.");
         return _processFrame(staticImage);
      }

      // 3. Use the first frame of the GIF
      img.Image firstFrame = animation.first;
      print("Decoded GIF, using first frame (${firstFrame.width}x${firstFrame.height}).");

      return _processFrame(firstFrame);

    } catch (e) {
      print("Error processing captcha image: $e");
      return null;
    }
  }
  
  // Helper to process a single image frame (grayscale and threshold)
  static img.Image _processFrame(img.Image frame) {
      // 4. Convert to Grayscale
      img.Image grayscaleImage = img.grayscale(frame);

      // 5. Apply a simple fixed threshold (Otsu is complex to implement)
      // Make pixels darker than threshold black (0), others white (255)
      const int thresholdValue = 128; // Adjust this threshold value as needed
      for (int y = 0; y < grayscaleImage.height; y++) {
        for (int x = 0; x < grayscaleImage.width; x++) {
          var pixel = grayscaleImage.getPixel(x, y);
          // Use luminance which is calculated correctly by image package for grayscale
          int luminance = img.getLuminance(pixel); 
          if (luminance < thresholdValue) {
            grayscaleImage.setPixelRgba(x, y, 0, 0, 0, 255); // Black
          } else {
            grayscaleImage.setPixelRgba(x, y, 255, 255, 255, 255); // White
          }
        }
      }
      print("Applied grayscale and fixed threshold ($thresholdValue).");
      return grayscaleImage; // Return the binary (black/white) image
  }
}
