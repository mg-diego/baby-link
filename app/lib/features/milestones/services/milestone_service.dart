import 'dart:io';
import 'package:app/core/network/storage_utils.dart';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'media_compressor.dart';
import 'upload_progress.dart';
import 'video_thumbnail.dart';

export 'upload_progress.dart';

/// Datos editables de un hito, comunes a creación y edición.
class MilestoneInput {
  final String title;
  final String? description;
  final DateTime date;
  final String category;
  final String? emoji;

  /// Fichero nuevo a subir. En edición, `null` conserva el actual.
  final File? mediaFile;
  final String mediaType;

  /// Fotograma ya extraído para la vista previa (sólo vídeo). Si es `null`,
  /// el servicio lo extrae al subir.
  final File? thumbnailFile;

  const MilestoneInput({
    required this.title,
    this.description,
    required this.date,
    required this.category,
    this.emoji,
    this.mediaFile,
    this.mediaType = 'none',
    this.thumbnailFile,
  });
}

/// URLs públicas de lo subido para un hito.
typedef _UploadedMedia = ({String url, String? thumbnailUrl});

class MilestoneService {
  static const _table = 'milestones';
  static const _bucket = 'milestones';

  final SupabaseClient _db;
  final MediaCompressor _compressor;
  final VideoThumbnailer _thumbnailer;

  MilestoneService([
    SupabaseClient? client,
    MediaCompressor? compressor,
    VideoThumbnailer? thumbnailer,
  ]) : _db = client ?? Supabase.instance.client,
       _compressor = compressor ?? const MediaCompressor(),
       _thumbnailer = thumbnailer ?? const VideoThumbnailer();

  Future<List<Milestone>> fetchAll(String babyId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('baby_id', babyId)
        .order('date', ascending: true)
        .order('created_at', ascending: true);
    return data.map(Milestone.fromJson).toList();
  }

