/// Contract for RestoreAI's fully offline processing engine.
///
/// No network APIs are permitted in implementations of this interface.
/// An engine must process local file paths and produce a new local output file.
/// The UI should not call an unavailable native engine.
enum RestoreMode { naturalEnhance, oldPhotoRestore, proRestore }

class RestoreRequest {
  const RestoreRequest({
    required this.inputPath,
    required this.outputPath,
    required this.mode,
    this.maxOutputPixels = 16000000,
  });

  final String inputPath;
  final String outputPath;
  final RestoreMode mode;
  final int maxOutputPixels;

  void validate() {
    if (inputPath.trim().isEmpty) {
      throw ArgumentError.value(inputPath, 'inputPath', 'Input path is required');
    }
    if (outputPath.trim().isEmpty) {
      throw ArgumentError.value(outputPath, 'outputPath', 'Output path is required');
    }
    if (inputPath == outputPath) {
      throw ArgumentError('Output must not overwrite the original image');
    }
    if (maxOutputPixels < 1) {
      throw ArgumentError.value(maxOutputPixels, 'maxOutputPixels', 'Must be positive');
    }
  }
}

class RestoreResult {
  const RestoreResult({
    required this.outputPath,
    required this.elapsed,
    required this.engineName,
  });

  final String outputPath;
  final Duration elapsed;
  final String engineName;
}

abstract class OfflineRestoreEngine {
  /// True only when all required on-device models and native libraries exist.
  Future<bool> get isAvailable;

  /// Must never upload the image or make a network request.
  Future<RestoreResult> process(RestoreRequest request);
}

/// Safe default until the Android ncnn/OpenCV engine is implemented and tested.
/// Do not silently return the input file as a successful restoration.
class UnavailableOfflineEngine implements OfflineRestoreEngine {
  const UnavailableOfflineEngine();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<RestoreResult> process(RestoreRequest request) async {
    request.validate();
    throw UnsupportedError(
      'Offline AI engine not installed. No image was modified.',
    );
  }
}
