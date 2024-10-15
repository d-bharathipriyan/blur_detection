library blur_detection;

import 'dart:io';

import 'package:blur_detection/blur_detect/blur_main.dart';

class BlurDetectionService {
  static Future<bool> isImageBlurred(File selectedFile) async {
    return await BlurMain.isImageBlurred(selectedFile);
  }
}
