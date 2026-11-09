import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:app/features/babies/views/widgets/baby_avatar.dart';

/// Superficie de "cristal" de la cabecera de Inicio, compartida por la tarjeta
/// del bebé y los botones que la acompañan para que se vean iguales.
class HeaderGlass extends StatelessWidget {
  final bool isNightMode;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const HeaderGlass({
    super.key,
    required this.isNightMode,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isNightMode
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isNightMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

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
        isNightMode ? Colors.white.withValues(alpha: 0.65) : dayTextSecondary;
    final shadow = isNightMode ? 0.40 : dayTextShadow;

    final fallbackIcon = Icon(
      Icons.person_outline_rounded,
      size: 22,
      color: isNightMode
          ? Colors.white.withValues(alpha: 0.80)
          : dayTextPrimary.withValues(alpha: 0.75),
    );

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Ficha del bebé' : 'Ficha de $name',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: HeaderGlass(
          isNightMode: isNightMode,
          padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isNightMode
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.70),
                    width: 1.5,
                  ),
                ),
                child: BabyAvatar(
                  photoUrl: photoUrl,
                  size: 42,
                  backgroundColor: isNightMode
                      ? Colors.black.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.30),
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
                              color: Colors.black.withValues(alpha: shadow),
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
                              color: Colors.black.withValues(alpha: shadow * 0.7),
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
    );
  }
}
