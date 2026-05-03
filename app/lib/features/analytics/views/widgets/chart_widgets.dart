import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app/shared/models/event_type.dart';

Color _getColorForSeries(BuildContext context, String seriesName, int index) {
  final lower = seriesName.toLowerCase();
  if (lower.contains('siesta') || lower.contains('nap')) return EventType.nap.getAccentColor(context);
  if (lower.contains('sueño') || lower.contains('sleep') || lower.contains('nocturno')) return EventType.bedtime.getAccentColor(context);
  if (lower.contains('despertar') || lower.contains('waking')) return EventType.nightWaking.getAccentColor(context);
  if (lower.contains('pecho') || lower.contains('nursing') || lower.contains('toma')) return EventType.nursing.getAccentColor(context);
  if (lower.contains('biber') || lower.contains('bottle')) return EventType.bottle.getAccentColor(context);
  if (lower.contains('sólido') || lower.contains('comida') || lower.contains('solids')) return EventType.solids.getAccentColor(context);
  if (lower.contains('pañal') || lower.contains('diaper')) return EventType.diaper.getAccentColor(context);

  final fallbackColors = [
    Theme.of(context).colorScheme.primary,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
  ];
  return fallbackColors[index % fallbackColors.length];
}

String _formatTooltipValue(double val) {
  final int h = val.floor();
  final int m = ((val - h) * 60).round();
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

class CustomLineChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = List<Map<String, dynamic>>.from(data['series'] ?? []);

    double maxY = 0;
    for (var s in series) {
      final values = List<num>.from(s['data'] ?? []);
      for (var val in values) {
        if (val.toDouble() > maxY) maxY = val.toDouble();
      }
    }
    maxY = (maxY + 2).ceilToDouble();

    int xInterval = (xLabels.length / 6).ceil();
    if (xInterval < 1) xInterval = 1;

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  //tooltipRoundedRadius: 12,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final valStr = _formatTooltipValue(spot.y);
                      final seriesName = series[spot.barIndex]['name'];
                      final color = _getColorForSeries(context, seriesName, spot.barIndex);
                      
                      return LineTooltipItem(
                        '$seriesName\n',
                        TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: valStr,
                            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: xInterval.toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < xLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            xLabels[index], 
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('');
                      return Text(
                        '${value.toInt()}h', 
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (xLabels.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineBarsData: series.asMap().entries.map((entry) {
                final idx = entry.key;
                final serie = entry.value;
                final values = List<num>.from(serie['data'] ?? []);
                final color = _getColorForSeries(context, serie['name'], idx);

                return LineChartBarData(
                  spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3,
                      color: color,
                      strokeWidth: 1.5,
                      strokeColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.1),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: series.asMap().entries.map((entry) {
            final color = _getColorForSeries(context, entry.value['name'], entry.key);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.value['name'], 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            );
          }).toList(),
        )
      ],
    );
  }
}

class CustomDonutChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomDonutChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = List<Map<String, dynamic>>.from(data['series'] ?? []);
    
    if (series.isEmpty) return const SizedBox();

    final values = List<num>.from(series.first['data'] ?? []);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              pieTouchData: PieTouchData(enabled: true),
              sections: values.asMap().entries.map((entry) {
                final idx = entry.key;
                final value = entry.value.toDouble();
                final label = xLabels.length > idx ? xLabels[idx] : '';
                final color = _getColorForSeries(context, label, idx);

                return PieChartSectionData(
                  color: color,
                  value: value,
                  title: '${value.toInt()}%',
                  radius: 45,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: xLabels.asMap().entries.map((entry) {
              final color = _getColorForSeries(context, entry.value, entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class CustomStackedBarChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomStackedBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = List<Map<String, dynamic>>.from(data['series'] ?? []);

    final screenWidth = MediaQuery.of(context).size.width;
    final dynamicBarWidth = xLabels.isNotEmpty
        ? ((screenWidth - 100) / (xLabels.length * 1.2)).clamp(4.0, 35.0)
        : 25.0;

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 0; i < xLabels.length; i++) {
      double currentY = 0;
      List<BarChartRodStackItem> stackItems = [];

      for (int j = 0; j < series.length; j++) {
        final values = List<num>.from(series[j]['data'] ?? []);
        if (i < values.length) {
          final val = values[i].toDouble();
          final color = _getColorForSeries(context, series[j]['name'], j);
          stackItems.add(BarChartRodStackItem(currentY, currentY + val, color));
          currentY += val;
        }
      }

      if (currentY > maxY) maxY = currentY;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: currentY,
              rodStackItems: stackItems,
              width: dynamicBarWidth,
              borderRadius: BorderRadius.circular(dynamicBarWidth > 8 ? 6 : 2),
            ),
          ],
        ),
      );
    }

    maxY = (maxY + 2).ceilToDouble();
    
    int xInterval = (xLabels.length / 6).ceil();
    if (xInterval < 1) xInterval = 1;

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dateLabel = xLabels[group.x];
                    List<TextSpan> children = [];
                    
                    for (int j = 0; j < series.length; j++) {
                      final values = List<num>.from(series[j]['data'] ?? []);
                      if (group.x < values.length && values[group.x] > 0) {
                        final valStr = _formatTooltipValue(values[group.x].toDouble());
                        final seriesName = series[j]['name'];
                        final color = _getColorForSeries(context, seriesName, j);
                        children.add(
                          TextSpan(
                            text: '$seriesName: $valStr\n',
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        );
                      }
                    }

                    return BarTooltipItem(
                      '$dateLabel\n',
                      TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 10),
                      children: children,
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1, 
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      
                      if (index % xInterval != 0) {
                        return const SizedBox.shrink();
                      }

                      if (index >= 0 && index < xLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            xLabels[index], 
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        '${value.toInt()}h', 
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: series.asMap().entries.map((entry) {
            final color = _getColorForSeries(context, entry.value['name'], entry.key);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.value['name'], 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            );
          }).toList(),
        )
      ],
    );
  }
}

class CustomSummaryCards extends StatelessWidget {
  final Map<String, dynamic> summaryData;

  const CustomSummaryCards({super.key, required this.summaryData});

  @override
  Widget build(BuildContext context) {
    final items = summaryData.entries.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final label = items[index].key;
        final rawValue = items[index].value;
        final color = _getColorForSeries(context, label, index);

        String displayValue = rawValue.toString();
        if (rawValue is num) {
          displayValue = _formatTooltipValue(rawValue.toDouble());
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.analytics_rounded, color: color, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}