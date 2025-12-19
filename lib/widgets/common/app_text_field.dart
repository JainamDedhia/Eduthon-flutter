import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Consistent text field widget
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function()? onTap;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        enabled: enabled,
        onChanged: onChanged,
        onTap: onTap,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Roboto',
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          floatingLabelAlignment: FloatingLabelAlignment.start,
          labelStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          floatingLabelStyle: TextStyle(
            color: AppTheme.primaryBlue,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: AppTheme.secondaryTextGrey,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppTheme.primaryBlue, size: 22)
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppTheme.white,
          isDense: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2.5),
          ),
          contentPadding: EdgeInsets.only(
            left: prefixIcon != null ? AppTheme.spacingM : AppTheme.spacingL,
            right: suffixIcon != null ? AppTheme.spacingM : AppTheme.spacingL,
            top: AppTheme.spacingL + 4,
            bottom: AppTheme.spacingL + 4,
          ),
        ),
      ),
    );
  }
}

