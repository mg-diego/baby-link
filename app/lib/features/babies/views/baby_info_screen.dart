import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:app/shared/models/event_type.dart';
import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/babies/views/baby_form_screen.dart';
import 'package:app/features/babies/views/widgets/editable_baby_avatar.dart';
import 'package:app/features/babies/views/widgets/growth_chart.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/views/event_form_launcher.dart';
import 'package:app/features/profile/screens/profile_screen.dart';

/// Medidas que se registran en los eventos de crecimiento.
enum GrowthMetric {
  weight('weight_kg', 'Peso', 'kg', Icons.monitor_weight_outlined),
  height('height_cm', 'Altura', 'cm', Icons.straighten_rounded),
  head('head_cm', 'Perímetro craneal', 'cm', Icons.face_outlined);

  final String key;
  final String label;
  final String unit;
  final IconData icon;

  const GrowthMetric(this.key, this.label, this.unit, this.icon);
}

class GrowthPoint {
  final DateTime date;
  final double value;

  const GrowthPoint(this.date, this.value);
}

/// Agrupa las mediciones por métrica (de más antigua a más reciente),
/// ignorando eventos que no incluyan esa medida.
Map<GrowthMetric, List<GrowthPoint>> groupGrowthEvents(List<Map<String, dynamic>> events) {
  final result = {for (final m in GrowthMetric.values) m: <GrowthPoint>[]};

  for (final ev in events) {
    final date = DateTime.tryParse(ev['start_time']?.toString() ?? '')?.toLocal();
    final metadata = ev['metadata'] as Map<String, dynamic>? ?? {};
    if (date == null) continue;

    for (final m in GrowthMetric.values) {
      final raw = metadata[m.key];
      final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      if (value != null && value > 0) result[m]!.add(GrowthPoint(date, value));
    }
  }

  for (final list in result.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  return result;
}

final _numberFormat = NumberFormat('#,##0.##', 'es');
String formatMeasure(double value) => _numberFormat.format(value);

class BabyInfoScreen extends ConsumerWidget {
  const BabyInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babyAsync = ref.watch(babyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi bebé'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Mi cuenta',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: babyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error al cargar datos: $err')),
        data: (baby) {
          if (baby == null || baby['dob'] == null) {
            return _NoBabyView();
          }
          return _BabyInfoBody(baby: baby);
        },
      ),
    );
  }
}

