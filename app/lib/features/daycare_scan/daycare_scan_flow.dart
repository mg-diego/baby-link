import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/network/api_service.dart';
import 'package:app/core/utils/time_utils.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/services/event_action_service.dart';
import 'package:app/shared/models/event_type.dart';

import 'daycare_sheet_parser.dart';
import 'daycare_sheet_scanner.dart';

/// Escanear la hoja diaria de la guardería: foto (cámara o galería) → OCR en
/// el móvil → revisión de las siestas encontradas → guardado.
///
/// Las siestas se proponen siempre para hoy; el día se puede cambiar en la
/// revisión. Nada se guarda sin que el usuario lo confirme.
///
/// Tras abrir la cámara, el widget que lanzó esto puede haber desaparecido (al
/// volver a la app se recargan datos y se reconstruye la pantalla), así que
/// después del primer `await` todo se cuelga del navegador raíz, que no se
/// desmonta, en vez de del `context` del botón.
Future<void> launchDaycareScan(BuildContext context, String babyId) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Haz una foto de la hoja de la guardería y apuntaré las siestas que aparezcan.',
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Hacer una foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;

  final XFile? picked;
  await _setPending(true);
  try {
    // Resolución de sobra para el OCR sin cargar una foto de 12 Mpx en memoria.
    picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
  } catch (e) {
    developer.log('Error al elegir la foto: $e', name: 'DaycareScan');
    final reason = source == ImageSource.camera
        ? 'No se pudo abrir la cámara. Revisa que la app tenga permiso.'
        : 'No se pudo abrir la galería.';
    _snack(messenger, reason);
    return;
  } finally {
    await _setPending(false);
  }
  if (picked == null) return;

  await _processPhoto(navigator, messenger, babyId, picked.path);
}

/// Android puede cerrar la app mientras la cámara está abierta (poca memoria).
/// Al volver, la foto no llega a `pickImage` sino a `retrieveLostData`: si el
/// escaneo estaba a medias, se retoma. Se llama al abrir Inicio.
Future<void> recoverLostDaycareScan(BuildContext context, String babyId) async {
  if (!Platform.isAndroid || !await _isPending()) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  await _setPending(false);

  final LostDataResponse response;
  try {
    response = await ImagePicker().retrieveLostData();
  } catch (e) {
    developer.log('Error recuperando la foto: $e', name: 'DaycareScan');
    return;
  }
  if (response.isEmpty) return;
  final file = response.file;
  if (file == null) {
    _snack(messenger, 'No se pudo recuperar la foto. Prueba otra vez.');
    return;
  }
  await _processPhoto(navigator, messenger, babyId, file.path);
}

const _pendingKey = 'daycare_scan_pending';

Future<void> _setPending(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    value ? await prefs.setBool(_pendingKey, true) : await prefs.remove(_pendingKey);
  } catch (_) {}
}

Future<bool> _isPending() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_pendingKey) ?? false;
  } catch (_) {
    return false;
  }
}

