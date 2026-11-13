import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const String apiUrl = String.fromEnvironment('RESTOREAI_API_URL');

void main() => runApp(const RestoreAIApp());

class RestoreAIApp extends StatefulWidget {
  const RestoreAIApp({super.key});

  @override
  State<RestoreAIApp> createState() => _RestoreAIAppState();
}

class _RestoreAIAppState extends State<RestoreAIApp> {
  bool arabic = true;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RestoreAI',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => Directionality(
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1020),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8665FF),
            brightness: Brightness.dark,
          ),
        ),
        home: RestoreHome(
          arabic: arabic,
          onLanguageChanged: (value) => setState(() => arabic = value),
        ),
      );
}

class RestoreHome extends StatefulWidget {
  const RestoreHome({
    super.key,
    required this.arabic,
    required this.onLanguageChanged,
  });

  final bool arabic;
  final ValueChanged<bool> onLanguageChanged;

  @override
  State<RestoreHome> createState() => _RestoreHomeState();
}

class _RestoreHomeState extends State<RestoreHome> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selected;
  Uint8List? _enhanced;
  String? _savedPath;
  String? _error;
  bool _busy = false;
  bool _showAfter = true;

  String tr(String ar, String en) => widget.arabic ? ar : en;

  Future<void> _pickImage() async {
    if (_busy) return;
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _selected = image;
        _enhanced = null;
        _savedPath = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('تعذر فتح معرض الصور.',
            'Could not open the photo gallery.'));
      }
    }
  }

  Future<void> _enhance() async {
    if (_selected == null || _busy || apiUrl.isEmpty) return;
    final endpoint = Uri.tryParse(apiUrl);
    if (endpoint == null || endpoint.scheme != 'https' ||
        endpoint.host.isEmpty || endpoint.userInfo.isNotEmpty) {
      setState(() => _error = tr('عنوان الخادم غير آمن أو غير صالح.',
          'The server URL is invalid or insecure.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _savedPath = null;
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final bytes = await _selected!.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('file_too_large');
      }
      final request = await client.postUrl(endpoint.resolve('/enhance'));
      // Upload as multipart/form-data, matching FastAPI's "image" field.
      final boundary = 'restoreai-upload-boundary';
      request.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');
      final extension = _selected!.name.toLowerCase().split('.').last;
      final mime = extension == 'png' ? 'image/png'
          : extension == 'webp' ? 'image/webp' : 'image/jpeg';
      final name = extension == 'png' ? 'photo.png'
          : extension == 'webp' ? 'photo.webp' : 'photo.jpg';
      request.add(utf8Bytes('--$boundary\r\n'
          'Content-Disposition: form-data; name="image"; filename="$name"\r\n'
          'Content-Type: $mime\r\n\r\n'));
      request.add(bytes);
      request.add(utf8Bytes('\r\n--$boundary--\r\n'));
      final response = await request.close().timeout(const Duration(minutes: 3));
      const maxResponseBytes = 96 * 1024 * 1024;
      if (response.contentLength > maxResponseBytes) {
        throw const FormatException('response_too_large');
      }
      final result = await response.fold<List<int>>(
          <int>[], (previous, chunk) {
            if (previous.length + chunk.length > maxResponseBytes) {
              throw const FormatException('response_too_large');
            }
            return previous..addAll(chunk);
          })
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType != 'image/png') {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (!mounted) return;
      setState(() {
        _enhanced = Uint8List.fromList(result);
        _showAfter = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr(
            'فشل التحسين. يرجى التحقق من تشغيل خادم الذكاء الاصطناعي ثم إعادة المحاولة.',
            'Enhancement failed. Check that the AI server is running and retry.'));
      }
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<int> utf8Bytes(String value) => value.codeUnits.every((c) => c < 128)
      ? value.codeUnits
      : throw const FormatException('Non-ASCII multipart header');

  Future<void> _save() async {
    if (_enhanced == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/restoreai_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_enhanced!, flush: true);
      if (mounted) setState(() => _savedPath = file.path);
    } catch (_) {
      if (mounted) setState(() => _error = tr('تعذر حفظ الصورة.',
          'Unable to save the image.'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('RestoreAI',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          actions: [
            TextButton.icon(
              onPressed: () => widget.onLanguageChanged(!widget.arabic),
              icon: const Icon(Icons.language),
              label: Text(widget.arabic ? 'English' : 'العربية'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.auto_awesome,
                  color: Color(0xFFAA95FF), size: 48),
              const SizedBox(height: 16),
              Text(tr('صورك تستحق حياة جديدة',
                  'Bring your photos back to life'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(tr('تحسين تفاصيل الصور بالذكاء الاصطناعي.',
                  'Enhance photo details with AI.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Container(
                height: 320,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2035),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF343A58)),
                ),
                child: _selected == null
                    ? Center(child: Text(tr('لم يتم اختيار صورة',
                        'No photo selected')))
                    : _enhanced != null && _showAfter
                        ? Image.memory(_enhanced!, fit: BoxFit.contain)
                        : Image.file(File(_selected!.path),
                            fit: BoxFit.contain),
              ),
              if (_enhanced != null) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false,
                        label: Text(tr('قبل', 'Before'))),
                    ButtonSegment(value: true,
                        label: Text(tr('بعد', 'After'))),
                  ],
                  selected: {_showAfter},
                  onSelectionChanged: (value) =>
                      setState(() => _showAfter = value.first),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(tr('اختيار صورة', 'Choose photo')),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selected != null && !_busy && apiUrl.isNotEmpty
                    ? _enhance : null,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(_busy ? tr('جارٍ التحسين...', 'Enhancing...')
                    : tr('تحسين الصورة', 'Enhance photo')),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_enhanced != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_alt),
                  label: Text(tr('حفظ داخل التطبيق', 'Save in app storage')),
                ),
              ],
              if (_savedPath != null)
                SelectableText(tr('تم الحفظ داخل ملفات التطبيق: ',
                    'Saved to app files: ') + _savedPath!),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              if (apiUrl.isEmpty)
                Text(tr('ميزة التحسين تحتاج إلى خادم HTTPS مُعدّ مسبقًا.',
                    'Enhancement requires a configured HTTPS server.'),
                    textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Text(tr('ملاحظة: تحسين الدقة لا يزيل الخدوش تلقائيًا.',
                  'Note: Super-resolution does not automatically remove scratches.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8990AB),
                      fontSize: 12)),
            ],
          ),
        ),
      );
}
