import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app/shared/models/event_type.dart';

const double _plotHeight = 200;
const int _maxBottomLabels = 6;

// ─── Unidades ─────────────────────────────────────────────────────────────────

/// Unidad de los valores de una gráfica (campo `unit` que envía la API).
enum ChartUnit {
  hours,
  minutes,
  count,
  ml,
  kg,
  cm;

  static ChartUnit fromData(Map<String, dynamic> data) {
    switch (data['unit']) {
      case 'minutes':
        return ChartUnit.minutes;
      case 'count':
        return ChartUnit.count;
      case 'ml':
        return ChartUnit.ml;
      case 'kg':
        return ChartUnit.kg;
      case 'cm':
        return ChartUnit.cm;
      default:
        return ChartUnit.hours;
    }
  }

  bool get startsAtZero => this != ChartUnit.kg && this != ChartUnit.cm;
}

String _decimal(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

String _hoursMinutes(double hours) {
  final total = (hours * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

/// Valor legible para tooltips y leyendas.
String formatChartValue(double v, ChartUnit unit) {
  switch (unit) {
    case ChartUnit.hours:
      return _hoursMinutes(v);
    case ChartUnit.minutes:
      return v >= 60 ? _hoursMinutes(v / 60) : '${v.round()} min';
    case ChartUnit.count:
      return '${v.round()}';
    case ChartUnit.ml:
      return '${v.round()} ml';
    case ChartUnit.kg:
      return '${_decimal(v, 2)} kg';
    case ChartUnit.cm:
      return '${_decimal(v, 1)} cm';
  }
}

/// Etiqueta corta para el eje Y.
String _axisLabel(double v, ChartUnit unit) {
  switch (unit) {
    case ChartUnit.hours:
      return '${_decimal(v, 1)}h';
    case ChartUnit.minutes:
      return v >= 120 ? '${_decimal(v / 60, 1)}h' : '${v.round()}m';
    case ChartUnit.count:
      return '${v.round()}';
    case ChartUnit.ml:
      return v >= 1000 ? '${_decimal(v / 1000, 1)}L' : '${v.round()}';
    case ChartUnit.kg:
      return _decimal(v, 1);
    case ChartUnit.cm:
      return '${v.round()}';
  }
}

// ─── Eje Y con intervalos "redondos" ──────────────────────────────────────────

class _YAxis {
  final double min;
  final double max;
  final double interval;
  const _YAxis(this.min, this.max, this.interval);

  factory _YAxis.fit(Iterable<double> values, ChartUnit unit) {
    final list = values.where((v) => v.isFinite).toList();
    double lo = list.isEmpty ? 0 : list.reduce(math.min);
    double hi = list.isEmpty ? 1 : list.reduce(math.max);

    if (unit.startsAtZero) {
      lo = 0;
    } else {
      final pad = math.max((hi - lo) * 0.15, unit == ChartUnit.kg ? 0.2 : 1);
      lo = math.max(0, lo - pad);
      hi = hi + pad;
    }
    if (hi <= lo) hi = lo + 1;

    final raw = (hi - lo) / 4;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / magnitude;
    final step = norm <= 1
        ? 1
        : norm <= 2
            ? 2
            : norm <= 2.5
                ? 2.5
                : norm <= 5
                    ? 5
                    : 10;
    var interval = step * magnitude;
    if (unit == ChartUnit.count) interval = math.max(1, interval.ceilToDouble());

    final min = (lo / interval).floor() * interval;
    var max = (hi / interval).ceil() * interval;
    if (max <= min) max = min + interval;
    return _YAxis(min, max, interval);
  }
}

// ─── Colores ──────────────────────────────────────────────────────────────────

Color _getColorForSeries(BuildContext context, String seriesName, int index) {
  final lower = seriesName.toLowerCase();
  if (lower.contains('siesta') || lower.contains('nap')) return EventType.nap.getAccentColor(context);
  if (lower.contains('despert') || lower.contains('waking')) return EventType.nightWaking.getAccentColor(context);
  if (lower.contains('sueño') || lower.contains('sleep') || lower.contains('nocturno')) return EventType.bedtime.getAccentColor(context);
  if (lower.contains('pecho') || lower.contains('nursing') || lower.contains('lactancia')) return EventType.nursing.getAccentColor(context);
  if (lower.contains('biber') || lower.contains('bottle') || lower.contains('volumen')) return EventType.bottle.getAccentColor(context);
  if (lower.contains('sólido') || lower.contains('comida') || lower.contains('solids')) return EventType.solids.getAccentColor(context);
  if (lower.contains('mojado')) return const Color(0xFF4A90D9);
  if (lower.contains('sucio')) return const Color(0xFFA1785C);
  if (lower.contains('mixto')) return EventType.diaper.getAccentColor(context);
  if (lower.contains('seco') || lower.contains('otro')) return Colors.blueGrey.shade300;
  if (lower.contains('pañal') || lower.contains('diaper')) return EventType.diaper.getAccentColor(context);
  if (lower.contains('peso') || lower.contains('altura') || lower.contains('perímetro')) {
    return EventType.growth.getAccentColor(context);
  }

  final fallbackColors = [
    Theme.of(context).colorScheme.primary,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.teal,
  ];
  return fallbackColors[index % fallbackColors.length];
}

// ─── Piezas comunes ───────────────────────────────────────────────────────────

class _ChartSeries {
  final String name;
  final List<double?> values;
  const _ChartSeries(this.name, this.values);

  static List<_ChartSeries> parse(Map<String, dynamic> data) {
    final raw = List<Map<String, dynamic>>.from(data['series'] ?? []);
    return raw
        .map((s) => _ChartSeries(
              s['name']?.toString() ?? '',
              List<dynamic>.from(s['data'] ?? [])
                  .map((v) => v is num ? v.toDouble() : null)
                  .toList(),
            ))
        .toList();
  }
}

class _NoChartData extends StatelessWidget {
  const _NoChartData();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          'Sin datos',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<_ChartSeries> series;
  final bool squareMarkers;
  const _Legend({required this.series, this.squareMarkers = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: series.asMap().entries.map((entry) {
        final color = _getColorForSeries(context, entry.value.name, entry.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: squareMarkers ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: squareMarkers ? BorderRadius.circular(3) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.value.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        );
      }).toList(),
    );
  }
}

int _labelStep(int count) => math.max(1, (count / _maxBottomLabels).ceil());

AxisTitles _bottomTitles(BuildContext context, List<String> xLabels) {
  final step = _labelStep(xLabels.length);
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        if (value != index.toDouble() || index < 0 || index >= xLabels.length || index % step != 0) {
          return const SizedBox.shrink();
        }
        return SideTitleWidget(
          meta: meta,
          space: 8,
          fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
          child: Text(
            xLabels[index],
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    ),
  );
}

AxisTitles _leftTitles(BuildContext context, _YAxis axis, ChartUnit unit) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 38,
      interval: axis.interval,
      getTitlesWidget: (value, meta) {
        // El 0 se sobreentiende
        if (unit.startsAtZero && value == 0) {
          return const SizedBox.shrink();
        }
        return SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(
            _axisLabel(value, unit),
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    ),
  );
}

FlGridData _grid(BuildContext context, _YAxis axis) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: axis.interval,
      getDrawingHorizontalLine: (_) => FlLine(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        strokeWidth: 1,
      ),
    );

Color _tooltipColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95);

