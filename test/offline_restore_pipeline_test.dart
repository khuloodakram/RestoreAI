import 'package:flutter_test/flutter_test.dart';
import 'package:restoreai/offline/restore_pipeline.dart';

void main() {
  test('rejects missing input path', () {
    expect(
      () => const RestoreRequest(
        inputPath: '',
        outputPath: '/tmp/out.png',
        mode: RestoreMode.naturalEnhance,
      ).validate(),
      throwsArgumentError,
    );
  });

  test('never overwrites the original', () {
    expect(
      () => const RestoreRequest(
        inputPath: '/tmp/photo.png',
        outputPath: '/tmp/photo.png',
        mode: RestoreMode.oldPhotoRestore,
      ).validate(),
      throwsArgumentError,
    );
  });

  test('valid request passes validation', () {
    const request = RestoreRequest(
      inputPath: '/tmp/photo.png',
      outputPath: '/tmp/restored.png',
      mode: RestoreMode.proRestore,
    );
    expect(request.validate, returnsNormally);
  });

  test('unavailable engine cannot report success', () async {
    const engine = UnavailableOfflineEngine();
    expect(await engine.isAvailable, isFalse);
    expect(
      engine.process(const RestoreRequest(
        inputPath: '/tmp/photo.png',
        outputPath: '/tmp/out.png',
        mode: RestoreMode.naturalEnhance,
      )),
      throwsUnsupportedError,
    );
  });
}