void _snack(ScaffoldMessengerState messenger, String text) {
  if (messenger.mounted) messenger.showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _processPhoto(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  String babyId,
  String path,
) async {
  if (!navigator.mounted) return;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  var dialogOpen = true;
  showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 20),
            Expanded(child: Text('Leyendo la hoja…')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  List<ScannedNap>? naps;
  try {
    naps = await DaycareSheetScanner.scanNaps(path, today);
  } catch (e) {
    developer.log('Error en el OCR: $e', name: 'DaycareScan');
    _snack(messenger, 'No se pudo leer la foto: $e');
  } finally {
    if (dialogOpen && navigator.mounted) navigator.pop();
  }
  if (naps == null || !navigator.mounted) return;

  final found = naps;
  await showModalBottomSheet<void>(
    context: navigator.context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DaycareScanReviewSheet(babyId: babyId, initialDay: today, naps: found),
  );
}

class _Row {
  ScannedNap nap;

  /// null = sin tocar: se marca sola salvo que pise una siesta ya registrada.
  bool? selected;

  _Row(this.nap, {this.selected});

  bool get isValid => nap.end.isAfter(nap.start);
}

class DaycareScanReviewSheet extends ConsumerStatefulWidget {
  final String babyId;
  final DateTime initialDay;
  final List<ScannedNap> naps;

  const DaycareScanReviewSheet({
    super.key,
    required this.babyId,
    required this.initialDay,
    required this.naps,
  });

  @override
  ConsumerState<DaycareScanReviewSheet> createState() => _DaycareScanReviewSheetState();
}

class _DaycareScanReviewSheetState extends ConsumerState<DaycareScanReviewSheet> {
  late DateTime _day = widget.initialDay;
  late final List<_Row> _rows = widget.naps.map(_Row.new).toList();
  bool _saving = false;

  String get _dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_day == today) return 'Hoy';
    if (_day == today.subtract(const Duration(days: 1))) return 'Ayer';
    return '${_day.day}/${_day.month}/${_day.year}';
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      for (final r in _rows) {
        r.nap = moveNapToDay(r.nap, _day);
      }
    });
  }

  Future<void> _pickTime(_Row row, {required bool isStart}) async {
    final current = isStart ? row.nap.start : row.nap.end;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (picked == null) return;
    final t = DateTime(_day.year, _day.month, _day.day, picked.hour, picked.minute);
    setState(() {
      row.nap = ScannedNap(
        start: isStart ? t : row.nap.start,
        end: isStart ? row.nap.end : t,
        source: row.nap.source,
      );
    });
  }

  void _addManual() {
    setState(() {
      _rows.add(_Row(
        ScannedNap(
          start: DateTime(_day.year, _day.month, _day.day, 12),
          end: DateTime(_day.year, _day.month, _day.day, 13),
          source: '',
        ),
        selected: true,
      ));
    });
  }

  Future<void> _save(List<_Row> toSave) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    var saved = 0;
    try {
      for (final row in toSave) {
        await ApiService.registerEvent(
          widget.babyId,
          EventType.nap.backendCategory,
          {'source': 'daycare_scan'},
          startTime: row.nap.start,
          endTime: row.nap.end,
        );
        saved++;
        _rows.remove(row);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(saved == 0 ? 'Error al guardar: $e' : 'Guardadas $saved; error en la siguiente: $e'),
      ));
    } finally {
      if (saved > 0) ref.read(eventActionProvider).refreshLists(widget.babyId);
      if (mounted) setState(() => _saving = false);
    }

    if (saved == toSave.length && mounted) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(saved == 1 ? 'Siesta registrada' : '$saved siestas registradas'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = EventType.nap.getAccentColor(context);
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final size = MediaQuery.sizeOf(context);

    final eventsAsync = ref.watch(dailyEventsProvider((babyId: widget.babyId, date: _day)));
    final existing = eventsAsync.asData?.value ?? const [];

    bool overlaps(_Row r) => overlapsExistingNap(r.nap, existing);
    bool isSelected(_Row r) => r.selected ?? !overlaps(r);

    final toSave = _rows.where(isSelected).toList();
    final canSave = !_saving &&
        !eventsAsync.isLoading &&
        toSave.isNotEmpty &&
        toSave.every((r) => r.isValid);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.document_scanner_outlined, color: accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Siestas de la guardería',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(_dayLabel),
                    onPressed: _saving ? null : _pickDay,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No he encontrado ninguna hora en la foto. Prueba con otra foto más '
                    'cerca y sin reflejos, o añade la siesta a mano.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.4),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NapTile(
                      row: _rows[i],
                      selected: isSelected(_rows[i]),
                      overlaps: overlaps(_rows[i]),
                      accent: accent,
                      enabled: !_saving,
                      onSelected: (v) => setState(() => _rows[i].selected = v),
                      onPickStart: () => _pickTime(_rows[i], isStart: true),
                      onPickEnd: () => _pickTime(_rows[i], isStart: false),
                      onRemove: () => setState(() => _rows.removeAt(i)),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _saving ? null : _addManual,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir siesta a mano'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: canSave ? () => _save(toSave) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(
                        toSave.length <= 1 ? 'Guardar siesta' : 'Guardar ${toSave.length} siestas',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NapTile extends StatelessWidget {
  final _Row row;
  final bool selected;
  final bool overlaps;
  final Color accent;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  const _NapTile({
    required this.row,
    required this.selected,
    required this.overlaps,
    required this.accent,
    required this.enabled,
    required this.onSelected,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final nap = row.nap;

    Widget timeButton(DateTime t, VoidCallback onTap) => InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              TimeUtils.formatTimeOnly(t),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
        );

    final notes = <Widget>[
      if (!row.isValid)
        Text('El fin no puede ser anterior al inicio', style: TextStyle(fontSize: 12, color: scheme.error))
      else
        Text(TimeUtils.formatDuration(nap.duration), style: TextStyle(fontSize: 12, color: muted)),
      if (nap.source.isNotEmpty)
        Text('Leído: "${nap.source}"', style: TextStyle(fontSize: 12, color: muted)),
      if (overlaps)
        Text(
          'Ya hay una siesta registrada a esa hora',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? accent.withValues(alpha: 0.5) : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: enabled ? (v) => onSelected(v ?? false) : null),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    timeButton(nap.start, onPickStart),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–', style: TextStyle(color: muted)),
                    ),
                    timeButton(nap.end, onPickEnd),
                  ],
                ),
                const SizedBox(height: 4),
                ...notes,
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: enabled ? onRemove : null,
            icon: Icon(Icons.close_rounded, color: muted),
          ),
        ],
      ),
    );
  }
}