// ─── Línea ────────────────────────────────────────────────────────────────────

class CustomLineChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final unit = ChartUnit.fromData(data);
    final series = _ChartSeries.parse(data).where((s) => s.values.any((v) => v != null)).toList();

    if (xLabels.isEmpty || series.isEmpty) return const _NoChartData();

    final axis = _YAxis.fit(series.expand((s) => s.values.whereType<double>()), unit);
    final singlePoint = xLabels.length == 1;
    final dense = xLabels.length > 15;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _plotHeight,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => _tooltipColor(context),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 160,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.asMap().entries.map((entry) {
                      final spot = entry.value;
                      final s = series[spot.barIndex];
                      final color = _getColorForSeries(context, s.name, spot.barIndex);
                      final header = entry.key == 0 ? '${xLabels[spot.x.round()]}\n' : '';
                      final name = series.length > 1 ? '${s.name}: ' : '';
                      return LineTooltipItem(
                        header,
                        TextStyle(color: onSurface, fontSize: 10, fontWeight: FontWeight.w600),
                        children: [
                          TextSpan(
                            text: '$name${formatChartValue(spot.y, unit)}',
                            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: _grid(context, axis),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: _bottomTitles(context, xLabels),
                leftTitles: _leftTitles(context, axis, unit),
              ),
              borderData: FlBorderData(show: false),
              minX: singlePoint ? -0.5 : 0,
              maxX: singlePoint ? 0.5 : (xLabels.length - 1).toDouble(),
              minY: axis.min,
              maxY: axis.max,
              lineBarsData: series.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final color = _getColorForSeries(context, s.name, idx);

                return LineChartBarData(
                  spots: s.values
                      .asMap()
                      .entries
                      .map((e) => e.value == null ? FlSpot.nullSpot : FlSpot(e.key.toDouble(), e.value!))
                      .toList(),
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: color,
                  barWidth: dense ? 2 : 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: dense ? 2 : 3,
                      color: color,
                      strokeWidth: 1.5,
                      strokeColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: series.length == 1 && unit.startsAtZero,
                    color: color.withValues(alpha: 0.1),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 14),
          _Legend(series: series),
        ],
      ],
    );
  }
}

