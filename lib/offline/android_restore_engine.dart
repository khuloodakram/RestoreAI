import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'restore_pipeline.dart';

/// Flutter-to-Android bridge for a future native, fully offline model runtime.
///
/// This class deliberately fails closed until native code reports that
/// verified model weights and inference libraries are installed.
class AndroidRestoreEngine implements OfflineRestoreEngine {
  AndroidRestoreEngine({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('restoreai/offline_inference');

  final MethodChannel _channel;

  @override
  Future<bool> get isAvailable async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<RestoreResult> process(RestoreRequest request) async {
    request.validate();
    if (!await isAvailable) {
      throw UnsupportedError('Offline AI engine is not installed.');
    }
    final stopwatch = Stopwatch()..start();
    final path = await _channel.invokeMethod<String>(
      'process',
      <String, Object>{
        'inputPath': request.inputPath,
        'outputPath': request.outputPath,
        'mode': request.mode.name,
        'maxOutputPixels': request.maxOutputPixels,
      },
    );
    stopwatch.stop();
    if (path == null || path != request.outputPath) {
      throw StateError('Native inference returned an unexpected output path.');
    }
    return RestoreResult(
      outputPath: path,
      elapsed: stopwatch.elapsed,
      engineName: 'Android native offline inference',
    );
  }
}
