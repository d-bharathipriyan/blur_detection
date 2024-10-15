import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImgCompression {
  static int minHeight = 170, minWidth = 90;

  static Future<File> imageCompression({
    required File picture,
    String? fileType,
  }) async {
    return await changeFormatAndCompressImage(
            image: picture,
            format: fileType?.trim().toLowerCase() ?? 'jpeg',
            sizeLimit: null) ??
        File('');
  }

  static CompressFormat? getFormat(String value) {
    switch (value) {
      case 'jpeg':
        return CompressFormat.jpeg;
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      case 'heic':
        return CompressFormat.heic;
      default:
        return null;
    }
  }

  static Future<File?> changeFormatAndCompressImage({
    required File image,
    String format = 'jpeg',
    required int? sizeLimit,
  }) async {
    try {
      Uint8List? uint8list = await image.readAsBytes();

      int imageSizeInKB =
          uint8list.lengthInBytes ~/ 1024; // Calculate image size in KB
      int quality = 99; // Default initial quality
      print('imageSizeInKB:<1> $imageSizeInKB');
      bool changeImgFormat = true;
      bool isImgAffected = false;
      if (sizeLimit != null && imageSizeInKB > sizeLimit) {
        changeImgFormat = false;
        isImgAffected = true;
        CompressFormat compressFormat =
            getFormat(format) ?? CompressFormat.jpeg;
        // --> Don't remove below method. [Purpose: set image in cache to reduce compressing time]
        uint8list = await FlutterImageCompress.compressWithList(
          uint8list,
          quality: quality,
          minHeight: minHeight,
          minWidth: minWidth,
          format: compressFormat,
        );

        // --> send cache image to find the quality
        quality = await getCompressQuality(
          sizeLimit: sizeLimit,
          tempImg: uint8list,
          format: format,
        );
        // Compress the image until it reaches or is smaller than the limit
        uint8list = await FlutterImageCompress.compressWithList(
          uint8list,
          quality: quality - 1,
          minHeight: minHeight,
          minWidth: minWidth,
          format: compressFormat,
        );
      }
      if (changeImgFormat) {
        isImgAffected = true;
        CompressFormat compressFormat =
            getFormat(format) ?? CompressFormat.jpeg;
        // --> Don't remove below method. [Purpose: set image in cache to reduce compressing time]
        uint8list = await FlutterImageCompress.compressWithList(
          uint8list,
          quality: quality,
          minHeight: minHeight,
          minWidth: minWidth,
          format: compressFormat,
        );
      }
      if (!isImgAffected) {
        return image;
      } else if (uint8list.isNotEmpty) {
        File compressedImage =
            File(image.path.replaceAll(RegExp(r'\.\w+$'), '.$format'));

        await compressedImage.writeAsBytes(uint8list);

        return compressedImage;
      } else {
        print('Compression failed');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  static Future<int> getCompressQuality({
    required Uint8List tempImg,
    required int sizeLimit,
    required String format,
  }) async {
    int quality = 50;

    int compressSize = await getCompressSize(
        uint8list: tempImg, compressSize: quality, format: format);

    if (compressSize == sizeLimit) {
      return quality;
    }

    List<int> sizeList =
        compressSize > sizeLimit ? [40, 30, 20, 10] : [90, 80, 70, 60];
    quality = sizeList.last;

    for (int i = 0; i < sizeList.length; i++) {
      compressSize = await getCompressSize(
          uint8list: tempImg, compressSize: sizeList[i], format: format);
      if (compressSize <= sizeLimit) {
        quality = sizeList[i];
        break;
      }
    }

    if (compressSize == sizeLimit) {
      return quality;
    }

    int tempvalue = quality;
    quality += 5;

    compressSize = await getCompressSize(
        uint8list: tempImg, compressSize: quality, format: format);

    if (compressSize == sizeLimit) {
      return quality;
    }

    sizeList = compressSize > sizeLimit
        ? [
            tempvalue + 4,
            tempvalue + 3,
            tempvalue + 2,
            tempvalue + 1,
          ]
        : [
            tempvalue + 9,
            tempvalue + 8,
            tempvalue + 7,
            tempvalue + 6,
          ];
    quality = sizeList.last;

    for (int i = 0; i < sizeList.length; i++) {
      compressSize = await getCompressSize(
          uint8list: tempImg, compressSize: sizeList[i], format: format);
      if (compressSize <= sizeLimit) {
        quality = sizeList[i];
        break;
      }
    }

    return quality;
  }

  static Future<int> getCompressSize(
      {required Uint8List uint8list,
      required int compressSize,
      required String format}) async {
    // Compress the image until it reaches or is smaller than the limit
    uint8list = await FlutterImageCompress.compressWithList(
      uint8list,
      quality: compressSize,
      minHeight: minHeight,
      minWidth: minWidth,
      format: getFormat(format) ?? CompressFormat.jpeg,
    );
    int imageSizeInKB =
        uint8list.lengthInBytes ~/ 1024; // Calculate image size in KB
    return imageSizeInKB;
  }
}
