import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Abstract class for sharpness metrics
abstract class SharpnessMetric {
  double compute(img.Image image);
}

double pixelToGray(img.Image image, int x, int y) {
  if (x < 0 || x >= image.width || y < 0 || y >= image.height) return 0.0;

  final pixel = image.getPixel(x, y);

  // Assuming the pixel object has r, g, b properties
  final red = pixel.r.toDouble();
  final green = pixel.g.toDouble();
  final blue = pixel.b.toDouble();

  // // Convert the pixel to grayscale using the luminosity method
  // return (0.3 * red + 0.59 * green + 0.11 * blue) / 255.0;

  // High-quality grayscale conversion using luminance method
  // This is a refined method that considers human eye sensitivity
  final gray = 0.2126 * red + 0.7152 * green + 0.0722 * blue;

  // Normalize to the range [0, 1]
  return gray / 255.0;
}

// Sobel filter kernel generator
List<List<double>> generateSobelKernel(String direction) {
  if (direction == 'x') {
    return [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
  } else if (direction == 'y') {
    return [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];
  }
  throw ArgumentError('Invalid direction: $direction');
}

// Enhanced Sobel Edge Metric
class EnhancedSobelEdgeMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final sobelX = generateSobelKernel('x');
    final sobelY = generateSobelKernel('y');

    final width = image.width;
    final height = image.height;
    double edgeStrength = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0;
        double gy = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final gray = pixelToGray(image, x + kx, y + ky);
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }
        final magnitude = sqrt(gx * gx + gy * gy);
        edgeStrength += magnitude;
      }
    }

    // Normalize to range [0, 1]
    return edgeStrength / ((width - 2) * (height - 2) * 255);
  }
}

// Enhanced Brenner Focus Measure Metric
class EnhancedBrennerFocusMeasureMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    double sum = 0;
    final width = image.width;
    final height = image.height;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final pixel1 = pixelToGray(image, x - 1, y);
        final pixel2 = pixelToGray(image, x + 1, y);
        final pixel3 = pixelToGray(image, x, y - 1);
        final pixel4 = pixelToGray(image, x, y + 1);

        final dx = pixel2 - pixel1;
        final dy = pixel4 - pixel3;
        final difference = sqrt(dx * dx + dy * dy);

        sum += difference * difference;
      }
    }

    // Normalize the result
    return sum / ((width - 2) * (height - 2));
  }
}

class FrequencyContentMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    // Frequency-based sharpness calculation
    double frequencySharpness = _computeFrequencySharpness(image);

    // High-frequency content-based sharpness calculation
    double highFrequencySharpness = _computeHighFrequencySharpness(image);

    // Combine the two metrics (you can choose how to combine them)
    return (frequencySharpness + highFrequencySharpness) / 2;
  }

  double _computeFrequencySharpness(img.Image image) {
    final width = image.width;
    final height = image.height;
    final data = Float64List(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        data[y * width + x] = _pixelToGray(image, x, y);
      }
    }

    List<double> fft(List<double> real, List<double> imag) {
      final n = real.length;
      if (n <= 1) return real;

      final halfSize = n ~/ 2;
      final evenReal = List<double>.generate(halfSize, (i) => real[i * 2]);
      final evenImag = List<double>.generate(halfSize, (i) => imag[i * 2]);
      final oddReal = List<double>.generate(halfSize, (i) => real[i * 2 + 1]);
      final oddImag = List<double>.generate(halfSize, (i) => imag[i * 2 + 1]);

      fft(evenReal, evenImag);
      fft(oddReal, oddImag);

      for (int k = 0; k < halfSize; k++) {
        final tReal =
            cos(2 * pi * k / n) * oddReal[k] - sin(2 * pi * k / n) * oddImag[k];
        final tImag =
            sin(2 * pi * k / n) * oddReal[k] + cos(2 * pi * k / n) * oddImag[k];
        real[k] = evenReal[k] + tReal;
        imag[k] = evenImag[k] + tImag;
        real[k + halfSize] = evenReal[k] - tReal;
        imag[k + halfSize] = evenImag[k] - tImag;
      }
      return real;
    }

    final real = List<double>.generate(width * height, (i) => data[i]);
    final imag = List<double>.generate(width * height, (i) => 0.0);
    fft(real, imag);

    double sum = 0;
    for (int i = 0; i < real.length; i++) {
      sum += sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }
    return sum / (width * height);
  }

  double _computeHighFrequencySharpness(img.Image image) {
    double sum = 0;
    int count = 0;
    final width = image.width;
    final height = image.height;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double pixelValue = _pixelToGray(image, x, y);
        sum += pixelValue;
        count++;
      }
    }

    if (count == 0) return 0;

    double average = sum / count;
    double variance = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double pixelValue = _pixelToGray(image, x, y);
        variance += (pixelValue - average) * (pixelValue - average);
      }
    }

    return sqrt(variance / count) / 255;
  }

  double _pixelToGray(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    final r = pixel.r;
    final g = pixel.g;
    final b = pixel.b;
    return 0.299 * r + 0.587 * g + 0.114 * b;
  }
}

