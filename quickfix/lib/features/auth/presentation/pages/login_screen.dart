import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/auth/presentation/controllers/auth_providers.dart';
import 'package:quickfix/core/utils/input_sanitizer.dart';
import 'package:quickfix/core/network/error_handler.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  int _timerCount = 60;
  Timer? _resendTimer;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() {
      _timerCount = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerCount > 0) {
        setState(() {
          _timerCount--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _sendOtp({bool isResend = false}) async {
    final phone = _phoneController.text.trim();
    if (!InputSanitizer.isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    AppHaptics.heavyTap();
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        forceResendingToken: isResend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          // Android instant auto-verification
          if (credential.smsCode != null && credential.smsCode!.isNotEmpty) {
            _otpController.text = credential.smsCode!;
          }
          await _verifyOtpWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          String errorMessage = e.message ?? 'Phone verification failed (${e.code}).';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'The entered phone number is invalid.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please wait a moment before trying again.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'SMS quota exceeded for today. Please try again later.';
          } else if (e.code == 'network-request-failed') {
            errorMessage = 'Network connection failed. Please check your internet connection.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
            _isOtpSent = true;
          });
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent to +91 $phone via SMS.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            _verificationId = verificationId;
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e, s) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final mapped = ErrorHandler.handle(e, s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapped.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (!InputSanitizer.isValidOtp(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification session expired. Please request a new OTP.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    AppHaptics.heavyTap();
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _verifyOtpWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String message = e.message ?? 'Verification failed (${e.code})';
        if (e.code == 'invalid-verification-code') {
          message = 'The OTP entered is incorrect. Please check and try again.';
        } else if (e.code == 'session-expired') {
          message = 'SMS code has expired. Please request a new OTP.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, s) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final mapped = ErrorHandler.handle(e, s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapped.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _verifyOtpWithCredential(PhoneAuthCredential credential) async {
    final phone = _phoneController.text.trim();
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        throw Exception("Firebase authentication token retrieval failed.");
      }

      await ref
          .read(authProvider.notifier)
          .login(phone, credential.smsCode ?? _otpController.text.trim(), firebaseToken: idToken);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppHaptics.successNotification();
        final shouldCompletePermissionFlow =
            !HiveService.isInitialPermissionFlowComplete();
        context.go(shouldCompletePermissionFlow ? '/location' : '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String message = e.message ?? 'Verification failed (${e.code})';
        if (e.code == 'invalid-verification-code') {
          message = 'The OTP entered is incorrect. Please check and try again.';
        } else if (e.code == 'session-expired') {
          message = 'SMS code has expired. Please request a new OTP.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, s) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final mapped = ErrorHandler.handle(e, s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapped.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          // Top 40% Hero
          Expanded(
            flex: 4,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.build,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QuickFix',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your trusted home service partner',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom 60% Form
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isOtpSent) ...[
                        Text(
                          'Welcome Back',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your phone number to continue',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 32),

                        // Phone Input Field
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '+91',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppColors.primary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter phone number',
                                    hintStyle: GoogleFonts.inter(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 250.ms),

                      ] else ...[
                        Text(
                          'Verify OTP',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Code sent to +91 ${_phoneController.text}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      _resendTimer?.cancel();
                                      setState(() {
                                        _isOtpSent = false;
                                        _otpController.clear();
                                      });
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 32),

                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12.0,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: GoogleFonts.inter(
                                color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight).withValues(alpha: 0.5),
                                letterSpacing: 12.0,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _timerCount > 0
                                  ? 'Resend code in ${_timerCount}s'
                                  : 'Didn\'t receive code?',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            if (_timerCount == 0)
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        AppHaptics.lightTap();
                                        _otpController.clear();
                                        _sendOtp(isResend: true);
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Resend',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ).animate().fadeIn(delay: 250.ms),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Verify & Proceed',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                      
                      const SizedBox(height: 48),

                      // Trust Badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTrustBadge(Icons.lock_outline, 'Secure', isDark),
                          _buildTrustBadge(Icons.shield_outlined, 'Verified', isDark),
                          _buildTrustBadge(Icons.flash_on, 'Instant', isDark),
                        ],
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String text, bool isDark) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.success,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
