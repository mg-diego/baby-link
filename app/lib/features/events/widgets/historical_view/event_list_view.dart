import 'package:flutter/material.dart';
import 'event_card.dart';

class EventListView extends StatefulWidget {
  final List<Map<String, dynamic>> initialEvents;
  final List<Map<String, dynamic>> yesterdayEvents;
  final bool isToday;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onTap;

  const EventListView({
    super.key,
    required this.initialEvents,
    required this.yesterdayEvents,
    required this.isToday,
    required this.onRefresh,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<EventListView> createState() => _EventListViewState();
}

class _EventListViewState extends State<EventListView> {
  late List<Map<String, dynamic>> _events;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.initialEvents);
  }

  @override
  void didUpdateWidget(covariant EventListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEvents != oldWidget.initialEvents) {
      setState(() {
        _events = widget.initialEvents;
      });
    }
  }

  List<_SleepAnchor> _buildAnchors(List<dynamic> allEvents) {
    List<_SleepAnchor> anchors = [];
    for (var e in allEvents) {
      final cat = e['category'];
      final start = DateTime.parse(e['start_time']).toLocal();
      final end = e['end_time'] != null ? DateTime.parse(e['end_time']).toLocal() : null;

      if (cat == 'woke_up') {
        anchors.add(_SleepAnchor(start, true));
      } else if (cat == 'bed_time') {
        anchors.add(_SleepAnchor(start, false));
      } else if (cat == 'nap') {
        anchors.add(_SleepAnchor(start, false));
        if (end != null) anchors.add(_SleepAnchor(end, true));
      } else if (cat == 'night_waking') {
        anchors.add(_SleepAnchor(start, true));
        if (end != null) anchors.add(_SleepAnchor(end, false));
      }
    }
    anchors.sort((a, b) => b.time.compareTo(a.time));
    return anchors;
  }

  Duration? _calcGap(List<_SleepAnchor> anchors, DateTime time, bool seekingWake) {
    for (var a in anchors) {
      if (a.time.isBefore(time)) {
        if (a.isWake == seekingWake) {
          return time.difference(a.time);
        }
        return null; 
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return _EmptyState(isToday: widget.isToday);
    }

    final sorted = List<Map<String, dynamic>>.from(_events)
      ..sort((a, b) => b['start_time'].compareTo(a['start_time']));

    final allEventsForAnchors = [..._events, ...widget.yesterdayEvents];
    final anchors = _buildAnchors(allEventsForAnchors);

    List<Widget> listItems = [];
    for (var event in sorted) {
      final cat = event['category'];
      final start = DateTime.parse(event['start_time']).toLocal();

      // 1. PINTAMOS LA TARJETA DEL EVENTO (Siempre va primero)
      listItems.add(
        EventCard(
          key: ValueKey(event['id']),
          event: event,
          onTap: () => widget.onTap(event),
          onDelete: () {
            setState(() => _events.removeWhere((e) => e['id'] == event['id']));
            widget.onDelete(event);
          },
        ),
      );

      // 2. PINTAMOS EL SEPARADOR DEBAJO (Cronológicamente "antes" del evento)
      if (cat == 'bed_time') {
        // Cierra el gran ciclo de vigilia del día
        final dur = _calcGap(anchors, start, true); 
        if (dur != null) {
          listItems.add(_SeparatorItem('Fin de periodo de vigilia', dur, Key('sep_${event['id']}')));
        }
      } else if (cat == 'nap') {
        // Cierra una ventana de vigilia normal entre siestas
        final dur = _calcGap(anchors, start, true); 
        if (dur != null) {
          listItems.add(_SeparatorItem('Ventana de vigilia', dur, Key('sep_${event['id']}')));
        }
      } else if (cat == 'woke_up') {
        // Cierra el gran ciclo de sueño de la noche
        final dur = _calcGap(anchors, start, false); 
        if (dur != null) {
          listItems.add(_SeparatorItem('Fin de periodo de sueño', dur, Key('sep_${event['id']}')));
        }
      } else if (cat == 'night_waking') {
        // Cierra un bloque de sueño nocturno antes de despertarse
        final dur = _calcGap(anchors, start, false); 
        if (dur != null) {
          listItems.add(_SeparatorItem('Sueño continuo', dur, Key('sep_${event['id']}')));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        itemCount: listItems.length,
        itemBuilder: (context, index) => listItems[index],
      ),
    );
  }
}

class _SleepAnchor {
  final DateTime time;
  final bool isWake;
  _SleepAnchor(this.time, this.isWake);
}

class _SeparatorItem extends StatelessWidget {
  final String label;
  final Duration duration;

  const _SeparatorItem(this.label, this.duration, Key key) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final h = duration.inHours, m = duration.inMinutes % 60;
    final timeStr = (h > 0 && m > 0) ? '${h}h ${m}m' : (h > 0 ? '${h}h' : '$m min');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text('$label $timeStr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.3)),
          ),
          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3), thickness: 1)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isToday;
  const _EmptyState({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(isToday ? 'Aún no hay eventos hoy.' : 'Sin eventos este día.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 15)),
        ],
      ),
    );
  }
}