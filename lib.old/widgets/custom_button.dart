import 'package:flutter/material.dart';

enum ButtonVariant {
  filled,
  outlined,
  text,
}

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData? icon;
  final Color? color;
  final bool isLoading;
  final bool isOutlined;
  final ButtonVariant variant;
  final double? width;
  final double? height;

  const CustomButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.color,
    this.isLoading = false,
    this.isOutlined = false,
    this.variant = ButtonVariant.filled,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;
    final effectiveVariant = isOutlined ? ButtonVariant.outlined : variant;

    return SizedBox(
      width: width,
      height: height ?? 40,
      child: _buildButton(effectiveVariant, buttonColor),
    );
  }

  Widget _buildButton(ButtonVariant variant, Color buttonColor) {
    switch (variant) {
      case ButtonVariant.outlined:
        return OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                  ),
                )
              : Icon(icon, size: 20),
          label: Text(text),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      case ButtonVariant.text:
        return TextButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                  ),
                )
              : Icon(icon, size: 20),
          label: Text(text),
          style: TextButton.styleFrom(
            foregroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      case ButtonVariant.filled:
      default:
        return ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon ?? Icons.add, size: 20),
          label: Text(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    }
  }
}
