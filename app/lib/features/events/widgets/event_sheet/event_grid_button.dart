import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/shared/models/event_type.dart';

class EventGridButton extends StatelessWidget {
  final EventType eventType;
  final bool isDisabled;
  final bool isActive;
  final AsyncValue<Map<String, dynamic>> lastEventsAsync;
  final VoidCallback onTap;

  const EventGridButton({
    super.key,
    required this.eventType,
    required this.isDisabled,
    this.isActive = false,
    required this.lastEventsAsync,
    required this.onTap,
  });

  bool _showsTimePlaceholder(EventType type) {
    return type == EventType.wokeUp ||
        type == EventType.nap ||
        type == EventType.bedtime ||
        type == EventType.bottle ||
        type == EventType.nursing ||
        type == EventType.solids ||
        type == EventType.bath ||
        type == EventType.nightWaking ||
        type == EventType.diaper;
  }

  String _formatTime(String? isoString, {bool short = false}) {
    if (isoString == null) return '--';
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '--';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) {
      final mins = diff.inMinutes.remainder(60);
      return (mins > 0 && !short)
          ? '${diff.inHours}h ${mins}m'
          : '${diff.inHours}h';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 65) / 4;
    final showTime = _showsTimePlaceholder(eventType);

    final Color baseColor = isActive ? Colors.red.shade400 : eventType.getAccentColor(context);
    final Color bgColor = isActive ? baseColor.withValues(alpha: 0.15) : eventType.getBackgroundColor(context);

    return Opacity(
      opacity: isDisabled && !isActive ? 0.35 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled && !isActive ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: itemWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withValues(alpha: 0.5),
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        isActive ? Icons.stop_circle_outlined : eventType.icon,
                        color: baseColor,
                        size: 24,
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _PulseDot(color: Colors.red.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isActive ? 'Detener' : eventType.uiLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? Colors.red.shade600 : null,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showTime && (!isDisabled || isActive)) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 12,
                    child: lastEventsAsync.when(
                      data: (eventsMap) {
                        if (eventType == EventType.diaper) {
                          final wetTime = _formatTime(
                            eventsMap['diaper_wet'],
                            short: true,
                          );
                          final dirtyTime = _formatTime(
                            eventsMap['diaper_dirty'],
                            short: true,
                          );

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 233, 224, 54),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                wetTime,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                dirtyTime,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }

                        final key = eventType == EventType.bottle
                            ? 'bottle'
                            : eventType == EventType.nursing
                                ? 'nursing'
                                : eventType == EventType.solids
                                    ? 'solids'
                                    : eventType.backendCategory;

                        return Text(
                          _formatTime(eventsMap[key], short: true),
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: SizedBox(
                          height: 8,
                          width: 8,
                          child: CircularProgressIndicator(strokeWidth: 1),
                        ),
                      ),
                      error: (_, __) => Text(
                        '--',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}