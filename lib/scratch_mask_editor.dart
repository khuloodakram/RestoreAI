import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A full-resolution black/white mask editor. White strokes mark damaged pixels.
class ScratchMaskEditor extends StatefulWidget {
  const ScratchMaskEditor({super.key, required this.imageBytes, required this.width,
    required this.height, required this.arabic});
  final Uint8List imageBytes;
  final int width, height;
  final bool arabic;
  @override
  State<ScratchMaskEditor> createState() => _ScratchMaskEditorState();
}

class _ScratchMaskEditorState extends State<ScratchMaskEditor> {
  final List<List<Offset>> _strokes = [];
  final List<double> _strokeWidths = [];
  double _brush = 9;
  bool _saving = false;
  String tr(String ar, String en) => widget.arabic ? ar : en;

  Offset _toImage(Offset p, Size size) => Offset(
    (p.dx / size.width * widget.width).clamp(0.0, widget.width.toDouble()),
    (p.dy / size.height * widget.height).clamp(0.0, widget.height.toDouble()));

  Future<Uint8List> _export() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.black, BlendMode.src);
    final paint = Paint()..color = Colors.white..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke
      ..strokeWidth = _brush;
    for (var i = 0; i < _strokes.length; i++) {
      final points = _strokes[i];
      paint.strokeWidth = _strokeWidths[i];
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(points.first, _strokeWidths[i] / 2, Paint()..color = Colors.white);
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) { path.lineTo(point.dx, point.dy); }
        canvas.drawPath(path, paint);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(widget.width, widget.height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Could not export mask');
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تحديد الخدوش', 'Mark scratches')),
      actions: [TextButton(onPressed: _saving ? null : () async {
        setState(() => _saving = true);
        try {
          final result = await _export();
          if (context.mounted) Navigator.pop(context, result);
        } catch (_) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('تعذر حفظ القناع', 'Could not save mask'))));
        } finally { if (mounted) setState(() => _saving = false); }
      }, child: Text(tr('استخدام القناع', 'Use mask')))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text(
        tr('ارسم فوق الخدوش فقط. الأبيض سيُرمَّم، وبقية الصورة ستُحفَظ.',
           'Paint only over scratches. White is repaired; the rest is preserved.'))),
      Expanded(child: Center(child: AspectRatio(
        aspectRatio: widget.width / widget.height,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: (d) => setState(() {
              _strokes.add([_toImage(d.localPosition, size)]);
              _strokeWidths.add(_brush);
            }),
            onPanUpdate: (d) => setState(() => _strokes.last.add(_toImage(d.localPosition, size))),
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(widget.imageBytes, fit: BoxFit.fill),
              CustomPaint(painter: _StrokePreview(_strokes, widget.width.toDouble(),
                widget.height.toDouble(), _strokeWidths)),
            ]));
        })))),
      Row(children: [
        IconButton(onPressed: _strokes.isEmpty ? null : () => setState(() {
            _strokes.removeLast();
            _strokeWidths.removeLast();
          }),
          icon: const Icon(Icons.undo), tooltip: tr('تراجع', 'Undo')),
        IconButton(onPressed: _strokes.isEmpty ? null : () => setState(() {
            _strokes.clear();
            _strokeWidths.clear();
          }),
          icon: const Icon(Icons.delete_outline), tooltip: tr('مسح الكل', 'Clear all')),
        Expanded(child: Slider(value: _brush, min: 2, max: 40,
          label: _brush.round().toString(), onChanged: (v) => setState(() => _brush = v))),
      ]),
    ]));
}

class _StrokePreview extends CustomPainter {
  _StrokePreview(this.strokes, this.width, this.height, this.strokeWidths);
  final List<List<Offset>> strokes;
  final double width, height;
  final List<double> strokeWidths;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / width, size.height / height);
    final paint = Paint()..color = const Color(0xBFFF5252)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    for (var i = 0; i < strokes.length; i++) {
      final points = strokes[i];
      paint.strokeWidth = strokeWidths[i];
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(points.first, strokeWidths[i] / 2, Paint()..color = paint.color);
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) { path.lineTo(point.dx, point.dy); }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _StrokePreview old) => true;
}
