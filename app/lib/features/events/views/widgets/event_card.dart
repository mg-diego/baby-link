import 'package:flutter/material.dart';
import '../../../../core/models/event_type.dart';

class EventCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  late final EventType eventType;
  late final DateTime startTime;
  late final DateTime? endTime;
  late final bool isOngoing;
  late final String metaStr;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final metadata = event['metadata'] as Map<String, dynamic>? ?? {};
    eventType = EventType.fromBackend(event['category'], metadata);
    startTime = DateTime.parse(event['start_time']).toLocal();
    endTime = event['end_time'] != null ? DateTime.parse(event['end_time']).toLocal() : null;
    isOngoing = event['end_time'] == null && _isDurationEvent(eventType);
    metaStr = _buildMetaStr(metadata);

    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    if (isOngoing) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool _isDurationEvent(EventType t) =>
      t == EventType.nap || t == EventType.nightWaking || t == EventType.nursing || t == EventType.pumping;

  String _fmt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _duration(DateTime s, DateTime e) {
    final d = e.difference(s);
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _buildMetaStr(Map<String, dynamic> meta) {
    if (meta.isEmpty) return '';
    final details = <String>[];
    if (meta['milk_type'] != null) details.add(meta['milk_type']);
    if (meta['amount_ml'] != null) details.add('${meta['amount_ml']} ml');
    if (meta['amount']?.toString().isNotEmpty == true) details.add(meta['amount'].toString());
    if (meta['ui_condition'] != null) details.add(meta['ui_condition']);
    else if (meta['condition'] != null) details.add(meta['condition']);
    if (meta['celsius'] != null) details.add('${meta['celsius']}°C');
    if (meta['how'] != null) details.add(meta['how']);
    if (meta['mood'] != null) details.add(meta['mood']);
    if (meta['ended'] != null) details.add(meta['ended']);
    String result = details.join(' · ');
    if (meta['notes']?.toString().isNotEmpty == true) {
      if (result.isNotEmpty) result += '\n';
      result += '📝 ${meta['notes']}';
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final Color accent = eventType.accentColor;

    final timeDisplay = endTime != null ? '${_fmt(startTime)} - ${_fmt(endTime!)}' : _fmt(startTime);
    final durationLabel = endTime != null ? _duration(startTime, endTime!) : null;

    return Dismissible(
      key: ValueKey('dismiss_${widget.event['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Eliminar registro', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('¿Deseas borrar este evento de ${eventType.uiLabel}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('BORRAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isOngoing ? accent.withOpacity(0.08) : eventType.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48, 
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12), 
                      borderRadius: BorderRadius.circular(14)
                    ),
                    child: Icon(eventType.icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              eventType.uiLabel, 
                              style: TextStyle(
                                fontWeight: FontWeight.w700, 
                                fontSize: 16, 
                                color: onSurface.withOpacity(0.9),
                                letterSpacing: -0.2,
                              )
                            ),
                            if (isOngoing) ...[
                              const SizedBox(width: 8), 
                              OngoingBadge(anim: _pulseAnim, color: accent)
                            ],
                          ],
                        ),
                        
                        if (durationLabel != null || metaStr.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                if (durationLabel != null)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: accent.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          durationLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (metaStr.isNotEmpty)
                                  TextSpan(
                                    text: metaStr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: onSurface.withOpacity(0.5),
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Text(
                    timeDisplay,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800, 
                      color: onSurface.withOpacity(0.85),
                      letterSpacing: -0.5, 
                    ),
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

class OngoingBadge extends StatelessWidget {
  final Animation<double> anim;
  final Color color;
  const OngoingBadge({super.key, required this.anim, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1 + 0.1 * anim.value),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4 + 0.3 * anim.value), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5, 
              height: 5, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: color.withOpacity(0.7 + 0.3 * anim.value)
              )
            ),
            const SizedBox(width: 4),
            Text(
              'EN CURSO', 
              style: TextStyle(
                fontSize: 9, 
                fontWeight: FontWeight.w800, 
                color: color, 
                letterSpacing: 0.5
              )
            ),
          ],
        ),
      ),
    );
  }
}