  Future<Milestone> create(
    String babyId,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async {
    final media = input.mediaFile != null
        ? await _uploadMedia(babyId, input, onProgress)
        : null;

    onProgress?.call(const UploadProgress(UploadPhase.saving));

    try {
      final row = await _db
          .from(_table)
          .insert({
            'baby_id': babyId,
            ..._fields(input),
            'media_url': media?.url,
            'media_type': media != null ? input.mediaType : 'none',
            'metadata': {Milestone.thumbnailKey: ?media?.thumbnailUrl},
          })
          .select()
          .single();
      return Milestone.fromJson(row);
    } catch (_) {
      await _removeUploaded(media); // no dejar huérfana la subida
      rethrow;
    }
  }

  Future<Milestone> update(
    Milestone original,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async {
    final media = input.mediaFile != null
        ? await _uploadMedia(original.babyId, input, onProgress)
        : null;

    onProgress?.call(const UploadProgress(UploadPhase.saving));

    // Con media nuevo, la miniatura anterior deja de valer.
    final Map<String, dynamic>? metadata = media == null
        ? null
        : {
            for (final e in original.metadata.entries)
              if (e.key != Milestone.thumbnailKey) e.key: e.value,
            Milestone.thumbnailKey: ?media.thumbnailUrl,
          };

    final Map<String, dynamic> row;
    try {
      row = await _db
          .from(_table)
          .update({
            ..._fields(input),
            'media_url': ?media?.url,
            'media_type': input.mediaType,
            'metadata': ?metadata,
          })
          .eq('id', original.id)
          .select()
          .single();
    } catch (_) {
      await _removeUploaded(media);
      rethrow;
    }

    // La foto/vídeo anterior (y su miniatura) ya no los referencia nadie.
    if (media != null) {
      await _removeMedia(original.mediaUrl);
      await _removeMedia(original.metadata[Milestone.thumbnailKey] as String?);
    }
    return Milestone.fromJson(row);
  }

  /// Borra el hito y, después, su foto/vídeo de Storage.
  Future<void> delete(Milestone milestone) async {
    await _db.from(_table).delete().eq('id', milestone.id);
    await _removeMedia(milestone.mediaUrl);
    await _removeMedia(milestone.metadata[Milestone.thumbnailKey] as String?);
  }

  /// Genera y guarda la miniatura de un vídeo subido antes de que existieran.
  /// Devuelve el hito actualizado, o el mismo si no hacía falta o no se pudo.
  Future<Milestone> ensureThumbnail(Milestone m) async {
    if (!m.isVideo || m.thumbnailUrl != null) return m;
    final frame = await _thumbnailer.frameOf(m.mediaUrl!);
    if (frame == null) return m;
    final url = await _uploadThumbnail(m.babyId, frame);
    if (url == null) return m;
    try {
      final row = await _db
          .from(_table)
          .update({
            'metadata': {...m.metadata, Milestone.thumbnailKey: url},
          })
          .eq('id', m.id)
          .select()
          .single();
      return Milestone.fromJson(row);
    } catch (_) {
      await _removeMedia(url);
      rethrow;
    }
  }

  Map<String, dynamic> _fields(MilestoneInput input) => {
    'title': input.title,
    'description': input.description,
    'date': _formatDate(input.date),
    'category': input.category,
    'emoji': input.emoji,
  };

  /// Sube el media de [input] (comprimido) y, si es vídeo, su miniatura.
  Future<_UploadedMedia> _uploadMedia(
    String babyId,
    MilestoneInput input,
    UploadProgressCallback? onProgress,
  ) async {
    final file = input.mediaFile!;
    final mediaType = input.mediaType;

    // El fotograma se saca del original, antes de comprimir: más nitidez.
    final frame = mediaType == 'video'
        ? input.thumbnailFile ?? await _thumbnailer.frameOf(file.path)
        : null;

    onProgress?.call(
      UploadProgress(UploadPhase.compressing, mediaType: mediaType),
    );
    final toUpload = await _compressor.compress(
      file,
      mediaType,
      onProgress: onProgress == null
          ? null
          : (f) => onProgress(
              UploadProgress(
                UploadPhase.compressing,
                fraction: f,
                mediaType: mediaType,
              ),
            ),
    );
    // supabase-dart no expone el progreso de subida: barra indeterminada.
    onProgress?.call(
      UploadProgress(UploadPhase.uploading, mediaType: mediaType),
    );
    try {
      final url = await _uploadFile(babyId, toUpload);
      final thumb = frame != null
          ? await _uploadThumbnail(
              babyId,
              frame,
              // El de la vista previa es de la UI: lo limpia la caché nativa.
              deleteAfter: input.thumbnailFile == null,
            )
          : null;
      return (url: url, thumbnailUrl: thumb);
    } finally {
      if (toUpload.path != file.path) _deleteTemp(toUpload);
    }
  }

  /// La miniatura es opcional: si falla, el hito se guarda sin ella.
  Future<String?> _uploadThumbnail(
    String babyId,
    File frame, {
    bool deleteAfter = true,
  }) async {
    try {
      return await _uploadFile(babyId, frame, suffix: '_thumb');
    } catch (e) {
      debugPrint('No se pudo subir la miniatura: $e');
      return null;
    } finally {
      if (deleteAfter) _deleteTemp(frame);
    }
  }

  Future<String> _uploadFile(
    String babyId,
    File file, {
    String suffix = '',
  }) async {
    final ext = p.extension(file.path).toLowerCase();
    final path = '$babyId/${DateTime.now().millisecondsSinceEpoch}$suffix$ext';
    await _db.storage
        .from(_bucket)
        .upload(
          path,
          file,
          // Los ficheros nunca se sobrescriben (nombre único), así que
          // pueden cachearse un año en CDN y en el móvil.
          fileOptions: const FileOptions(cacheControl: '31536000'),
        );
    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  void _deleteTemp(File f) {
    f.delete().catchError((Object e) {
      debugPrint('No se pudo borrar el temporal ${f.path}: $e');
      return f;
    });
  }

  Future<void> _removeUploaded(_UploadedMedia? media) async {
    await _removeMedia(media?.url);
    await _removeMedia(media?.thumbnailUrl);
  }

  Future<void> _removeMedia(String? url) =>
      removePublicStorageFile(_db, _bucket, url);

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
