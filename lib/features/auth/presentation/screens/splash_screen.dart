import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/splash_intro_provider.dart';

/// Animasi pembentukan logo. Router menunggu animasi ini selesai sebelum
/// membuka login atau dashboard, sementara pemeriksaan sesi tetap berjalan.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _controller.forward().whenComplete(() {
      if (mounted) {
        ref.read(splashIntroCompletedProvider.notifier).state = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(AppConstants.appLogoAsset), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final logoSize = math.min(MediaQuery.sizeOf(context).width * 0.64, 244.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.splashBackground,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.black,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: SafeArea(
          child: Center(
            child: Semantics(
              label: 'KarsaOne sedang dibuka',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final value = _controller.value;
                  final logoOpacity = Curves.easeInOut.transform(
                    _phase(value, 0.36, 0.55),
                  );
                  final reveal = Curves.easeInOutCubic.transform(
                    _phase(value, 0.52, 0.87),
                  );
                  final orbitOpacity = _phase(value, 0.32, 0.45) *
                      (1 - _phase(value, 0.62, 0.75));
                  final settle = Curves.easeOutBack.transform(
                    _phase(value, 0.75, 0.94),
                  );

                  return SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Transform.scale(
                      scale: 0.96 + (0.04 * settle),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < 3; i++)
                            _buildDot(i, logoSize, value),
                          Opacity(
                            opacity: logoOpacity,
                            child: ClipPath(
                              clipper: _LogoRevealClipper(reveal),
                              child: Image.asset(
                                AppConstants.appLogoAsset,
                                width: logoSize,
                                height: logoSize,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          if (orbitOpacity > 0)
                            CustomPaint(
                              size: Size.square(logoSize),
                              painter: _OrbitPainter(value, orbitOpacity),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, double size, double value) {
    final entrance = Curves.easeOutBack.transform(
      _phase(value, 0.08 + index * 0.06, 0.29 + index * 0.06),
    );
    final spread = Curves.easeInOut.transform(_phase(value, 0.30, 0.53));
    final opacity = _phase(value, 0.08 + index * 0.06, 0.25 + index * 0.06) *
        (1 - _phase(value, 0.39, 0.56));
    final diameter = size * (0.11 + (index == 1 ? 0.045 * spread : 0));
    final startX = (index - 1) * 0.21 + 0.5;
    final endX = (index - 1) * 0.29 + 0.5;
    final x = size * (startX + (endX - startX) * spread);
    final y = size * (0.46 - (index == 1 ? 0.14 : 0.09) * spread);

    return Positioned(
      left: x - diameter / 2,
      top: y - diameter / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: entrance,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9AD9FF), Color(0xFF0764EA)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bagian atas logo hadir lebih dulu; batas bergelombang membuka dokumen dan
/// sapuan biru di bawahnya sampai gambar final terlihat utuh.
class _LogoRevealClipper extends CustomClipper<Path> {
  const _LogoRevealClipper(this.reveal);

  final double reveal;

  @override
  Path getClip(Size size) {
    final base = size.height * 0.49;
    final edge = base + (size.height - base + 12) * reveal;
    final amplitude = 8 * math.sin(math.pi * reveal);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, edge);

    for (var step = 16; step >= 0; step--) {
      final x = size.width * step / 16;
      final wave = math.sin((x / size.width * 2 * math.pi) - reveal * math.pi);
      path.lineTo(x, edge + wave * amplitude);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _LogoRevealClipper oldClipper) =>
      oldClipper.reveal != reveal;
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.progress, this.opacity);

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF65B7F7).withValues(alpha: opacity * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final ring = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.32),
      radius: size.width * 0.25,
    );
    final angle = progress * math.pi * 3;
    canvas.drawArc(ring, angle, math.pi * 0.54, false, paint);
    canvas.drawArc(ring, angle + math.pi, math.pi * 0.44, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
