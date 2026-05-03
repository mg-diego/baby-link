import 'package:app/shared/widgets/custom_top_bar.dart';
import 'package:app/features/analytics/providers/daily_summary_provider.dart';
import 'package:app/features/analytics/views/widgets/category_selector.dart';
import 'package:app/features/analytics/views/widgets/chart_widgets.dart';
import 'package:app/features/widgets/date_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerWidget {
  final String babyId;
  const StatsScreen({super.key, required this.babyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1222) : const Color(0xFFFAFBFF),
      appBar: const CustomTopBar(centerContent: Text('Estadísticas')),
      body: Column(
        children: [
          DateSelector(babyId: babyId, isRangeMode: true),
          const StatsCategorySelector(),
          Divider(height: 1, color: cs.outline.withOpacity(0.2)),

          Expanded(
            child: statsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF4A90D9),
                  strokeWidth: 2.5,
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_outlined,
                          size: 48,
                          color: cs.onSurface.withOpacity(0.25)),
                      const SizedBox(height: 12),
                      Text(
                        'Error al cargar datos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$err',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                if (data == null || data.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_chart_outlined_rounded,
                            size: 56,
                            color: cs.onSurface.withOpacity(0.18)),
                        const SizedBox(height: 12),
                        Text(
                          'Sin datos para este rango',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.40),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final summaryCards =
                    List<Map<String, dynamic>>.from(data['summary_cards'] ?? []);
                final charts =
                    List<Map<String, dynamic>>.from(data['charts'] ?? []);

                return RefreshIndicator(
                  color: const Color(0xFF4A90D9),
                  backgroundColor: isDark
                      ? const Color(0xFF1A1D2E)
                      : Colors.white,
                  onRefresh: () async => ref.refresh(statsProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      if (summaryCards.isNotEmpty) ...[
                        _buildSummaryGrid(context, isDark, summaryCards),
                        const SizedBox(height: 24),
                      ],
                      ...charts.map((chart) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildChartWidget(context, isDark, chart),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary grid ────────────────────────────────────────────────────────────

  Widget _buildSummaryGrid(
    BuildContext context,
    bool isDark,
    List<Map<String, dynamic>> cards,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) =>
          _SummaryCard(card: cards[i], isDark: isDark),
    );
  }

  // ─── Chart card ──────────────────────────────────────────────────────────────

  Widget _buildChartWidget(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> chart,
  ) {
    final title = chart['title'] ?? 'Sin título';
    final type = chart['type'] ?? 'unknown';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE8EDF5),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF0F1222).withOpacity(0.40),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF4A90D9).withOpacity(0.07),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFE8EAF6)
                        : const Color(0xFF2D3142),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _getSpecificChart(context, type, chart['data']),
          ),
        ],
      ),
    );
  }

  Widget _getSpecificChart(BuildContext context, String type, dynamic data) {
    if (data == null) {
      return Center(
        child: Text(
          'Sin datos',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
          ),
        ),
      );
    }
    switch (type) {
      case 'line':
      case 'line_multiple':
        return CustomLineChart(data: data);
      case 'donut':
        return CustomDonutChart(data: data);
      case 'stacked_bar':
        return CustomStackedBarChart(data: data);
      default:
        return Center(
          child: Text(
            'Gráfica no soportada',
            style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
            ),
          ),
        );
    }
  }
}

// ─── Summary card widget ───────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool isDark;

  const _SummaryCard({required this.card, required this.isDark});

  // Asigna un color de acento según el tipo de KPI
  Color _accentFor(String? label) {
    final l = (label ?? '').toLowerCase();
    if (l.contains('biberón') || l.contains('leche') || l.contains('lactancia')) {
      return const Color(0xFF1D9E75); // teal — alimentación
    }
    if (l.contains('pañal') || l.contains('diaper')) {
      return const Color(0xFFEF9F27); // amber — pañal
    }
    if (l.contains('siesta') || l.contains('nap') || l.contains('sueño')) {
      return const Color(0xFF7F77DD); // lavanda — sueño
    }
    if (l.contains('despertar') || l.contains('noche')) {
      return const Color(0xFFD85A30); // coral — noche
    }
    return const Color(0xFF4A90D9); // azul — genérico
  }

  @override
  Widget build(BuildContext context) {
    final trend = card['trend'] as String?;
    final isPositive = trend != null && trend.startsWith('+');
    final isNegative = trend != null && trend.startsWith('-');
    final accent = _accentFor(card['label']);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE8EDF5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF0F1222).withOpacity(0.35)
                : accent.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dot + label
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card['label'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF7986CB)
                        : const Color(0xFF546E7A),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Value + trend
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  card['value'] ?? '—',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFE8EAF6)
                        : const Color(0xFF2D3142),
                    height: 1.1,
                  ),
                ),
              ),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF1D9E75).withOpacity(0.12)
                        : isNegative
                            ? const Color(0xFFE24B4A).withOpacity(0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isPositive
                          ? const Color(0xFF1D9E75)
                          : isNegative
                              ? const Color(0xFFE24B4A)
                              : isDark
                                  ? const Color(0xFF7986CB)
                                  : const Color(0xFF546E7A),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}