// ─── Donut ────────────────────────────────────────────────────────────────────

class CustomDonutChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomDonutChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = _ChartSeries.parse(data);
    final unit = ChartUnit.fromData(data);
    if (series.isEmpty) return const _NoChartData();

    final values = series.first.values;
    final slices = <({String label, double value, Color color})>[];
    for (var i = 0; i < xLabels.length && i < values.length; i++) {
      final v = values[i] ?? 0;
      if (v > 0) {
        slices.add((label: xLabels[i], value: v, color: _getColorForSeries(context, xLabels[i], i)));
      }
    }
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (slices.isEmpty || total <= 0) return const _NoChartData();

    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: slices.map((s) {
                    final pct = s.value / total * 100;
                    return PieChartSectionData(
                      color: s.color,
                      value: s.value,
                      // En porciones pequeñas el texto no cabe: el % ya aparece en la leyenda
                      title: pct >= 8 ? '${pct.round()}%' : '',
                      radius: 34,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatChartValue(total, unit),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices.map((s) {
              final pct = (s.value / total * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$pct%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: s.color),
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

// ─── Barras (apiladas o simples) ─────────────────────────────────────────────

class CustomStackedBarChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomStackedBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final xLabels = List<String>.from(data['x_labels'] ?? []);
    final series = _ChartSeries.parse(data);
    final unit = ChartUnit.fromData(data);

    double valueAt(_ChartSeries s, int i) => i < s.values.length ? (s.values[i] ?? 0) : 0;

    final totals = List<double>.generate(
      xLabels.length,
      (i) => series.fold<double>(0, (sum, s) => sum + valueAt(s, i)),
    );
    if (xLabels.isEmpty || totals.every((t) => t <= 0)) return const _NoChartData();

    final axis = _YAxis.fit(totals, unit);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _plotHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final plotWidth = constraints.maxWidth - 38;
              final barWidth = (plotWidth / xLabels.length * 0.6).clamp(3.0, 28.0);
              final radius = Radius.circular(barWidth > 8 ? 5 : 2);

              final barGroups = List.generate(xLabels.length, (i) {
                double currentY = 0;
                final stackItems = <BarChartRodStackItem>[];
                for (var j = 0; j < series.length; j++) {
                  final val = valueAt(series[j], i);
                  if (val <= 0) continue;
                  stackItems.add(BarChartRodStackItem(
                    currentY,
                    currentY + val,
                    _getColorForSeries(context, series[j].name, j),
                  ));
                  currentY += val;
                }
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: currentY,
                      rodStackItems: stackItems,
                      color: stackItems.isEmpty ? Colors.transparent : stackItems.first.color,
                      width: barWidth,
                      borderRadius: BorderRadius.vertical(top: radius),
                    ),
                  ],
                );
              });

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: axis.max,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => _tooltipColor(context),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: 160,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final i = group.x;
                        final lines = <TextSpan>[];
                        for (var j = 0; j < series.length; j++) {
                          final val = valueAt(series[j], i);
                          if (val <= 0 && series.length > 1) continue;
                          final name = series.length > 1 ? '${series[j].name}: ' : '';
                          lines.add(TextSpan(
                            text: '\n$name${formatChartValue(val, unit)}',
                            style: TextStyle(
                              color: _getColorForSeries(context, series[j].name, j),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ));
                        }
                        return BarTooltipItem(
                          xLabels[i],
                          TextStyle(color: onSurface, fontWeight: FontWeight.w600, fontSize: 10),
                          children: lines,
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: _bottomTitles(context, xLabels),
                    leftTitles: _leftTitles(context, axis, unit),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: _grid(context, axis),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              );
            },
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 14),
          _Legend(series: series, squareMarkers: true),
        ],
      ],
    );
  }
}
