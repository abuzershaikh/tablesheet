import 'dart:math' as math;
import 'package:flutter/material.dart';
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
  late AnimationController _popController;
  late Animation<double> _popAnimation;
  late AnimationController _sparkleController;
  late AnimationController _aiGlowController;
  late Animation<double> _aiGlowAnimation;

  @override
  void initState() {
    super.initState();
    // Continuous 360-degree rotating gradient border
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Rhythmic pop-up pulse animation (pops up smoothly every 2.2s)
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _popAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
    ]).animate(_popController);

    // Radiating border sparkles / sprinkles
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Animated breathing glow on the "AI" badge
    _aiGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _aiGlowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _aiGlowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _popController.dispose();
    _sparkleController.dispose();
    _aiGlowController.dispose();
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

    // Card dimensions
    const cardWidth = 144.0;
    const cardHeight = 52.0;

    // Container with room for sparkles and close button
    const containerWidth = 160.0;
    const containerHeight = 68.0;

    // Default position: bottom-right
    final defaultX = screenSize.width - containerWidth - 14.0;
    final defaultY = screenSize.height - containerHeight - 80.0;

    final currentX = _position?.dx ?? defaultX;
    final currentY = _position?.dy ?? defaultY;

    // Clamp inside screen boundaries
    final clampedX = currentX.clamp(6.0, screenSize.width - containerWidth - 6.0);
    final clampedY = currentY.clamp(40.0, screenSize.height - containerHeight - 40.0);

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
            width: containerWidth,
            height: containerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ─── 1. RADIATING SPARKLES AROUND CARD BORDER ───
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _CardSparklesPainter(
                            progress: _sparkleController.value,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ─── 2. RHYTHMIC POP-UP ANIMATED CARD ───
                AnimatedBuilder(
                  animation: _popAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _popAnimation.value,
                      child: child,
                    );
                  },
                  child: InkWell(
                    onTap: _openCopilot,
                    borderRadius: BorderRadius.circular(26),
                    child: AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, _) {
                        return Container(
                          width: cardWidth,
                          height: cardHeight,
                          padding: const EdgeInsets.all(2.5), // Rotating neon border thickness
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: SweepGradient(
                              transform: GradientRotation(_rotateController.value * 2 * math.pi),
                              colors: const [
                                Color(0xFF00F2FE), // Cyan
                                Color(0xFF4FACFE), // Electric Blue
                                Color(0xFF00FF87), // Neon Mint Green
                                Color(0xFFFF0844), // Pink/Crimson
                                Color(0xFF7928CA), // Purple
                                Color(0xFF00F2FE), // Loop back
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F2FE).withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1.5,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B132B),
                              borderRadius: BorderRadius.circular(23.5),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Sparkle Star Icon
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFF00F2FE),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),

                                // "Sheetpro" Text
                                const Text(
                                  'Sheetpro',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Animated "AI" Glowing Badge
                                AnimatedBuilder(
                                  animation: _aiGlowAnimation,
                                  builder: (context, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF06B6D4),
                                            Color.lerp(
                                              const Color(0xFF3B82F6),
                                              const Color(0xFF8B5CF6),
                                              _aiGlowAnimation.value,
                                            )!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF06B6D4).withValues(alpha: _aiGlowAnimation.value * 0.7),
                                            blurRadius: 8 * _aiGlowAnimation.value,
                                            spreadRadius: 1.0,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'AI',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ─── 3. DISMISS (X) CLOSE BUTTON ───
                Positioned(
                  top: 2,
                  right: 2,
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
                        border: Border.all(color: Colors.white60, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
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

/// Custom painter to draw animated twinkling sparkles around the card perimeter
class _CardSparklesPainter extends CustomPainter {
  final double progress;
  final double cardWidth;
  final double cardHeight;

  _CardSparklesPainter({
    required this.progress,
    required this.cardWidth,
    required this.cardHeight,
  });

  // Relative positions along the perimeter (0.0 to 1.0)
  static const List<double> perimeterStops = [
    0.05, 0.20, 0.35, 0.50, 0.65, 0.80, 0.92,
  ];

  static const List<Color> sparkleColors = [
    Color(0xFF00F2FE), // Cyan
    Color(0xFFFFDF00), // Gold
    Color(0xFF00FF87), // Mint green
    Color(0xFFFFFFFF), // Pure white
    Color(0xFFFF4081), // Neon Pink
    Color(0xFF80D8FF), // Sky blue
    Color(0xFFFFE57F), // Warm gold
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final halfW = cardWidth / 2;
    final halfH = cardHeight / 2;

    for (int i = 0; i < perimeterStops.length; i++) {
      final phase = (progress + (i / perimeterStops.length)) % 1.0;
      final t = (perimeterStops[i] + (progress * 0.2)) % 1.0;

      // Calculate perimeter coordinate on rounded card
      Offset basePos;
      Offset normalDir;

      if (t < 0.35) {
        // Top edge
        final frac = t / 0.35;
        basePos = Offset(centerX - halfW + (cardWidth * frac), centerY - halfH);
        normalDir = const Offset(0, -1);
      } else if (t < 0.5) {
        // Right edge
        final frac = (t - 0.35) / 0.15;
        basePos = Offset(centerX + halfW, centerY - halfH + (cardHeight * frac));
        normalDir = const Offset(1, 0);
      } else if (t < 0.85) {
        // Bottom edge
        final frac = (t - 0.5) / 0.35;
        basePos = Offset(centerX + halfW - (cardWidth * frac), centerY + halfH);
        normalDir = const Offset(0, 1);
      } else {
        // Left edge
        final frac = (t - 0.85) / 0.15;
        basePos = Offset(centerX - halfW, centerY + halfH - (cardHeight * frac));
        normalDir = const Offset(-1, 0);
      }

      // Drift outward from border
      final drift = phase * 9.0;
      final sparkPos = basePos + (normalDir * drift);

      // Swell and fade
      final intensity = math.sin(phase * math.pi);
      final sparkSize = 2.0 + (intensity * 3.5);
      final opacity = (intensity * 0.95).clamp(0.0, 1.0);

      _drawSparkle(canvas, sparkPos, sparkSize, sparkleColors[i % sparkleColors.length], opacity);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color, double opacity) {
    if (size <= 0.5 || opacity <= 0.05) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: (opacity * 0.45).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.9);

    final path = Path();
    // 4-pointed sparkle star shape (✦)
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Bright core dot
    final corePaint = Paint()..color = Colors.white.withValues(alpha: opacity);
    canvas.drawCircle(center, size * 0.28, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CardSparklesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
