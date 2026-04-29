import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CustomLineChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = List<Map<String, dynamic>>.from(data['series'] ?? []);

    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
    ];

    double maxY = 0;
    for (var s in series) {
      final values = List<num>.from(s['data'] ?? []);
      for (var val in values) {
        if (val.toDouble() > maxY) maxY = val.toDouble();
      }
    }
    maxY = (maxY + 2).ceilToDouble();

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < xLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(xLabels[index], style: const TextStyle(fontSize: 10)),
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
                      return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
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
                final color = colors[idx % colors.length];

                return LineChartBarData(
                  spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.1),
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
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[entry.key % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(entry.value['name'], style: const TextStyle(fontSize: 12)),
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

    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: values.asMap().entries.map((entry) {
                final idx = entry.key;
                final value = entry.value.toDouble();
                return PieChartSectionData(
                  color: colors[idx % colors.length],
                  value: value,
                  title: '${value.toInt()}%',
                  radius: 40,
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[entry.key % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
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

    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
    ];

    List<BarChartGroupData> barGroups = [];
    
    double maxY = 0;

    for (int i = 0; i < xLabels.length; i++) {
      double currentY = 0;
      List<BarChartRodStackItem> stackItems = [];

      for (int j = 0; j < series.length; j++) {
        final values = List<num>.from(series[j]['data'] ?? []);
        if (i < values.length) {
          final val = values[i].toDouble();
          stackItems.add(BarChartRodStackItem(currentY, currentY + val, colors[j % colors.length]));
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
              width: 25,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    maxY = (maxY + 2).ceilToDouble();

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < xLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(xLabels[index], style: const TextStyle(fontSize: 10)),
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
                      return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
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
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[entry.key % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(entry.value['name'], style: const TextStyle(fontSize: 12)),
              ],
            );
          }).toList(),
        )
      ],
    );
  }
}