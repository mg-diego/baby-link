import 'package:app/features/milestones/providers/milestones_provider.dart';
import 'package:app/features/milestones/services/milestone_service.dart';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Milestone _m(String id, DateTime date, {String title = 'Hito'}) => Milestone(
  id: id,
  babyId: 'baby',
  title: title,
  date: date,
  category: 'physical',
  createdAt: DateTime(2026),
);

Milestone _video(String id, DateTime date, {String? thumb}) => Milestone(
  id: id,
  babyId: 'baby',
  title: 'Vídeo',
  date: date,
  category: 'physical',
  mediaUrl: 'https://x/$id.mp4',
  mediaType: 'video',
  metadata: {Milestone.thumbnailKey: ?thumb},
  createdAt: DateTime(2026),
);

class _FakeService implements MilestoneService {
  List<Milestone> rows;
  bool failDelete = false;
  _FakeService(this.rows);

  @override
  Future<List<Milestone>> fetchAll(String babyId) async => [...rows];

  @override
  Future<Milestone> create(
    String babyId,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async => _m('new', input.date, title: input.title);

  @override
  Future<Milestone> update(
    Milestone original,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async => _m(original.id, input.date, title: input.title);

  /// Hitos a los que se les pidió miniatura.
  final thumbnailCalls = <String>[];

  @override
  Future<Milestone> ensureThumbnail(Milestone m) async {
    thumbnailCalls.add(m.id);
    return _video(m.id, m.date, thumb: 'https://x/${m.id}_thumb.jpg');
  }

  @override
  Future<void> delete(Milestone milestone) async {
    if (failDelete) throw Exception('network');
  }
}

void main() {
  group('formatBabyAge', () {
    final dob = DateTime(2026, 1, 31);

    test('días antes del primer mes', () {
      expect(formatBabyAge(dob, DateTime(2026, 1, 31)), '0 días');
      expect(formatBabyAge(dob, DateTime(2026, 2, 1)), '1 día');
      expect(formatBabyAge(dob, DateTime(2026, 2, 28)), '28 días');
    });

    test('meses completos', () {
      expect(formatBabyAge(dob, DateTime(2026, 3, 31)), '2 meses');
      expect(formatBabyAge(dob, DateTime(2026, 3, 30)), '1 mes');
    });

    test('años y meses', () {
      expect(formatBabyAge(dob, DateTime(2027, 1, 31)), '1 año');
      expect(formatBabyAge(dob, DateTime(2028, 3, 31)), '2 años y 2 meses');
    });

    test('fecha anterior al nacimiento no da negativos', () {
      expect(formatBabyAge(dob, DateTime(2026, 1, 1)), '0 días');
    });
  });

  group('MilestonesNotifier', () {
    late _FakeService service;
    late ProviderContainer container;
    final provider = milestonesProvider('baby');

    setUp(() {
      service = _FakeService([
        _m('a', DateTime(2026, 2, 1)),
        _m('b', DateTime(2026, 4, 1)),
      ]);
      container = ProviderContainer(
        overrides: [milestoneServiceProvider.overrideWithValue(service)],
      );
    });

    tearDown(() => container.dispose());

    List<String> ids() =>
        container.read(provider).requireValue.map((m) => m.id).toList();

    test('crear inserta en orden cronológico', () async {
      await container.read(provider.future);
      await container
          .read(provider.notifier)
          .create(
            MilestoneInput(
              title: 'Nuevo',
              date: DateTime(2026, 3, 1),
              category: 'physical',
            ),
          );
      expect(ids(), ['a', 'new', 'b']);
    });

    test('editar reordena si cambia la fecha', () async {
      await container.read(provider.future);
      final a = container.read(provider).requireValue.first;
      await container
          .read(provider.notifier)
          .edit(
            a,
            MilestoneInput(
              title: 'A',
              date: DateTime(2026, 5, 1),
              category: 'physical',
            ),
          );
      expect(ids(), ['b', 'a']);
    });

    test('borrar es optimista y se revierte si falla', () async {
      await container.read(provider.future);
      service.failDelete = true;

      final future = container.read(provider.notifier).delete('a');
      expect(ids(), ['b']);

      await expectLater(future, throwsException);
      expect(ids(), ['a', 'b']);
    });
  });

  group('miniaturas de vídeo', () {
    test('previewImageUrl: foto → su URL, vídeo → fotograma', () {
      final photo = Milestone(
        id: 'p',
        babyId: 'baby',
        title: 'Foto',
        date: DateTime(2025, 2, 1),
        category: 'physical',
        mediaUrl: 'https://x/p.jpg',
        mediaType: 'image',
        createdAt: DateTime(2026),
      );
      expect(photo.previewImageUrl, 'https://x/p.jpg');
      expect(photo.thumbnailUrl, isNull);

      expect(_video('v', DateTime(2025)).previewImageUrl, isNull);
      expect(
        _video('v', DateTime(2025), thumb: 'https://x/t.jpg').previewImageUrl,
        'https://x/t.jpg',
      );
    });

    test('al cargar genera las que faltan, una vez por vídeo', () async {
      final service = _FakeService([
        _m('foto', DateTime(2025, 2, 1)),
        _video('sin', DateTime(2025, 3, 1)),
        _video('con', DateTime(2025, 4, 1), thumb: 'https://x/con.jpg'),
      ]);
      final container = ProviderContainer(
        overrides: [milestoneServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final provider = milestonesProvider('baby');

      await container.read(provider.future);
      await pumpEventQueue();

      expect(service.thumbnailCalls, ['sin']);
      final sin = container
          .read(provider)
          .requireValue
          .firstWhere((m) => m.id == 'sin');
      expect(sin.thumbnailUrl, 'https://x/sin_thumb.jpg');

      // Recargar no vuelve a intentarlo en la misma sesión.
      container.invalidate(provider);
      await container.read(provider.future);
      await pumpEventQueue();
      expect(service.thumbnailCalls, ['sin']);
    });
  });
}
