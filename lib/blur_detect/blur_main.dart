import 'dart:async';
import 'dart:io';
import 'package:blur_detection/blur_detect/blur_algorithm.dart';
import 'package:blur_detection/blur_detect/compression.dart';

class BlurMain {
  static Future<bool> isImageBlurred(File selectedFile) async {
    try {
      // Step 1: Copy the file
      String copiedFilePath = '${selectedFile.path}_copy.jpg';
      File copiedFile = await selectedFile.copy(copiedFilePath);

      // Step 2: Compress the copied image
      File compressedFile =
          await ImgCompression.imageCompression(picture: copiedFile);

      // Step 3: Evaluate blurriness on the compressed image
      bool isImageBlur = await evaluateImageSharpness(compressedFile);

      // Step 4: Delete the copied image after processing
      await copiedFile.delete();

      return isImageBlur;
    } catch (e) {
      // Handle errors (e.g., file not found or compression issues)
      return false;
    }
  }
}
