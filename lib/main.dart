import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const RestoreAIApp());

class RestoreAIApp extends StatefulWidget {
  const RestoreAIApp({super.key});

  @override
  State<RestoreAIApp> createState() => _RestoreAIAppState();
}

class _RestoreAIAppState extends State<RestoreAIApp> {
  bool arabic = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RestoreAI',
      debugShowCheckedModeBanner: false,
      locale: Locale(arabic ? 'ar' : 'en'),
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
  String? _error;

  String tr(String ar, String en) => widget.arabic ? ar : en;

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _selected = image;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('تعذر فتح معرض الصور. حاولي مرة أخرى.',
            'Could not open the gallery. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          const SizedBox(width: 8),
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
            Text(
              tr('أعيدي الحياة إلى صورك', 'Bring your photos back to life'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              tr('اختاري صورة لتجهيزها للتحسين بالذكاء الاصطناعي.',
                  'Select a photo to prepare it for AI enhancement.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFADB2CA), fontSize: 15),
            ),
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
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            size: 68, color: Color(0xFFAA95FF)),
                        const SizedBox(height: 16),
                        Text(
                          tr('لم يتم اختيار صورة', 'No photo selected'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Image.file(
                      File(_selected!.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(tr('تعذر عرض الصورة',
                            'Unable to display image')),
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(tr('اختيار صورة', 'Choose photo')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: const Color(0xFF7658EB),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(tr('تحسين الصورة — قريبًا',
                  'Enhance photo — coming soon')),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            Text(
              tr('التحسين غير مفعّل حتى نتأكد من اتصال التطبيق بخادم الذكاء الاصطناعي.',
                  'Enhancement will be enabled after the AI server connection is verified.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF8990AB), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