class _NoBabyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.child_care, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Aún no hay ningún bebé vinculado', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BabyFormScreen()),
              ),
              child: const Text('Registrar bebé'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BabyInfoBody extends ConsumerWidget {
  final Map<String, dynamic> baby;

  const _BabyInfoBody({required this.baby});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babyId = baby['id'] as String;
    final name = (baby['name'] as String?) ?? 'Bebé';
    final dob = DateTime.parse(baby['dob']);
    final growthAsync = ref.watch(growthHistoryProvider(babyId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(growthHistoryProvider(babyId));
        await ref.read(growthHistoryProvider(babyId).future).catchError((_) => <Map<String, dynamic>>[]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeaderCard(babyId: babyId, name: name, photoUrl: baby['photo_url'] as String?, dob: dob),
          const SizedBox(height: 12),
          _AgeStatsRow(dob: dob),
          const SizedBox(height: 28),
          _SectionTitle(
            'MEDIDAS ACTUALES',
            trailing: TextButton.icon(
              onPressed: () => launchEventForm(context, ref, babyId, EventType.growth),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ),
          growthAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => _InfoTile(
              icon: Icons.error_outline,
              title: 'No se pudieron cargar las medidas',
              subtitle: 'Desliza hacia abajo para reintentar',
            ),
            data: (events) => _GrowthSection(
              dob: dob,
              grouped: groupGrowthEvents(events),
              onAdd: () => launchEventForm(context, ref, babyId, EventType.growth),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('CURIOSIDADES'),
          _FunFacts(
            dob: dob,
            weights: growthAsync.asData != null
                ? groupGrowthEvents(growthAsync.asData!.value)[GrowthMetric.weight]!
                : const [],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edad
// ---------------------------------------------------------------------------

({int years, int months, int days}) _ageParts(DateTime dob, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var totalMonths = (today.year - dob.year) * 12 + today.month - dob.month;
  if (_monthiversary(dob, totalMonths).isAfter(today)) totalMonths--;
  if (totalMonths < 0) return (years: 0, months: 0, days: 0);

  final days = _daysBetween(_monthiversary(dob, totalMonths), today);
  return (years: totalMonths ~/ 12, months: totalMonths % 12, days: days);
}

String _plural(int n, String singular, String plural) => n == 1 ? '1 $singular' : '$n $plural';

String _ageLabel(DateTime dob, DateTime now) {
  final a = _ageParts(dob, now);
  final parts = <String>[
    if (a.years > 0) _plural(a.years, 'año', 'años'),
    if (a.months > 0) _plural(a.months, 'mes', 'meses'),
    if (a.days > 0 || (a.years == 0 && a.months == 0)) _plural(a.days, 'día', 'días'),
  ];
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Fecha en la que el bebé cumple [totalMonths] meses (ajustando a fin de mes).
DateTime _monthiversary(DateTime dob, int totalMonths) {
  final y = dob.year + (dob.month - 1 + totalMonths) ~/ 12;
  final m = (dob.month - 1 + totalMonths) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, dob.day > lastDay ? lastDay : dob.day);
}

class _HeaderCard extends StatelessWidget {
  final String babyId;
  final String name;
  final String? photoUrl;
  final DateTime dob;

  const _HeaderCard({required this.babyId, required this.name, required this.photoUrl, required this.dob});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = _today();
    final dobLabel = DateFormat("d 'de' MMMM 'de' y", 'es').format(dob);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Row(
        children: [
          EditableBabyAvatar(babyId: babyId, name: name, photoUrl: photoUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ageLabel(dob, today),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.cake_outlined, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Nació el $dobLabel',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeStatsRow extends StatelessWidget {
  final DateTime dob;

  const _AgeStatsRow({required this.dob});

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final days = _daysBetween(dob, today);
    final a = _ageParts(dob, today);
    final totalMonths = a.years * 12 + a.months;

    final next = _monthiversary(dob, totalMonths + 1);
    final daysToNext = _daysBetween(today, next);
    final nextIsBirthday = (totalMonths + 1) % 12 == 0;
    final nextLabel = nextIsBirthday
        ? 'para cumplir ${_plural((totalMonths + 1) ~/ 12, 'año', 'años')}'
        : 'para los ${totalMonths + 1} meses';

    return Row(
      children: [
        Expanded(child: _StatTile(value: NumberFormat.decimalPattern('es').format(days), label: 'días de vida')),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(value: '${days ~/ 7}', label: days ~/ 7 == 1 ? 'semana' : 'semanas')),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: daysToNext == 1 ? '1 día' : '$daysToNext días',
            label: nextLabel,
            highlight: true,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;

  const _StatTile({required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight ? scheme.secondaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? scheme.onSecondaryContainer : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Crecimiento
// ---------------------------------------------------------------------------

class _GrowthSection extends StatefulWidget {
  final DateTime dob;
  final Map<GrowthMetric, List<GrowthPoint>> grouped;
  final VoidCallback onAdd;

  const _GrowthSection({required this.dob, required this.grouped, required this.onAdd});

  @override
  State<_GrowthSection> createState() => _GrowthSectionState();
}

class _GrowthSectionState extends State<_GrowthSection> {
  GrowthMetric? _selected;

  @override
  Widget build(BuildContext context) {
    final available = GrowthMetric.values.where((m) => widget.grouped[m]!.isNotEmpty).toList();

    if (available.isEmpty) {
      return _InfoTile(
        icon: EventType.growth.icon,
        title: 'Sin mediciones todavía',
        subtitle: 'Registra peso, altura o perímetro craneal',
        onTap: widget.onAdd,
      );
    }

    final selected = available.contains(_selected) ? _selected! : available.first;
    final lastDate = available
        .map((m) => widget.grouped[m]!.last.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final daysAgo = _daysBetween(lastDate, _today());
    final agoLabel = switch (daysAgo) {
      0 => 'hoy',
      1 => 'ayer',
      _ => 'hace $daysAgo días',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final m in GrowthMetric.values) ...[
              Expanded(child: _MetricTile(metric: m, points: widget.grouped[m]!)),
              if (m != GrowthMetric.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Última medición: ${DateFormat('d MMM y', 'es').format(lastDate)} ($agoLabel)',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final m in available)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: m == selected,
                          onSelected: (_) => setState(() => _selected = m),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: GrowthChart(
                    dob: widget.dob,
                    points: widget.grouped[selected]!,
                    unit: selected.unit,
                    color: EventType.growth.color,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      'Edad (meses)',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final GrowthMetric metric;
  final List<GrowthPoint> points;

  const _MetricTile({required this.metric, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = points.isNotEmpty ? points.last : null;
    final prev = points.length >= 2 ? points[points.length - 2] : null;
    final delta = (last != null && prev != null) ? last.value - prev.value : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EventType.growth.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 18, color: EventType.growth.color),
          const SizedBox(height: 8),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              last != null ? '${formatMeasure(last.value)} ${metric.unit}' : '—',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            delta == null
                ? ' '
                : '${delta >= 0 ? '+' : '−'}${formatMeasure(delta.abs())} ${metric.unit}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: delta == null || delta >= 0 ? Colors.green.shade600 : scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Curiosidades
// ---------------------------------------------------------------------------

String _zodiac(DateTime d) {
  const signs = [
    (1, 20, '♑ Capricornio'), (2, 19, '♒ Acuario'), (3, 21, '♓ Piscis'),
    (4, 20, '♈ Aries'), (5, 21, '♉ Tauro'), (6, 21, '♊ Géminis'),
    (7, 23, '♋ Cáncer'), (8, 23, '♌ Leo'), (9, 23, '♍ Virgo'),
    (10, 23, '♎ Libra'), (11, 22, '♏ Escorpio'), (12, 22, '♐ Sagitario'),
  ];
  // Cada entrada indica el último día del signo que empezó en el mes anterior.
  final (month, lastDay, sign) = signs[d.month - 1];
  if (d.day < lastDay) return sign;
  return signs[month % 12].$3;
}

class _FunFacts extends StatelessWidget {
  final DateTime dob;
  final List<GrowthPoint> weights;

  const _FunFacts({required this.dob, required this.weights});

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final days = _daysBetween(dob, today);
    final hours = DateTime.now().difference(dob).inHours;
    final fmt = NumberFormat.decimalPattern('es');

    const roundDays = [100, 200, 365, 500, 730, 1000, 1500, 2000];
    final nextRound = roundDays.where((d) => d > days).firstOrNull;

    final facts = <Widget>[
      _InfoTile(
        icon: Icons.calendar_month_outlined,
        title: 'Nació un ${DateFormat('EEEE', 'es').format(dob)}',
        subtitle: 'Signo del zodiaco: ${_zodiac(dob)}',
      ),
      _InfoTile(
        icon: Icons.hourglass_bottom_rounded,
        title: '${fmt.format(hours)} horas de vida',
        subtitle: 'Unos ${fmt.format(hours * 60)} minutos descubriendo el mundo',
      ),
      if (nextRound != null)
        _InfoTile(
          icon: Icons.celebration_outlined,
          title: 'Cumplirá $nextRound días el ${DateFormat("d 'de' MMMM", 'es').format(dob.add(Duration(days: nextRound)))}',
          subtitle: 'Faltan ${nextRound - days} días',
        ),
    ];

    if (weights.length >= 2) {
      final first = weights.first;
      final last = weights.last;
      final gainedKg = last.value - first.value;
      final weeks = _daysBetween(first.date, last.date) / 7;
      final perWeek = weeks > 0 ? (gainedKg * 1000 / weeks).round() : null;

      facts.add(
        _InfoTile(
          icon: Icons.trending_up_rounded,
          title: '${gainedKg >= 0 ? 'Ha ganado' : 'Ha perdido'} ${formatMeasure(gainedKg.abs())} kg',
          subtitle: 'Desde el ${DateFormat('d MMM y', 'es').format(first.date)}'
              '${perWeek != null ? ' · ≈ $perWeek g/semana' : ''}',
        ),
      );
    }

    return Column(children: facts);
  }
}

// ---------------------------------------------------------------------------
// Comunes
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 20) : null,
      ),
    );
  }
}
