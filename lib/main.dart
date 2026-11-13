import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const RestoreAIApp());

class RestoreAIApp extends StatelessWidget {
  const RestoreAIApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RestoreAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1020),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8665FF),
            brightness: Brightness.dark,
          ),
        ),
        home: const RestoreHome(),
      );
}

class RestoreHome extends StatefulWidget {
  const RestoreHome({super.key});

  @override
  State<RestoreHome> createState() => _RestoreHomeState();
}

class _RestoreHomeState extends State<RestoreHome> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selected;
  String? _error;

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _selected = image;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RestoreAI', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.auto_awesome, color: Color(0xFFAA95FF), size: 48),
            const SizedBox(height: 16),
            const Text('Bring your photos back to life',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Select a photo to prepare it for AI enhancement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFADB2CA), fontSize: 15)),
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
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 68, color: Color(0xFFAA95FF)),
                        SizedBox(height: 16),
                        Text('No photo selected',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : Image.file(File(_selected!.path), fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(child: Text('Unable to display image'))),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: const Color(0xFF7658EB),
              ),
            ),
            const SizedBox(height: 12),
            const FilledButton.icon(
              onPressed: null,
              icon: Icon(Icons.auto_fix_high),
              label: Text('Enhance photo — coming after Android AI verification'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const Text(
              'Phase 2 prototype: photo selection is enabled. AI enhancement is deliberately disabled until the NCNN Android integration passes real inference tests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8990AB), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
