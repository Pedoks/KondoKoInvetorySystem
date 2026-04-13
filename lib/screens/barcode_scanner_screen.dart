import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/constants.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String hintLabel;

  const BarcodeScannerScreen({
    super.key,
    this.hintLabel = 'Align barcode within the frame',
  });

  @override
  State<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
      BarcodeFormat.itf,
    ],
    detectionSpeed: DetectionSpeed.normal,
    autoStart: true,
  );

  bool _hasScanned    = false;
  bool _torchOn       = false;
  String? _previewValue;

  // "Move closer" hint
  Timer?  _moveCloserTimer;
  bool    _showMoveCloser = false;

  // Pulse animation on scan frame
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // Scan-line sweep animation
  late final AnimationController _sweepCtrl;
  late final Animation<double>   _sweepAnim;

  @override
  void initState() {
    super.initState();

    // Pulse border glow
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Sweep line
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _sweepAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sweepCtrl, curve: Curves.linear),
    );

    // Start "move closer" timer — show hint if nothing detected in 2.5s
    _startMoveCloserTimer();
  }

  void _startMoveCloserTimer() {
    _moveCloserTimer?.cancel();
    _moveCloserTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!_hasScanned && mounted) {
        setState(() => _showMoveCloser = true);
      }
    });
  }

  @override
  void dispose() {
    _moveCloserTimer?.cancel();
    _pulseCtrl.dispose();
    _sweepCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final raw     = barcode?.rawValue;

    if (raw != null && raw.isNotEmpty) {
      // Show preview value briefly
      setState(() {
        _previewValue   = raw;
        _showMoveCloser = false;
      });

      // Small delay so user sees the preview, then pop
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!_hasScanned && mounted) {
          _hasScanned = true;
          Navigator.pop(context, raw);
        }
      });
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.primaryColorValue),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Barcode',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellowAccent : Colors.white,
            ),
            onPressed: _toggleTorch,
            tooltip: _torchOn ? 'Torch On' : 'Torch Off',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera ──────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect:   _onDetect,
          ),

          // ── Dark vignette overlay ────────────────────
          _ScanOverlay(),

          // ── Animated scan frame ──────────────────────
          Center(
            child: SizedBox(
              width:  270,
              height: 170,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Stack(
                  children: [
                    // Glow border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_previewValue != null
                                  ? Colors.greenAccent
                                  : const Color(
                                      AppConstants.primaryColorValue))
                              .withOpacity(_pulseAnim.value),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_previewValue != null
                                    ? Colors.greenAccent
                                    : const Color(
                                        AppConstants.primaryColorValue))
                                .withOpacity(_pulseAnim.value * 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Corner brackets
                    ..._buildCorners(),

                    // Sweep line
                    if (_previewValue == null)
                      AnimatedBuilder(
                        animation: _sweepAnim,
                        builder: (_, __) => Positioned(
                          top: _sweepAnim.value * 150,
                          left: 8,
                          right: 8,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(AppConstants
                                          .primaryColorValue)
                                      .withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ✓ tick when detected
                    if (_previewValue != null)
                      Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          size: 48,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Preview value chip ───────────────────────
          if (_previewValue != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.5 + 90,
              left: 24,
              right: 24,
              child: Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade700,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      _previewValue!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom hint / move-closer ────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // "Move closer" hint
                AnimatedOpacity(
                  opacity: _showMoveCloser && _previewValue == null
                      ? 1.0
                      : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Move closer to the barcode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Default hint
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _previewValue != null
                        ? 'Barcode detected!'
                        : widget.hintLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Corner bracket decorations
  List<Widget> _buildCorners() {
    const double size  = 22;
    const double thick = 3.5;
    const color        = Colors.white;
    const radius       = Radius.circular(4);

    return [
      // Top-left
      Positioned(
        top: 0, left: 0,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                top: true, left: true,
                color: color, thick: thick, radius: radius),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0, right: 0,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                top: true, left: false,
                color: color, thick: thick, radius: radius),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0, left: 0,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                top: false, left: true,
                color: color, thick: thick, radius: radius),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0, right: 0,
        child: SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                top: false, left: false,
                color: color, thick: thick, radius: radius),
          ),
        ),
      ),
    ];
  }
}

// ── Dark overlay with a clear window ──────────────────
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return CustomPaint(
      size: size,
      painter: _OverlayPainter(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const windowW = 270.0;
    const windowH = 170.0;
    final cx = size.width  / 2;
    final cy = size.height / 2;

    final paint = Paint()..color = Colors.black.withOpacity(0.55);

    final windowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy), width: windowW, height: windowH),
      const Radius.circular(14),
    );

    final fullPath   = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final windowPath = Path()..addRRect(windowRect);
    final clipped    = Path.combine(PathOperation.difference, fullPath, windowPath);

    canvas.drawPath(clipped, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Corner bracket painter ─────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool   top;
  final bool   left;
  final Color  color;
  final double thick;
  final Radius radius;

  const _CornerPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thick,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = thick
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final double x = left ? 0 : size.width;
    final double y = top  ? 0 : size.height;
    final double dx = left ?  size.width  : -size.width;
    final double dy = top  ?  size.height : -size.height;

    final path = Path()
      ..moveTo(x + dx * 0.05, y)
      ..lineTo(x + dx * 0.85, y)
      ..moveTo(x, y + dy * 0.05)
      ..lineTo(x, y + dy * 0.85);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}