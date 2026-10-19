import 'package:flutter/material.dart';

import 'package:app/features/babies/views/widgets/baby_avatar.dart';

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isNightMode;
  final Color dayIconColor; 
  final VoidCallback onTap;

  /// Si se indica, se muestra la imagen (recortada en círculo) en vez del icono.
  final String? imageUrl;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.isNightMode,
    required this.dayIconColor,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: 20,
      color: isNightMode
          ? Colors.white.withOpacity(0.80)
          : dayIconColor,
    );

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
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? BabyAvatar(photoUrl: imageUrl, size: 44, fallback: iconWidget)
            : iconWidget,
      ),
    );
  }
}