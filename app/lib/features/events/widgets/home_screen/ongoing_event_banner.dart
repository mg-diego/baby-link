import 'package:app/core/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:app/shared/models/event_type.dart';

class OngoingEventBanner extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isNightMode;
  final VoidCallback onTap;
  final VoidCallback onStop;

  const OngoingEventBanner({
    super.key,
    required this.event,
    required this.isNightMode,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cat = event['category'];
    final meta = (event['metadata'] as Map<String, dynamic>?) ?? {};
    final type = EventType.fromBackend(cat, meta);
    final startTime = DateTime.parse(event['start_time']).toLocal();
    final isNap = cat == 'nap';
    
    final predictedStartStr = meta['predicted_start_time'] as String?;
    final predictedEndStr = meta['predicted_end_time'] as String?;
    final hasPrediction = predictedStartStr != null && predictedEndStr != null;

    final textColor = isNightMode ? Colors.white : const Color(0xFF2D3142);
    final subTextColor = isNightMode ? Colors.white70 : const Color(0xFF546E7A);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.005,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.015,
            ),
            decoration: BoxDecoration(
              color: isNightMode
                  ? type.getAccentColor(context).withOpacity(0.6)
                  : type.getAccentColor(context).withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: type.getAccentColor(context).withOpacity(isNightMode ? 0.4 : 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(size.width * 0.02),
                      decoration: BoxDecoration(
                        color: type.getAccentColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(type.icon, color: Colors.white, size: 20),
                    ),
                    SizedBox(width: size.width * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${type.uiLabel} en curso',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          StreamBuilder(
                            stream: Stream.periodic(const Duration(minutes: 1)),
                            builder: (context, _) {
                              final diff = DateTime.now().difference(startTime);
                              final h = diff.inHours;
                              final m = diff.inMinutes % 60;
                              final timeStr = h > 0 ? '${h}h ${m}m' : '$m min';
                              return Text(
                                'Iniciado hace $timeStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onStop,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.035,
                          vertical: size.height * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: type.getAccentColor(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: type.getAccentColor(context).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Detener',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isNap && hasPrediction) ...[
                  SizedBox(height: size.height * 0.01),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(minutes: 1)),
                    builder: (context, _) {
                      final now = DateTime.now();
                      final elapsed = now.difference(startTime).inMinutes;

                      final pStart = DateTime.parse(predictedStartStr!).toLocal();
                      final pEnd = DateTime.parse(predictedEndStr!).toLocal();

                      final totalRaw = pEnd.difference(pStart).inMinutes.toDouble();
                      final total = totalRaw > 0 ? totalRaw : 1.0;
                      
                      final progress = (elapsed / total).clamp(0.0, 1.0);
                      
                      final remainingMins = pEnd.difference(now).inMinutes;
                      final isOverdue = remainingMins < 0;
                      final overdueMins = isOverdue ? -remainingMins : 0;
                      
                      final accentColor = type.getAccentColor(context);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(
                                      isNightMode ? 0.20 : 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: LinearGradient(
                                        colors: isOverdue
                                            ? [
                                                accentColor.withOpacity(0.6),
                                                accentColor,
                                              ]
                                            : [
                                                accentColor.withOpacity(0.7),
                                                accentColor,
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isOverdue
                                ? 'Siesta más larga de lo previsto (+${TimeUtils.formatMinutes(overdueMins)})'
                                : 'Tiempo restante estimado: ${TimeUtils.formatMinutes(remainingMins)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOverdue ? accentColor : subTextColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}