import 'package:flutter/material.dart';

import '../../services/upload_progress.dart';

/// Botón de guardar que, mientras se guarda, se convierte en una barra de
/// progreso con la fase actual ("Comprimiendo vídeo · 42 %").
class SaveProgressButton extends StatelessWidget {
  static const _color = Color(0xFF4A90D9);

  final String label;
  final bool busy;
  final UploadProgress? progress;
  final VoidCallback onPressed;

  const SaveProgressButton({
    super.key,
    required this.label,
    required this.busy,
    required this.progress,
    required this.onPressed,
  });

  Widget _bar(double? value) => LinearProgressIndicator(
    value: value,
    minHeight: 50,
    color: _color,
    backgroundColor: _color.withValues(alpha: 0.45),
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    if (!busy) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: radius),
            elevation: 0,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    final p = progress;
    final text = p == null ? 'Guardando…' : [p.label, ?p.percent].join(' · ');

    return Semantics(
      liveRegion: true,
      label: text,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // La barra rellena el botón. Con avance medible se anima para
              // que los saltos (llegan cada ~1 %) no se vean a tirones.
              if (p?.fraction case final fraction?)
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fraction),
                  duration: const Duration(milliseconds: 250),
                  builder: (_, value, _) => _bar(value),
                )
              else
                _bar(null),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p?.fraction == null) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
