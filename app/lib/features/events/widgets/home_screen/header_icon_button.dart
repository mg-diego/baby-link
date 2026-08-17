import 'package:flutter/material.dart';

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isNightMode;
  final Color dayIconColor; 
  final VoidCallback onTap;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.isNightMode,
    required this.dayIconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        decoration: BoxDecoration(
          color: isNightMode
              ? Colors.black.withOpacity(0.22)
              : Colors.white.withOpacity(0.30),
          shape: BoxShape.circle,
          border: Border.all(
            color: isNightMode
                ? Colors.white.withOpacity(0.10)
                : Colors.white.withOpacity(0.50),
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isNightMode
              ? Colors.white.withOpacity(0.80)
              : dayIconColor,
        ),
      ),
    );
  }
}