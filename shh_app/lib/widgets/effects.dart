import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';


class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double glitchIntensity;
  final Duration glitchInterval;

  const GlitchText({
    super.key,
    required this.text,
    this.style,
    this.glitchIntensity = 0.03,
    this.glitchInterval = const Duration(milliseconds: 100),
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  late Timer _timer;
  double _offsetX = 0;
  double _offsetY = 0;
  bool _showCyan = false;
  bool _showMagenta = false;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _startGlitch();
  }

  void _startGlitch() {
    _timer = Timer.periodic(widget.glitchInterval, (_) {
      if (_random.nextDouble() < widget.glitchIntensity) {
        setState(() {
          _offsetX = (_random.nextDouble() - 0.5) * 4;
          _offsetY = (_random.nextDouble() - 0.5) * 2;
          _showCyan = _random.nextBool();
          _showMagenta = _random.nextBool();
        });
        
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              _offsetX = 0;
              _offsetY = 0;
              _showCyan = false;
              _showMagenta = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? AppTextStyles.displayLarge;
    
    return Stack(
      children: [
        
        if (_showCyan)
          Transform.translate(
            offset: Offset(_offsetX - 2, _offsetY),
            child: Text(
              widget.text,
              style: baseStyle.copyWith(color: AppColors.cyan.withValues(alpha: 0.7)),
            ),
          ),
        
        if (_showMagenta)
          Transform.translate(
            offset: Offset(_offsetX + 2, _offsetY),
            child: Text(
              widget.text,
              style: baseStyle.copyWith(color: AppColors.hotPink.withValues(alpha: 0.7)),
            ),
          ),
        
        Transform.translate(
          offset: Offset(_offsetX, _offsetY),
          child: Text(widget.text, style: baseStyle),
        ),
      ],
    );
  }
}


class BlinkingCursor extends StatefulWidget {
  final Color color;
  final double width;
  final double height;

  const BlinkingCursor({
    super.key,
    this.color = AppColors.neonGreen,
    this.width = 10,
    this.height = 20,
  });

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> {
  bool _visible = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: widget.color,
      ),
    );
  }
}


class NoiseOverlay extends StatefulWidget {
  final double opacity;
  final Widget child;

  const NoiseOverlay({
    super.key,
    this.opacity = 0.05,
    required this.child,
  });

  @override
  State<NoiseOverlay> createState() => _NoiseOverlayState();
}

class _NoiseOverlayState extends State<NoiseOverlay> {
  late Timer _timer;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _seed++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: NoisePainter(seed: _seed, opacity: widget.opacity),
            ),
          ),
        ),
      ],
    );
  }
}

class NoisePainter extends CustomPainter {
  final int seed;
  final double opacity;
  final Random _random;

  NoisePainter({required this.seed, required this.opacity}) : _random = Random(seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    for (var i = 0; i < 500; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final brightness = _random.nextDouble();
      
      paint.color = Color.fromRGBO(
        (brightness * 255).toInt(),
        (brightness * 255).toInt(),
        (brightness * 255).toInt(),
        opacity,
      );
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, 2, 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant NoisePainter oldDelegate) => oldDelegate.seed != seed;
}


class ScanlineOverlay extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double spacing;

  const ScanlineOverlay({
    super.key,
    required this.child,
    this.opacity = 0.03,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ScanlinePainter(opacity: opacity, spacing: spacing),
            ),
          ),
        ),
      ],
    );
  }
}

class ScanlinePainter extends CustomPainter {
  final double opacity;
  final double spacing;

