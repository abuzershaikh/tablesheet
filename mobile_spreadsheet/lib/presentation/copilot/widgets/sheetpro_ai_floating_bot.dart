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
    // Continuous rotating border animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Subtle pulsing neon glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
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

    // Total widget dimensions: 104 wide x 118 tall
    const widgetWidth = 104.0;
    const widgetHeight = 118.0;

    // Default position: bottom-right
    final defaultX = screenSize.width - widgetWidth - 16.0;
    final defaultY = screenSize.height - widgetHeight - 75.0;

    final currentX = _position?.dx ?? defaultX;
    final currentY = _position?.dy ?? defaultY;

    // Clamp inside screen boundaries
    final clampedX = currentX.clamp(8.0, screenSize.width - widgetWidth - 8.0);
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
                // ─── 1. CIRCULAR BASE WITH ROTATING GRADIENT BORDER ───
                Positioned(
                  top: 24,
                  left: 10,
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 84,
                        height: 84,
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
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(3.0), // Rotating border thickness
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              transform: GradientRotation(_rotateController.value * 2 * math.pi),
                              colors: const [
                                Color(0xFF00F2FE), // Cyan
                                Color(0xFF4FACFE), // Blue
                                Color(0xFF00FF87), // Emerald
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
                                  const Color(0xFF1E293B).withValues(alpha: 0.96),
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

                // ─── 2. LOTTIE ROBOT (3D POP-OUT: HALF INSIDE, HALF OUTSIDE) ───
                Positioned(
                  top: 0, // Popped 24px above circle top!
                  left: 5,
                  child: IgnorePointer(
                    ignoring: false,
                    child: InkWell(
                      onTap: _openCopilot,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: SizedBox(
                        width: 94,
                        height: 94,
                        child: Lottie.asset(
                          'assets/animations/aibot.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.cyanAccent,
                              size: 55,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── 3. OVERLAPPING INKWELL HIT TARGET ───
                Positioned(
                  top: 24,
                  left: 10,
                  width: 84,
                  height: 84,
                  child: InkWell(
                    onTap: _openCopilot,
                    customBorder: const CircleBorder(),
                  ),
                ),

                // ─── 4. "SHEETPRO AI" PILL BADGE (AT BOTTOM OF CIRCLE) ───
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: GestureDetector(
                    onTap: _openCopilot,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0891B2), Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 9.5),
                          SizedBox(width: 3.5),
                          Text(
                            'Sheetpro AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── 5. DISMISS (X) CLOSE BUTTON ───
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