// Tenengrad Focus Measure (improved)
class TenengradFocusMeasureMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final sobelX = generateSobelKernel('x');
    final sobelY = generateSobelKernel('y');

    double sum = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0;
        double gy = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final gray = pixelToGray(image, x + kx, y + ky);
            gx += gray * sobelX[ky + 1][kx + 1];
            gy += gray * sobelY[ky + 1][kx + 1];
          }
        }
        final magnitude = gx * gx + gy * gy;
        sum += magnitude;
      }
    }
    return sum / ((image.width - 2) * (image.height - 2));
  }
}

// Wavelet Transform Metric (improved)
// Wavelet Transform Metric (improved)
class WaveletTransformMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final width = image.width;
    final height = image.height;
    final data = Float64List(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        data[y * width + x] = pixelToGray(image, x, y);
      }
    }

    List<double> haarTransform(List<double> data, int size) {
      if (size == 1) return data;

      final halfSize = size ~/ 2;
      final result = List<double>.generate(size, (i) => 0.0);

      for (int i = 0; i < halfSize; i++) {
        result[i] = (data[2 * i] + data[2 * i + 1]) / sqrt(2);
        result[halfSize + i] = (data[2 * i] - data[2 * i + 1]) / sqrt(2);
      }

      final transformed = haarTransform(result.sublist(0, halfSize), halfSize);
      transformed.addAll(result.sublist(halfSize, size));
      return transformed;
    }

    final result = haarTransform(data.toList(), width * height);
    double sum = 0;

    for (double value in result) {
      sum += value * value;
    }

    return sqrt(sum) / (width * height);
  }
}

/*
class LaplacianVarianceMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final width = image.width;
    final height = image.height;
    double sum = 0.0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final pixel = pixelToGray(image, x, y);

        double laplacian = -4 * pixel +
            pixelToGray(image, x - 1, y) +
            pixelToGray(image, x + 1, y) +
            pixelToGray(image, x, y - 1) +
            pixelToGray(image, x, y + 1);

        sum += laplacian * laplacian;
        count++;
      }
    }

    return sum / count;
  }
}
*/

class VarianceOfLaplacian implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    // Convert image to grayscale
    List<int> gray = List<int>.filled(width * height, 0);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int pixelIndex = y * width + x;
        final pixel = image.getPixel(x, y);

        // Assuming the pixel object has r, g, b properties
        final red = pixel.r.toDouble();
        final green = pixel.g.toDouble();
        final blue = pixel.b.toDouble();

        gray[pixelIndex] = (0.299 * red + 0.587 * green + 0.114 * blue).toInt();
      }
    }

    // Apply Laplacian filter
    List<int> laplacian = List<int>.filled(width * height, 0);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int pixelIndex = y * width + x;
        int value = (-4 * gray[pixelIndex] +
                gray[pixelIndex - width] +
                gray[pixelIndex + width] +
                gray[pixelIndex - 1] +
                gray[pixelIndex + 1])
            .abs();
        laplacian[pixelIndex] = value;
      }
    }

    // Calculate variance
    double mean = laplacian.reduce((a, b) => a + b) / laplacian.length;
    double variance =
        laplacian.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            laplacian.length;

    return variance;
  }
}

class AutoCorrelationMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    final width = image.width;
    final height = image.height;
    final data = List<double>.generate(
        width * height, (i) => pixelToGray(image, i % width, i ~/ width));

    double mean = data.reduce((a, b) => a + b) / data.length;
    double variance =
        data.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            data.length;

    double autoCorrelation = 0.0;
    for (int offset = 1; offset < width; offset++) {
      double sum = 0.0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width - offset; x++) {
          sum += data[y * width + x] * data[y * width + (x + offset)];
        }
      }
      autoCorrelation += sum / (width * height);
    }

    return autoCorrelation / variance;
  }
}

class LBPSharpnessMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    double lbpSum = 0;
    final width = image.width;
    final height = image.height;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double lbpValue = _calculateLBP(image, x, y);
        lbpSum += lbpValue;
      }
    }

    return lbpSum / ((width - 2) * (height - 2));
  }

  double _calculateLBP(img.Image image, int x, int y) {
    final centerPixel = pixelToGray(image, x, y);
    int lbpValue = 0;

    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;

        final neighborPixel = pixelToGray(image, x + dx, y + dy);
        lbpValue = (lbpValue << 1) | (neighborPixel >= centerPixel ? 1 : 0);
      }
    }

    return lbpValue.toDouble();
  }
}

class ContrastAdjustedVarianceMetric implements SharpnessMetric {
  @override
  double compute(img.Image image) {
    double sum = 0;
    double sumSquared = 0;
    double contrastSum = 0;

    final width = image.width;
    final height = image.height;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final pixel = pixelToGray(image, x, y);
        final contrast = _localContrast(image, x, y);

        sum += pixel;
        sumSquared += pixel * pixel;
        contrastSum += contrast;
      }
    }

    double mean = sum / ((width - 2) * (height - 2));
    double variance =
        (sumSquared / ((width - 2) * (height - 2))) - (mean * mean);
    double adjustedVariance =
        variance / (contrastSum / ((width - 2) * (height - 2)));

    return adjustedVariance;
  }

  double _localContrast(img.Image image, int x, int y) {
    final centerPixel = pixelToGray(image, x, y);
    double contrast = 0;

    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;

        final neighborPixel = pixelToGray(image, x + dx, y + dy);
        contrast += (centerPixel - neighborPixel).abs();
      }
    }

    return contrast / 8.0;
  }
}

// Function to calculate the average brightness of an image
double computeAverageBrightness(img.Image image) {
  double totalBrightness = 0;
  final int width = image.width;
  final int height = image.height;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);

      // Assuming the pixel object has r, g, b properties
      final red = pixel.r.toDouble();
      final green = pixel.g.toDouble();
      final blue = pixel.b.toDouble();

      // Convert to grayscale using luminosity method
      final gray = 0.2126 * red + 0.7152 * green + 0.0722 * blue;

      totalBrightness += gray;
    }
  }

  // Calculate the average brightness
  return totalBrightness / (width * height);
}

double getValueByPercentage({
  required double value,
  required double requiredPercentage,
}) {
  return (value * requiredPercentage) / 100;
}

double getPercentage({
  required double value,
  required double totalValue,
}) {
  if (totalValue == 0) return 0; // To avoid division by zero
  return (value / totalValue) * 100;
}

