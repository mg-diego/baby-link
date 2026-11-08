import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:app/features/babies/views/widgets/baby_avatar.dart';

/// Cabecera de la pestaña Inicio: tarjeta de cristal con la foto, el nombre y
/// la edad del bebé. Al pulsarla se abre su ficha.
class HomeHeader extends StatelessWidget {
  final String name;
  final String age;
  final String? photoUrl;
  final bool isNightMode;

  /// Colores del texto en modo día (varían con la hora para mantener el
  /// contraste sobre el cielo del atardecer).
  final Color dayTextPrimary;
  final Color dayTextSecondary;
  final double dayTextShadow;

  final VoidCallback onTap;

  const HomeHeader({
    super.key,
    required this.name,
    required this.age,
    required this.photoUrl,
    required this.isNightMode,
    required this.dayTextPrimary,
    required this.dayTextSecondary,
    required this.dayTextShadow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPri = isNightMode ? Colors.white : dayTextPrimary;
    final textSec =
        isNightMode ? Colors.white.withOpacity(0.65) : dayTextSecondary;
    final shadow = isNightMode ? 0.40 : dayTextShadow;

    final fallbackIcon = Icon(
      Icons.person_outline_rounded,
      size: 22,
      color: isNightMode
          ? Colors.white.withOpacity(0.80)
          : dayTextPrimary.withOpacity(0.75),
    );

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Ficha del bebé' : 'Ficha de $name',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
              decoration: BoxDecoration(
                color: isNightMode
                    ? Colors.black.withOpacity(0.25)
                    : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isNightMode
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.55),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNightMode
                            ? Colors.white.withOpacity(0.18)
                            : Colors.white.withOpacity(0.70),
                        width: 1.5,
                      ),
                    ),
                    child: BabyAvatar(
                      photoUrl: photoUrl,
                      size: 42,
                      backgroundColor: isNightMode
                          ? Colors.black.withOpacity(0.22)
                          : Colors.white.withOpacity(0.30),
                      fallback: fallbackIcon,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name.isNotEmpty)
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPri,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(shadow),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        if (age.isNotEmpty)
                          Text(
                            age,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSec,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(shadow * 0.7),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: textSec,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
