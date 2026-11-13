import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restoreai/offline/android_restore_engine.dart';
import 'package:restoreai/offline/restore_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('restoreai/offline_inference');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('reports unavailable if native plugin is missing', () async {
    expect(await AndroidRestoreEngine().isAvailable, isFalse);
  });

  test('refuses to process if native engine is unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return false;
      fail('Must not invoke process without an available engine');
    });
    final engine = AndroidRestoreEngine();
    expect(
      engine.process(const RestoreRequest(
        inputPath: '/photo.png',
        outputPath: '/out.png',
        mode: RestoreMode.naturalEnhance,
      )),
      throwsUnsupportedError,
    );
  });

  test('passes mode and file paths to native processing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'process') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(args['mode'], 'oldPhotoRestore');
        expect(args['inputPath'], '/photo.png');
        expect(args['maxOutputPixels'], 16000000);
        return '/out.png';
      }
      fail('Unexpected method: ${call.method}');
    });
    final result = await AndroidRestoreEngine().process(
      const RestoreRequest(
        inputPath: '/photo.png',
        outputPath: '/out.png',
        mode: RestoreMode.oldPhotoRestore,
      ),
    );
    expect(result.outputPath, '/out.png');
  });

  test('rejects incorrect native output path', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      return '/unexpected.png';
    });
    expect(
      AndroidRestoreEngine().process(const RestoreRequest(
        inputPath: '/photo.png',
        outputPath: '/out.png',
        mode: RestoreMode.proRestore,
      )),
      throwsStateError,
    );
  });
}
