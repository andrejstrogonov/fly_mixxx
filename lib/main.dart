import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tango EQ Demo',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const EqualizerPage(),
    );
  }
}

enum FilterType { peak, lowShelf, highShelf, bandPass }

class EqualizerBand {
  final double freq;
  String label;
  double gainDb;
  FilterType type;

  EqualizerBand({
    required this.freq,
    required this.label,
    this.gainDb = 0.0,
    this.type = FilterType.peak,
  });
}

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  final List<EqualizerBand> bands = [
    EqualizerBand(freq: 60, label: 'Double Bass'),
    EqualizerBand(freq: 125, label: 'Bandoneon (low)'),
    EqualizerBand(freq: 250, label: 'Piano (low)'),
    EqualizerBand(freq: 500, label: 'Violin (low)'),
    EqualizerBand(freq: 1000, label: 'Bandoneon (mid)'),
    EqualizerBand(freq: 2000, label: 'Violin (high)'),
    EqualizerBand(freq: 4000, label: 'Guitar'),
    EqualizerBand(freq: 8000, label: 'Strings/air'),
  ];

  void applyToAudio() {
    // Хук для интеграции с аудио-движком (в реальном коде)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tango Graphic EQ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // График частотной характеристики
            SizedBox(
              height: 170,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomPaint(
                    painter: EqualizerPainter(bands: bands),
                    size: const Size(double.infinity, double.infinity),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Полосы эквалайзера
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: bands.map((b) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${b.freq.toInt()} Hz',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            width: 40,
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Slider(
                                min: -12,
                                max: 12,
                                value: b.gainDb,
                                onChanged: (v) {
                                  setState(() {
                                    b.gainDb = v;
                                  });
                                  applyToAudio();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${b.gainDb.toStringAsFixed(1)} dB',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 90,
                            child: DropdownButton<FilterType>(
                              isExpanded: true,
                              value: b.type,
                              items: FilterType.values.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(_filterTypeLabel(t),
                                      style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (t) {
                                if (t == null) return;
                                setState(() {
                                  b.type = t;
                                });
                                applyToAudio();
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 100,
                            child: Text(
                              b.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterTypeLabel(FilterType t) {
    switch (t) {
      case FilterType.peak:
        return 'Peak';
      case FilterType.lowShelf:
        return 'Low Shelf';
      case FilterType.highShelf:
        return 'High Shelf';
      case FilterType.bandPass:
        return 'Band Pass';
    }
  }
}

class EqualizerPainter extends CustomPainter {
  final List<EqualizerBand> bands;

  EqualizerPainter({required this.bands});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = Colors.black12;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, paintBg);

    // Сетка
    final gridPaint = Paint()..color = Colors.black26;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Расчет АЧХ на логарифмической оси
    final int points = size.width.toInt().clamp(10, 1000);
    final List<Offset> pts = [];
    const fMin = 20.0;
    const fMax = 20000.0;

    for (int x = 0; x < points; x++) {
      final t = points > 1 ? x / (points - 1) : 0.5;
      final freq = fMin * pow(fMax / fMin, t).toDouble();
      double mag = 0.0;

      for (final b in bands) {
        final bw = _bandwidthForType(b.type);
        final lnf = log(freq);
        final lnCenter = log(b.freq);
        final gauss = exp(-0.5 * pow((lnf - lnCenter) / bw, 2).toDouble());
        mag += b.gainDb * gauss;
      }

      final yNorm = (mag + 18) / 36;
      final y = size.height * (1 - yNorm.clamp(0.0, 1.0));
      pts.add(Offset(x.toDouble(), y));
    }

    final path = Path();
    if (pts.isNotEmpty) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }

    // Заливка под кривой
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.deepPurple.withValues(alpha: 0.5),
          Colors.transparent
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final closed = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(closed, fillPaint);

    // Кривая АЧХ
    final curvePaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, curvePaint);
  }

  double _bandwidthForType(FilterType t) {
    switch (t) {
      case FilterType.peak:
        return 0.45;
      case FilterType.lowShelf:
        return 1.6;
      case FilterType.highShelf:
        return 1.6;
      case FilterType.bandPass:
        return 0.25;
    }
  }

  @override
  bool shouldRepaint(covariant EqualizerPainter oldDelegate) {
    if (oldDelegate.bands.length != bands.length) return true;
    for (int i = 0; i < bands.length; i++) {
      if (oldDelegate.bands[i].gainDb != bands[i].gainDb ||
          oldDelegate.bands[i].type != bands[i].type) {
        return true;
      }
    }
    return false;
  }
}