  ScanlinePainter({required this.opacity, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1;

    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class AsciiLoader extends StatefulWidget {
  final double size;
  final Color color;

  const AsciiLoader({
    super.key,
    this.size = 100,
    this.color = AppColors.neonGreen,
  });

  @override
  State<AsciiLoader> createState() => _AsciiLoaderState();
}

class _AsciiLoaderState extends State<AsciiLoader> {
  int _frame = 0;
  late Timer _timer;

  static const List<String> _frames = [
    '[ ▓░░░░░░░░░ ]',
    '[ ░▓░░░░░░░░ ]',
    '[ ░░▓░░░░░░░ ]',
    '[ ░░░▓░░░░░░ ]',
    '[ ░░░░▓░░░░░ ]',
    '[ ░░░░░▓░░░░ ]',
    '[ ░░░░░░▓░░░ ]',
    '[ ░░░░░░░▓░░ ]',
    '[ ░░░░░░░░▓░ ]',
    '[ ░░░░░░░░░▓ ]',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _frames.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _frames[_frame],
      style: AppTextStyles.code.copyWith(
        color: widget.color,
        fontSize: widget.size / 5,
      ),
    );
  }
}


class HexScrambleText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const HexScrambleText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<HexScrambleText> createState() => _HexScrambleTextState();
}

class _HexScrambleTextState extends State<HexScrambleText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = Random();
  String _displayText = '';
  static const _hexChars = '0123456789ABCDEF';

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addListener(_updateText);
    _controller.forward();
  }

  void _updateText() {
    final progress = _controller.value;
    final revealedLength = (widget.text.length * progress).floor();
    
    setState(() {
      _displayText = widget.text.substring(0, revealedLength) +
        List.generate(
          widget.text.length - revealedLength,
          (_) => _hexChars[_random.nextInt(_hexChars.length)],
        ).join();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style ?? AppTextStyles.code,
    );
  }
}


class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typingSpeed;
  final bool showCursor;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.showCursor = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _charIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.typingSpeed, (_) {
      if (_charIndex < widget.text.length && mounted) {
        setState(() => _charIndex++);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.text.substring(0, _charIndex),
          style: widget.style ?? AppTextStyles.terminal,
        ),
        if (widget.showCursor && _charIndex < widget.text.length)
          const BlinkingCursor(width: 8, height: 16),
      ],
    );
  }
}


class GridBackground extends StatelessWidget {
  final Widget child;
  final Color gridColor;
  final double spacing;
  final double strokeWidth;

  const GridBackground({
    super.key,
    required this.child,
    this.gridColor = const Color(0x0DFFFFFF),
    this.spacing = 30,
    this.strokeWidth = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: GridPainter(
              color: gridColor,
              spacing: spacing,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double strokeWidth;

  GridPainter({
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class CyberBorder extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final double borderWidth;
  final bool showCorners;

  const CyberBorder({
    super.key,
    required this.child,
    this.borderColor = AppColors.neonGreen,
    this.borderWidth = 2,
    this.showCorners = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Stack(
        children: [
          child,
          if (showCorners) ...[
            Positioned(
              top: 0,
              left: 0,
              child: _buildCorner(true, true),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _buildCorner(true, false),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildCorner(false, true),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildCorner(false, false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorner(bool top, bool left) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: borderColor, width: borderWidth + 1) : BorderSide.none,
          bottom: !top ? BorderSide(color: borderColor, width: borderWidth + 1) : BorderSide.none,
          left: left ? BorderSide(color: borderColor, width: borderWidth + 1) : BorderSide.none,
          right: !left ? BorderSide(color: borderColor, width: borderWidth + 1) : BorderSide.none,
        ),
      ),
    );
  }
}


class RandomCounter extends StatefulWidget {
  final int digits;
  final TextStyle? style;
  final Duration interval;

  const RandomCounter({
    super.key,
    this.digits = 8,
    this.style,
    this.interval = const Duration(milliseconds: 50),
  });

  @override
  State<RandomCounter> createState() => _RandomCounterState();
}

class _RandomCounterState extends State<RandomCounter> {
  String _value = '';
  late Timer _timer;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _updateValue();
    _timer = Timer.periodic(widget.interval, (_) => _updateValue());
  }

  void _updateValue() {
    if (mounted) {
      setState(() {
        _value = List.generate(
          widget.digits,
          (_) => _random.nextInt(16).toRadixString(16).toUpperCase(),
        ).join();
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '0x$_value',
      style: widget.style ?? AppTextStyles.code.copyWith(
        color: AppColors.neonGreen.withValues(alpha: 0.5),
        fontSize: 10,
      ),
    );
  }
}
