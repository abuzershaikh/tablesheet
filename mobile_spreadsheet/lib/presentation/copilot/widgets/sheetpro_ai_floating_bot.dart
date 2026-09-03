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

    _glowAnimation = Tween<double>(begin: 4.0, end: 14.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _glowController.dispose();
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

    // Total widget dimensions
    const widgetWidth = 124.0;
    const widgetHeight = 138.0;

    // Default position: bottom-right above formula / bottom bar
    final defaultX = screenSize.width - widgetWidth - 12.0;
    final defaultY = screenSize.height - widgetHeight - 80.0;

    final currentX = _position?.dx ?? defaultX;
    final currentY = _position?.dy ?? defaultY;

    // Clamp inside screen boundaries
    final clampedX = currentX.clamp(4.0, screenSize.width - widgetWidth - 4.0);
    final clampedY = currentY.clamp(40.0, screenSize.height - widgetHeight - 40.0);

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
                  top: 26,
                  left: 14,
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: 2.5,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
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
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(3.5), // Rotating neon border thickness
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              transform: GradientRotation(_rotateController.value * 2 * math.pi),
                              colors: const [
                                Color(0xFF00F2FE), // Bright Cyan
                                Color(0xFF4FACFE), // Electric Blue
                                Color(0xFF00FF87), // Neon Mint Green
                                Color(0xFFFF0844), // Vivid Pink
                                Color(0xFF7928CA), // Deep Violet
                                Color(0xFF00F2FE), // Seamless Loop
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

                // ─── 2. LOTTIE ROBOT (ZOOMED & 3D POP-OUT: AADHA ANDAR, AADHA BAHAR) ───
                Positioned(
                  top: -6, // Popped high above circle top!
                  left: 2,
                  child: InkWell(
                    onTap: _openCopilot,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Transform.scale(
                        scale: 1.95, // Zooms in so the actual robot character is large and prominent!
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
                              size: 65,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── 3. CIRCLE TAP TARGET ───
                Positioned(
                  top: 26,
                  left: 14,
                  width: 96,
                  height: 96,
                  child: InkWell(
                    onTap: _openCopilot,
                    customBorder: const CircleBorder(),
                  ),
                ),

                // ─── 4. "SHEETPRO AI" SHINY PILL BADGE ───
                Positioned(
                  bottom: 4,
                  left: 14,
                  width: 96,
                  child: Center(
                    child: GestureDetector(
                      onTap: _openCopilot,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0891B2), Color(0xFF0284C7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 10.5),
                            SizedBox(width: 4),
                            Text(
                              'Sheetpro AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── 5. DISMISS (X) CLOSE BUTTON ───
                Positioned(
                  top: 16,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      widget.onDismiss?.call();
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white60, width: 1.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 14,
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
