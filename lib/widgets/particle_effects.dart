import 'package:flutter/material.dart';
import 'dart:math' as math;

class ParticleEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final ParticleType type;
  final Color? color;

  const ParticleEffect({
    super.key,
    required this.child,
    this.isActive = false,
    this.type = ParticleType.sparkle,
    this.color,
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _generateParticles();

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _generateParticles();
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reset();
    }
  }

  void _generateParticles() {
    final random = math.Random();
    _particles = List.generate(widget.type.particleCount, (index) {
      return Particle(
        emoji: widget.type.emojis[random.nextInt(widget.type.emojis.length)],
        startAngle: random.nextDouble() * 2 * math.pi,
        speed: 50 + random.nextDouble() * 100,
        size: 16 + random.nextDouble() * 16,
        lifespan: 0.5 + random.nextDouble() * 1.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.isActive)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particles, _controller.value),
                size: const Size(200, 200),
              );
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class Particle {
  final String emoji;
  final double startAngle;
  final double speed;
  final double size;
  final double lifespan;

  Particle({
    required this.emoji,
    required this.startAngle,
    required this.speed,
    required this.size,
    required this.lifespan,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final progress = animationValue / particle.lifespan;
      if (progress > 1.0) continue;

      final distance = particle.speed * progress;
      final x = center.dx + math.cos(particle.startAngle) * distance;
      final y = center.dy + math.sin(particle.startAngle) * distance;

      final opacity = 1.0 - progress;
      final currentSize = particle.size * (1.0 - progress * 0.5);

      final textPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: currentSize,
            color: Colors.white.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

enum ParticleType {
  sparkle(['✨', '⭐', '🌟'], 12),
  victory(['🎉', '🏆', '👑', '💎'], 15),
  explosion(['💥', '⚡', '🔥'], 8),
  magic(['✨', '🪄', '🌙', '⭐'], 10),
  hearts(['❤️', '💖', '💕', '💝'], 8),
  celebration(['🎊', '🎉', '🎈', '🎁'], 12);

  const ParticleType(this.emojis, this.particleCount);

  final List<String> emojis;
  final int particleCount;
}

// Floating score animation widget
class FloatingScoreAnimation extends StatefulWidget {
  final int score;
  final Color color;
  final bool isVisible;

  const FloatingScoreAnimation({
    super.key,
    required this.score,
    this.color = Colors.green,
    this.isVisible = false,
  });

  @override
  State<FloatingScoreAnimation> createState() => _FloatingScoreAnimationState();
}

class _FloatingScoreAnimationState extends State<FloatingScoreAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(FloatingScoreAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.forward().then((_) => _controller.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '+${widget.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Pulse animation widget for UI elements
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.isActive = true,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _scaleAnimation.value : 1.0,
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}