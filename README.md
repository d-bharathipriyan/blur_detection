# Blur Detection

  A Flutter package for detecting blur in images. This package is useful for applications that need to validate image quality and enhance user experience by ensuring that images are clear and sharp.

## Author

Bharathi priyan <d.bharathipriyan@gmail.com>

## Features

- Detects blur levels in images.
- Supports various image formats.

## Platform Support

This package supports the following platforms:

- **Android**
- **iOS**

## Installation

  To use the `blur_detection` package, add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  blur_detection: ^1.0.0
```  

## Usage

  The following example demonstrates how to check if an image is blurred:
```dart
// Example usage code
Future<void> checkImageBlur(File file) async {
  final bool isBlurred = await BlurDetectionService.isImageBlurred(file);

  if (isBlurred) {
    print("The image is blurred.");
  } else {
    print("The image is clear.");
  }
}
```

## Contributing

  We welcome contributions! If you’d like to contribute, please fork the [repository](https://github.com/d-bharathipriyan/blur_detection) and submit a pull request. For major changes, please open an issue first to discuss your proposed changes.

## License

  This project is licensed under the MIT License - see the [LICENSE](https://github.com/d-bharathipriyan/blur_detection/blob/master/LICENSE) file for details.