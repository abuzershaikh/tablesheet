import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../copilot_chat_screen.dart';

class SheetproAiFloatingBot extends StatefulWidget {
  final String sheetId;
  final Function(Map<String, dynamic>)? onPipelineApplied;
  final VoidCallback? onDismiss;

  const SheetproAiFloatingBot({
    super.key,
    required this.sheetId,
    this.onPipelineApplied,
    this.onDismiss,
  });

  @override
  State<SheetproAiFloatingBot> createState() => _SheetproAiFloatingBotState();
}

class _SheetproAiFloatingBotState extends State<SheetproAiFloatingBot> with TickerProviderStateMixin {
  Offset? _position;
  late AnimationController _rotateController;
  late AnimationController _glowController;
  late AnimationController _sparkleController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Continuous 360-degree rotating gradient border
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Subtle pulsing neon glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Sparkles / Sprinkles radiating outward from border
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _glowController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _openCopilot() {
    CopilotFullScreenChatScreen.open(
      context,
      sheetId: widget.sheetId,
      onPipelineApplied: widget.onPipelineApplied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Balanced Medium Dimensions: 114 wide x 128 tall
    const widgetWidth = 114.0;
    const widgetHeight = 128.0;

    // Default position: bottom-right above formula / bottom bar
    final defaultX = screenSize.width - widgetWidth - 14.0;
    final defaultY = screenSize.height - widgetHeight - 75.0;

    final currentX = _position?.dx ?? defaultX;
    final currentY = _position?.dy ?? defaultY;

    // Clamp inside screen boundaries
    final clampedX = currentX.clamp(6.0, screenSize.width - widgetWidth - 6.0);
    final clampedY = currentY.clamp(35.0, screenSize.height - widgetHeight - 35.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: widgetWidth,
            height: widgetHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ─── 1. CIRCULAR BASE WITH ROTATING NEON GRADIENT BORDER ───
                Positioned(
                  top: 22,
                  left: 14,
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F2FE).withValues(alpha: 0.45),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: 2.0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, _) {
                        return Container(
                          width: 86,
                          height: 86,
                          padding: const EdgeInsets.all(3.0), // Rotating border thickness
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              transform: GradientRotation(_rotateController.value * 2 * math.pi),
                              colors: const [
                                Color(0xFF00F2FE), // Bright Cyan
                                Color(0xFF4FACFE), // Electric Blue
                                Color(0xFF00FF87), // Neon Mint
                                Color(0xFFFF0844), // Pink/Crimson
                                Color(0xFF7928CA), // Purple
                                Color(0xFF00F2FE), // Loop back
                              ],
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF1E293B).withValues(alpha: 0.95),
                                  const Color(0xFF0A0F1D).withValues(alpha: 0.98),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ─── 2. RADIATING SPARKLES / SPRINKLES FROM BORDER ───
                Positioned(
                  top: 10,
                  left: 2,
                  width: 110,
                  height: 110,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _BorderSparklesPainter(
                            progress: _sparkleController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ─── 3. LOTTIE ROBOT (MEDIUM 1.58x SCALE & 3D POP-OUT) ───
                Positioned(
                  top: -2, // Popped above circle top edge!
                  left: 4,
                  child: InkWell(
                    onTap: _openCopilot,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: SizedBox(
                      width: 106,
                      height: 106,
                      child: Transform.scale(
                        scale: 1.58, // Medium, perfectly balanced zoom!
                        alignment: const Alignment(0, 0.1),
                        child: Lottie.asset(
                          'assets/animations/aibot.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.cyanAccent,
                              size: 50,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── 4. CIRCLE TAP TARGET ───
                Positioned(
                  top: 22,
                  left: 14,
                  width: 86,
                  height: 86,
                  child: InkWell(
                    onTap: _openCopilot,
                    customBorder: const CircleBorder(),
                  ),
                ),

                // ─── 5. "SHEETPRO AI" PILL BADGE ───
                Positioned(
                  bottom: 3,
                  left: 14,
                  width: 86,
                  child: Center(
                    child: GestureDetector(
                      onTap: _openCopilot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0891B2), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F2FE).withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 9.0),
                            SizedBox(width: 3.0),
                            Text(
                              'Sheetpro AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── 6. DISMISS (X) CLOSE BUTTON ───
                Positioned(
                  top: 14,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      widget.onDismiss?.call();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw twinkling, radiating 4-point sparkle stars around the border
class _BorderSparklesPainter extends CustomPainter {
  final double progress;

  _BorderSparklesPainter({required this.progress});

  // 8 sparkle positions around circle (radius ~43px from center at (55, 55))
  static const List<double> baseAngles = [
    0.35,   // top right
    1.10,   // bottom right
    1.90,   // bottom
    2.75,   // bottom left
    3.55,   // left
    4.30,   // top left
    5.15,   // top
    5.90,   // upper right
  ];

  static const List<Color> sparkleColors = [
    Color(0xFF00F2FE), // Cyan
    Color(0xFFFFDF00), // Golden yellow
    Color(0xFF00FF87), // Mint green
    Color(0xFFFFFFFF), // Pure white
    Color(0xFFFF4081), // Pink
    Color(0xFF00F2FE), // Cyan
    Color(0xFFFFE57F), // Warm gold
    Color(0xFF80D8FF), // Sky blue
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 45.0;

    for (int i = 0; i < baseAngles.length; i++) {
      // Stagger animation for each particle
      final phase = (progress + (i / baseAngles.length)) % 1.0;

      // Particle drifts outward from baseRadius to baseRadius + 12
      final currentRadius = baseRadius + (phase * 11.0);
      final angle = baseAngles[i] + (progress * 0.4);

      final sparkPos = Offset(
        center.dx + currentRadius * math.cos(angle),
        center.dy + currentRadius * math.sin(angle),
      );

      // Sparkle size and opacity swell and fade (sine curve)
      final intensity = math.sin(phase * math.pi);
      final sparkSize = 2.5 + (intensity * 3.5); // 2.5 to 6px
      final opacity = (intensity * 0.95).clamp(0.0, 1.0);

      _drawSparkle(canvas, sparkPos, sparkSize, sparkleColors[i % sparkleColors.length], opacity);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color, double opacity) {
    if (size <= 0.5 || opacity <= 0.05) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Glowing halo
    final glowPaint = Paint()
      ..color = color.withValues(alpha: (opacity * 0.45).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.9);

    final path = Path();
    // 4-pointed sparkle star shape
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Bright tiny core dot
    final corePaint = Paint()..color = Colors.white.withValues(alpha: opacity);
    canvas.drawCircle(center, size * 0.28, corePaint);
  }

  @override
  bool shouldRepaint(covariant _BorderSparklesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
