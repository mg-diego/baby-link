import 'package:flutter/material.dart';
import 'package:app/shared/models/event_type.dart';

class BiologicalActionButton extends StatelessWidget {
  final EventType eventType;
  final bool isNight;
  final bool isDisabled;
  final DateTime? lastEventTime;
  final bool isLoading;
  final VoidCallback onTap;

  const BiologicalActionButton({
    super.key,
    required this.eventType,
    required this.isNight,
    this.isDisabled = false,
    this.lastEventTime,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventColor = eventType.getAccentColor(context);

    return Opacity(
      opacity: isDisabled ? 0.35 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              customBorder: const CircleBorder(),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: eventColor.withOpacity(0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(eventType.icon, color: eventColor, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          _buildTimeLabel(eventColor),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(Color eventColor) {
    final textColor = isNight ? eventColor : const Color(0xFF455A64);

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    if (isLoading) return Text('...', style: textStyle);
    if (lastEventTime == null) return Text('--', style: textStyle);

    return StreamBuilder(
      stream: Stream.periodic(const Duration(minutes: 1)),
      builder: (context, _) {
        final diff = DateTime.now().difference(lastEventTime!);
        String timeStr = 'Ahora';
        if (diff.inDays > 0) {
          timeStr = '${diff.inDays}d';
        } else if (diff.inHours > 0) {
          final mins = diff.inMinutes.remainder(60);
          timeStr = mins > 0 ? '${diff.inHours}h ${mins}m' : '${diff.inHours}h';
        } else if (diff.inMinutes > 0) {
          timeStr = '${diff.inMinutes}m';
        }
        return Text(timeStr, style: textStyle);
      },
    );
  }
}