import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/auth/presentation/controllers/auth_providers.dart';
import 'package:quickfix/features/auth/presentation/widgets/launch_3d_painter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Main sequence animation controller (0.0 -> 1.0)
  late AnimationController _sequenceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _sheenAnimation;
  late Animation<double> _exitScaleAnimation;
  late Animation<double> _exitFadeAnimation;

  // Continuous loop controller for 3D orbital rings and floating physics
  late AnimationController _ambientController;

  // 3D Particles list
  late List<Particle3D> _particles;

  // Interactive 3D touch tilt offsets (in radians)
  double _touchTiltX = 0.0;
  double _touchTiltY = 0.0;

  bool _minAnimationFinished = false;
  bool _navigated = false;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();

    // 1. Initialize random 3D particles constellation
    final random = math.Random();
    _particles = List.generate(
      32,
      (_) => Particle3D.random(random, [
        AppColors.primaryAccent,
        const Color(0xFF8B5CF6),
        const Color(0xFF38BDF8),
        const Color(0xFFFFB800),
        Colors.white,
      ]),
    );

    // 2. Continuous ambient controller for 3D physics & floating oscillation
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _ambientController.addListener(() {
      for (final p in _particles) {
        p.update(0.016);
      }
    });

    // 3. Main entrance & greeting sequence controller (~2200ms total cinematic duration)
    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Stage 1: 3D Emblem entry (0.0 to 0.45)
    _scaleAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Stage 2: 3D Greeting Card Flip & Slide (0.35 to 0.75)
    _cardSlideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Stage 3: Specular light sheen passing over the emblem (0.4 to 0.85)
    _sheenAnimation = Tween<double>(begin: -1.2, end: 1.8).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeInOut),
      ),
    );

    // Stage 4: Exit push transition (0.9 to 1.0)
    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.9, 1.0, curve: Curves.easeInQuad),
      ),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.92, 1.0, curve: Curves.easeOut),
      ),
    );

    _sequenceController.addListener(() {
      // Trigger haptic tick when emblem pops in
      if (_sequenceController.value >= 0.25 && !_hapticFired) {
        _hapticFired = true;
        AppHaptics.mediumTap();
      }
    });

    _sequenceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _minAnimationFinished = true);
          _tryNavigate();
        }
      }
    });

    _sequenceController.forward();

    // 4. Start auth check & pre-warm background caches simultaneously
    Future.microtask(() {
      ref.read(authProvider.notifier).checkSession();
      ref.read(categoriesProvider);
      ref.read(bannersProvider);
      ref.read(homepageLayoutProvider);
    });
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _onSkipTap() {
    AppHaptics.lightTap();
    if (!_minAnimationFinished) {
      setState(() => _minAnimationFinished = true);
    }
    _tryNavigate(forceImmediate: true);
  }

  void _tryNavigate({bool forceImmediate = false}) {
    if (!mounted || _navigated) return;
    final authState = ref.read(authProvider);

    // Navigate when animation finished AND auth is not loading, or when forced by skip tap
    if ((_minAnimationFinished || forceImmediate) && !authState.isLoading) {
      _navigated = true;
      final isOnboarded = HiveService.isOnboardingComplete();
      if (!isOnboarded) {
        context.go('/onboarding');
        return;
      }
      final hasCompletedPermissionFlow =
          HiveService.isInitialPermissionFlowComplete();
      if (!hasCompletedPermissionFlow) {
        context.go('/location');
        return;
      }
      if (authState.isAuthenticated) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(isDarkModeProvider);

    // Reactive navigation listener when authState finishes loading
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isLoading && _minAnimationFinished) {
        _tryNavigate();
      }
    });

    // Resolve user details from reactive state or instant Hive storage cache
    final cachedProfile = HiveService.getCachedProfile();
    final authState = ref.watch(authProvider);
    final user = authState.user ?? cachedProfile;

    final rawName = user?['name']?.toString().trim() ?? '';
    final hasName = rawName.isNotEmpty;
    final firstName = hasName ? rawName.split(' ').first : '';
    final timeGreeting = _getTimeGreeting();

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Deep obsidian background
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onSkipTap,
        onPanUpdate: (details) {
          // Interactive 3D touch tilt calculation based on drag delta
          setState(() {
            _touchTiltY = (_touchTiltY + details.delta.dx * 0.003).clamp(-0.35, 0.35);
            _touchTiltX = (_touchTiltX - details.delta.dy * 0.003).clamp(-0.35, 0.35);
          });
        },
        onPanEnd: (_) {
          // Smooth return to zero
          setState(() {
            _touchTiltX = 0.0;
            _touchTiltY = 0.0;
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_sequenceController, _ambientController]),
          builder: (context, child) {
            // Natural 3D floating wobble
            final floatSin = math.sin(_ambientController.value * math.pi * 2);
            final floatCos = math.cos(_ambientController.value * math.pi * 2);

            // Total 3D tilt angles (combining ambient physics + user touch)
            final currentTiltX = (floatSin * 0.08) + _touchTiltX;
            final currentTiltY = (floatCos * 0.08) + _touchTiltY;

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Deep Space Multi-Layer Ambient Background
                _buildBackgroundGradients(size, floatSin),

                // 2. 3D Floating Particle Constellation with depth projection
                CustomPaint(
                  size: size,
                  painter: ParticleField3DPainter(
                    particles: _particles,
                    animationValue: _ambientController.value,
                  ),
                ),

                // 3. Central 3D Perspective Viewport
                Center(
                  child: Transform.scale(
                    scale: _exitScaleAnimation.value,
                    child: Opacity(
                      opacity: _exitFadeAnimation.value.clamp(0.0, 1.0),
                      child: Transform(
                        alignment: FractionalOffset.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014) // True 3D perspective projection
                          ..rotateX(currentTiltX)
                          ..rotateY(currentTiltY),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 3D Holographic Emblem with Dual Orbiters
                            _buildHologramEmblem(size),

                            const SizedBox(height: 32),

                            // Personalized 3D Glassmorphic Greeting Card
                            _buildPersonalizedCard(
                              hasName: hasName,
                              firstName: firstName,
                              timeGreeting: timeGreeting,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Futuristic Laser Loading Line & Skip Indicator
                Positioned(
                  left: 32,
                  right: 32,
                  bottom: 38,
                  child: _buildFooterSection(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Ambient multi-layer background nebula gradients
  Widget _buildBackgroundGradients(Size size, double floatSin) {
    return Stack(
      children: [
        // Primary gradient layer
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF090D16),
                Color(0xFF0F172A),
                Color(0xFF13132B),
              ],
            ),
          ),
        ),

        // Glowing violet nebula aura at top-left
        Positioned(
          top: -size.height * 0.15 + (floatSin * 20),
          left: -size.width * 0.2,
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryAccent.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Cyan-indigo nebula aura at bottom-right
        Positioned(
          bottom: -size.height * 0.1 - (floatSin * 20),
          right: -size.width * 0.25,
          child: Container(
            width: size.width * 0.85,
            height: size.width * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 3D Holographic QuickFix Emblem with rotating dual orbital rings & light sheen
  Widget _buildHologramEmblem(Size size) {
    return Transform.scale(
      scale: _scaleAnimation.value,
      child: Opacity(
        opacity: _fadeAnimation.value.clamp(0.0, 1.0),
        child: SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dual 3D Orbiting Rings
              CustomPaint(
                size: const Size(170, 170),
                painter: OrbitalRings3DPainter(
                  rotationAngle: _ambientController.value * math.pi * 2,
                  primaryColor: AppColors.primaryAccent,
                  accentColor: const Color(0xFF38BDF8),
                ),
              ),

              // Outer Pulsing Neon Glow Ring
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.45),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                      blurRadius: 48,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // Frosted Glass Hexagonal Shield with 3D Border
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      // Inner 3D Gradient Icon Orb
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFF6E42E5),
                              Color(0xFF4F46E5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryAccent.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Crossed repair tools with electric spark
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.build_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 26,
                                ),
                              ],
                            ),

                            // Specular Sheen sweep across emblem
                            Positioned.fill(
                              child: ClipOval(
                                child: Transform.translate(
                                  offset: Offset(_sheenAnimation.value * 72, 0),
                                  child: Transform.rotate(
                                    angle: math.pi / 4,
                                    child: Container(
                                      width: 28,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withValues(alpha: 0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D Glassmorphic Personalized Greeting Card ("Hello, Vivek" / "Welcome to QuickFix")
  Widget _buildPersonalizedCard({
    required bool hasName,
    required String firstName,
    required String timeGreeting,
  }) {
    final cardProgress = CurvedAnimation(
      parent: _sequenceController,
      curve: const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
    ).value;

    return Transform.translate(
      offset: Offset(0, _cardSlideAnimation.value),
      child: Opacity(
        opacity: cardProgress.clamp(0.0, 1.0),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic Chip Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryAccent.withValues(alpha: 0.35),
                      const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasName ? Icons.waving_hand_rounded : Icons.auto_awesome,
                      color: const Color(0xFFFFB800),
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasName ? timeGreeting.toUpperCase() : 'QUICKFIX AI',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Personalized Headline: "Hello, Vivek 👋" or "Welcome to QuickFix"
              Text(
                hasName ? 'Hello, $firstName 👋' : 'Welcome to QuickFix',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle Tagline
              Text(
                hasName
                    ? 'Fix Fast, Live Easy • Services Ready'
                    : 'Instant Hyperlocal Home Services',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Footer futuristic laser progress & Skip indicator
  Widget _buildFooterSection() {
    final progress = _sequenceController.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing laser progress bar
        Container(
          height: 3.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF38BDF8),
                          AppColors.primaryAccent,
                          Color(0xFFFFB800),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withValues(alpha: 0.7),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Skip / Continue Hint
        Text(
          'Tap anywhere to continue',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white38,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
