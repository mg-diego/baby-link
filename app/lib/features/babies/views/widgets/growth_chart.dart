import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:app/features/babies/views/baby_info_screen.dart';

/// Evolución de una medida de crecimiento con la edad (en meses) en el eje X.
class GrowthChart extends StatelessWidget {
  final DateTime dob;
  final List<GrowthPoint> points;
  final String unit;
  final Color color;

  const GrowthChart({
    super.key,
    required this.dob,
    required this.points,
    required this.unit,
    required this.color,
  });

  static const _daysPerMonth = 30.4375;

  double _ageInMonths(DateTime date) => date.difference(dob).inHours / 24 / _daysPerMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = points.map((p) => FlSpot(_ageInMonths(p.date), p.value)).toList();

    final minValue = spots.map((s) => s.y).reduce(math.min);
    final maxValue = spots.map((s) => s.y).reduce(math.max);
    final padding = math.max((maxValue - minValue) * 0.15, maxValue * 0.05);

    final minX = math.max(0.0, spots.first.x.floorToDouble());
    final maxX = math.max(minX + 1, spots.last.x.ceilToDouble());
    final xInterval = math.max(1.0, ((maxX - minX) / 6).ceilToDouble());

    final labelStyle = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: math.max(0, minValue - padding),
        maxY: maxValue + padding,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${value.round()}', style: labelStyle),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Text(formatMeasure(value), style: labelStyle);
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.surfaceContainerHighest.withValues(alpha: 0.95),
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final point = points[spot.spotIndex];
              return LineTooltipItem(
                '${formatMeasure(point.value)} $unit\n',
                TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
                children: [
                  TextSpan(
                    text: DateFormat('d MMM y', 'es').format(point.date),
                    style: TextStyle(color: scheme.onSurface, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeWidth: 1.5,
                strokeColor: scheme.surface,
              ),
            ),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
