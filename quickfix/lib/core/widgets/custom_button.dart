import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';

enum CustomButtonType { primary, secondary, actionRed, outlined, text, accent }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final double? width;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = CustomButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 52,
    this.width,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color buttonColor;
    Color contentColor;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case CustomButtonType.primary:
        buttonColor = backgroundColor ?? AppColors.primary;
        contentColor = textColor ?? Colors.white;
        break;
      case CustomButtonType.secondary:
      case CustomButtonType.outlined:
        buttonColor = Colors.transparent;
        contentColor = textColor ?? AppColors.primary;
        borderSide = BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.primary,
          width: 1.5,
        );
        break;
      case CustomButtonType.accent:
        buttonColor = backgroundColor ?? AppColors.primaryAccent;
        contentColor = textColor ?? Colors.white;
        break;
      case CustomButtonType.actionRed:
        buttonColor = backgroundColor ?? Colors.red;
        contentColor = textColor ?? Colors.white;
        break;
      case CustomButtonType.text:
        buttonColor = Colors.transparent;
        contentColor = textColor ?? AppColors.primaryAccent;
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: buttonColor,
      foregroundColor: contentColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: borderSide,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
    );

    Widget child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: contentColor),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: contentColor,
                ),
              ),
            ],
          );

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : width,
      child: type == CustomButtonType.text || type == CustomButtonType.outlined || type == CustomButtonType.secondary
          ? TextButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: child,
            ),
    );
  }
}
