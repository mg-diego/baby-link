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

    return Scaffold(
      appBar: const CustomTopBar(centerContent: Text('Estadísticas')),
      body: Column(
        children: [
          DateSelector(babyId: babyId, isRangeMode: true),
          const StatsCategorySelector(),
          const Divider(height: 1),
          
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error al cargar datos:\n$err', textAlign: TextAlign.center),
                ),
              ),
              data: (data) {
                if (data == null || data.isEmpty) {
                  return const Center(child: Text('No hay datos para este rango.'));
                }

                final summaryCards = List<Map<String, dynamic>>.from(data['summary_cards'] ?? []);
                final charts = List<Map<String, dynamic>>.from(data['charts'] ?? []);

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(statsProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // 1. Pintamos las tarjetas de resumen (KPIs)
                      if (summaryCards.isNotEmpty) ...[
                        _buildSummaryGrid(context, summaryCards),
                        const SizedBox(height: 24),
                      ],

                      // 2. Pintamos las gráficas dinámicamente
                      ...charts.map((chart) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: _buildChartWidget(context, chart),
                        );
                      }),
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

  // --- WIDGETS PRIVADOS (El Patrón Factory) ---

  Widget _buildSummaryGrid(BuildContext context, List<Map<String, dynamic>> cards) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final trend = card['trend'] as String?;
        final isPositiveTrend = trend != null && trend.startsWith('+');

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card['label'] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      card['value'] ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (trend != null)
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPositiveTrend ? Colors.green : Colors.redAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartWidget(BuildContext context, Map<String, dynamic> chart) {
    final title = chart['title'] ?? 'Sin título';
    final type = chart['type'] ?? 'unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Aquí va el Factory que decide qué pintar
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
    if (data == null) return const Center(child: Text('Sin datos'));

    switch (type) {
      case 'line':
      case 'line_multiple':
        return CustomLineChart(data: data);
      case 'donut':
        return CustomDonutChart(data: data);
      case 'stacked_bar':
        return CustomStackedBarChart(data: data);
      default:
        return const Center(child: Text('Gráfica no soportada'));
    }
  }
}