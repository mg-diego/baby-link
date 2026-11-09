/// Extrae las siestas de la hoja diaria de la guardería a partir del texto que
/// devuelve el OCR.
///
/// En la hoja, lo único con forma de rango de horas son las siestas, así que da
/// igual en qué fila estén: se busca cualquier "HH:MM - HH:MM" y se ignora el
/// resto ("Tot / Tot x2", títulos de las filas...).
///
/// La letra es a mano, así que se toleran los fallos típicos del OCR: `:` leído
/// como `.`, `,`, `h` o perdido (`1220-1415`), guion largo o "a", y letras que
/// parecen dígitos (`l2:2O`). A cambio la validación es estricta: es mejor no
/// proponer nada que proponer una hora mal leída.
library;

class ScannedNap {
  final DateTime start;
  final DateTime end;

  /// Texto tal como lo leyó el OCR, para mostrarlo en la revisión.
  final String source;

  const ScannedNap({required this.start, required this.end, required this.source});

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is ScannedNap && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ScannedNap($start → $end, "$source")';
}

const minNapDuration = Duration(minutes: 10);
const maxNapDuration = Duration(hours: 4);

/// Letras que el OCR confunde con dígitos. Solo se sustituyen junto a un dígito,
/// para no tocar palabras ("Tot" sigue siendo "Tot").
const _digitLookalikes = {
  'O': '0', 'o': '0', 'D': '0', 'Q': '0',
  'l': '1', 'I': '1', 'i': '1', '|': '1', '!': '1',
  'Z': '2', 'z': '2',
  'S': '5', 's': '5',
  'B': '8',
  'g': '9', 'q': '9',
};

bool _isDigit(String? c) => c != null && c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

String _fixDigitLookalikes(String text) {
  final chars = text.split('');
  final out = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    final c = chars[i];
    final replacement = _digitLookalikes[c];
    final prev = i > 0 ? chars[i - 1] : null;
    final next = i + 1 < chars.length ? chars[i + 1] : null;
    out.write(replacement != null && (_isDigit(prev) || _isDigit(next)) ? replacement : c);
  }
  return out.toString();
}

// Hora: 1-2 dígitos, separador opcional y 2 dígitos de minutos.
const _time = r'(\d{1,2})\s?([:.,;h\x27’])?\s?(\d{2})';
// Entre las dos horas: guion (de cualquier tipo), "a"/"al" o solo espacio.
final _range = RegExp(
  '(?<!\\d)$_time(\\s*[-‐‑‒–—―~_=>]+\\s*|\\s+al?\\s+|\\s+)$_time(?!\\d)',
);

/// Pasa la hora a 24 h. En la guardería no se duerme de madrugada: una hora de
/// 1 a 6 es de la tarde escrita en formato de 12 h ("2:15" son las 14:15).
int? _hour24(int h) {
  if (h > 23) return null;
  if (h >= 1 && h <= 6) return h + 12;
  return h;
}

List<ScannedNap> parseNapRanges(String text, DateTime day) {
  // Las líneas del OCR se unen: un rango puede venir partido en dos.
  final normalized = _fixDigitLookalikes(text.replaceAll(RegExp(r'\s+'), ' '));
  final date = DateTime(day.year, day.month, day.day);
  final found = <ScannedNap>{};

  for (final m in _range.allMatches(normalized)) {
    final startSep = m.group(2);
    final joiner = m.group(4)!;
    final endSep = m.group(6);
    // Sin guion ni separadores ("1220 1415") podría ser cualquier número: solo
    // se acepta un rango sin guion si las dos horas llevan separador.
    if (joiner.trim().isEmpty && (startSep == null || endSep == null)) continue;

    final sh = _hour24(int.parse(m.group(1)!));
    final sm = int.parse(m.group(3)!);
    final eh = _hour24(int.parse(m.group(5)!));
    final em = int.parse(m.group(7)!);
    if (sh == null || eh == null || sm > 59 || em > 59) continue;

    final start = date.add(Duration(hours: sh, minutes: sm));
    final end = date.add(Duration(hours: eh, minutes: em));
    final duration = end.difference(start);
    if (duration < minNapDuration || duration > maxNapDuration) continue;

    found.add(ScannedNap(start: start, end: end, source: m.group(0)!.trim()));
  }

  return found.toList()..sort((a, b) => a.start.compareTo(b.start));
}

/// Mueve las horas de una siesta a otro día, conservando la hora del reloj.
ScannedNap moveNapToDay(ScannedNap nap, DateTime day) {
  DateTime onDay(DateTime t) => DateTime(day.year, day.month, day.day, t.hour, t.minute);
  return ScannedNap(start: onDay(nap.start), end: onDay(nap.end), source: nap.source);
}

/// Si la siesta pisa alguna de las ya registradas ese día (`events` en el
/// formato de la API). Una siesta en curso cuenta hasta ahora.
bool overlapsExistingNap(ScannedNap nap, List<dynamic> events, {DateTime? now}) {
  for (final e in events) {
    if (e is! Map || e['category'] != 'nap') continue;
    final start = DateTime.tryParse(e['start_time']?.toString() ?? '')?.toLocal();
    if (start == null) continue;
    final endRaw = e['end_time'];
    final end = endRaw == null
        ? (now ?? DateTime.now())
        : DateTime.tryParse(endRaw.toString())?.toLocal() ?? start;
    if (start.isBefore(nap.end) && end.isAfter(nap.start)) return true;
  }
  return false;
}
