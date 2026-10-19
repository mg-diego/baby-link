import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar circular del bebé: muestra su foto si existe y, si no (o si falla
/// la carga), el [fallback] indicado.
class BabyAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  final Widget fallback;
  final Color? backgroundColor;

  const BabyAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
    required this.fallback,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