// Function to load image from file and calculate sharpness metrics
Future<bool> evaluateImageSharpness(File file, {int? index}) async {
  // Load image from file
  final imageBytes = await file.readAsBytes();
  final image = img.decodeImage(Uint8List.fromList(imageBytes))!;

  //final lBPSharpnessMetric = LBPSharpnessMetric().compute(image);

  final varianceOfLaplacian = VarianceOfLaplacian().compute(image);
  if (varianceOfLaplacian < 150) return true;

  final contrastAdjustedVarianceMetric =
      ContrastAdjustedVarianceMetric().compute(image);
  if (contrastAdjustedVarianceMetric < 0.009) return true;

  final frequencyContentMetric = FrequencyContentMetric().compute(image);
  if (frequencyContentMetric < 150) return true;

  final autoCorrelationMetric = AutoCorrelationMetric().compute(image);

  final brightness = computeAverageBrightness(image);

  final tenengradFocusMeasureMetric =
      TenengradFocusMeasureMetric().compute(image);

  final enhancedBrennerFocusMeasureMetric =
      EnhancedBrennerFocusMeasureMetric().compute(image);

  final waveletTransformMetric = WaveletTransformMetric().compute(image);

  List<bool> cases = [
    // case 1:
    (() {
      if (autoCorrelationMetric < 500 && contrastAdjustedVarianceMetric < 2) {
        double contrastAdjustedPercentage =
            getPercentage(value: contrastAdjustedVarianceMetric, totalValue: 2);
        double autoCorrelationPercentage =
            getPercentage(value: autoCorrelationMetric, totalValue: 500);
        double tenengradFocusPercentage =
            getPercentage(value: tenengradFocusMeasureMetric, totalValue: 1);
        double enhancedBrennerFocusPercentage = getPercentage(
            value: enhancedBrennerFocusMeasureMetric, totalValue: 0.2);
        double waveletPercentage =
            getPercentage(value: waveletTransformMetric, totalValue: 0.006);

        double targetAdjustment = 5000 + brightness;

        double adjustedValue = getValueByPercentage(
            value: targetAdjustment,
            requiredPercentage: (contrastAdjustedPercentage +
                    autoCorrelationPercentage +
                    tenengradFocusPercentage +
                    enhancedBrennerFocusPercentage +
                    waveletPercentage) /
                5);

        double requirement = targetAdjustment - adjustedValue;

        double totalMetricSum = varianceOfLaplacian + frequencyContentMetric;

        if (requirement > totalMetricSum) return false;
      }

      double adjustedVarianceOfLaplacian = 1000;
      adjustedVarianceOfLaplacian += (5000 - autoCorrelationMetric) <= 0
          ? 0
          : (5000 - autoCorrelationMetric);

      double adjustedContrastVariance = 1;
      adjustedContrastVariance += (2 - (500 / autoCorrelationMetric)) <= 0
          ? 0
          : (2 - (500 / autoCorrelationMetric));

      double adjustedFrequencyContent = 1000;
      adjustedFrequencyContent += (5000 - autoCorrelationMetric) <= 0
          ? 0
          : (5000 - autoCorrelationMetric);

      double variancePercentage = getPercentage(
          value: varianceOfLaplacian, totalValue: adjustedVarianceOfLaplacian);
      double contrastPercentage = getPercentage(
          value: contrastAdjustedVarianceMetric,
          totalValue: adjustedContrastVariance);
      // double autoCorrelationP =
      //     getPercentage(value: autoCorrelationMetric, totalValue: 5000);
      double frequencyPercentage = getPercentage(
          value: frequencyContentMetric, totalValue: adjustedFrequencyContent);

      double tenengradPercentage =
          getPercentage(value: tenengradFocusMeasureMetric, totalValue: 1);
      double enhancedBrennerPercentage = getPercentage(
          value: enhancedBrennerFocusMeasureMetric, totalValue: 0.2);
      double waveletTransformPercentage =
          getPercentage(value: waveletTransformMetric, totalValue: 0.006);

      double combinedPercentage = variancePercentage +
          contrastPercentage +
          frequencyPercentage +
          ((tenengradPercentage +
                  enhancedBrennerPercentage +
                  waveletTransformPercentage) /
              2);

      double requiredCombinedThreshold = (100 + (brightness / 50));

      bool isAboveThreshold = combinedPercentage > requiredCombinedThreshold;

      return isAboveThreshold;
    })(),

    // case 2:
    (() {
      if (brightness < 200 ||
          contrastAdjustedVarianceMetric > 0.5 ||
          (varianceOfLaplacian >= 2000 &&
              autoCorrelationMetric >= 2000 &&
              frequencyContentMetric >= 2000) ||
          (varianceOfLaplacian +
                  autoCorrelationMetric +
                  frequencyContentMetric >=
              10000)) {
        return true;
      }
      return false;
    })()
  ];

  return cases.contains(false);
}
