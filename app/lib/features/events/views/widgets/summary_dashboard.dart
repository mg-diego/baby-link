import 'package:flutter/material.dart';

class SummaryDashboard extends StatelessWidget {
  final dynamic summary;

  const SummaryDashboard({super.key, required this.summary});

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.bedtime_rounded,
            value: _formatMinutes(summary.totalNapMinutes),
            label: 'Siesta',
            color: const Color(0xFF7C83FD),
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.local_drink_rounded,
            value: '${summary.totalFeeds}',
            label: 'Tomas',
            color: const Color(0xFF26C6DA),
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.baby_changing_station_rounded,
            value: '${summary.totalDirtyDiapers}',
            label: 'Pañales',
            color: const Color(0xFFFFB74D),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}