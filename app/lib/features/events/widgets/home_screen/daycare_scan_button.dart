import 'package:flutter/material.dart';

import 'package:app/features/daycare_scan/daycare_scan_flow.dart';

import 'home_header.dart';

/// Botón de la cabecera de Inicio: escanear la hoja diaria de la guardería
/// para registrar sus siestas.
class DaycareScanButton extends StatelessWidget {
  final String babyId;
  final bool isNightMode;
  final Color dayTextPrimary;
  final Color dayTextSecondary;

  const DaycareScanButton({
    super.key,
    required this.babyId,
    required this.isNightMode,
    required this.dayTextPrimary,
    required this.dayTextSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final night = isNightMode;
    final textPri = night ? Colors.white : dayTextPrimary;
    final textSec = night ? Colors.white.withValues(alpha: 0.65) : dayTextSecondary;

    return Semantics(
      button: true,
      label: 'Escanear la hoja de la guardería',
      child: GestureDetector(
        onTap: () => launchDaycareScan(context, babyId),
        behavior: HitTestBehavior.opaque,
        child: HeaderGlass(
          isNightMode: night,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 22,
                  color: night ? Colors.white.withValues(alpha: 0.90) : dayTextPrimary,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoja',
                      style: TextStyle(
                        color: textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      'Guarde',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
