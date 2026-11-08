import 'dart:io';
import 'package:app/core/network/storage_utils.dart';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'media_compressor.dart';
import 'upload_progress.dart';

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

  const MilestoneInput({
    required this.title,
    this.description,
    required this.date,
    required this.category,
    this.emoji,
    this.mediaFile,
    this.mediaType = 'none',
  });
}

class MilestoneService {
  static const _table = 'milestones';
  static const _bucket = 'milestones';

  final SupabaseClient _db;
  final MediaCompressor _compressor;

  MilestoneService([SupabaseClient? client, MediaCompressor? compressor])
    : _db = client ?? Supabase.instance.client,
      _compressor = compressor ?? const MediaCompressor();

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
    final mediaUrl = input.mediaFile != null
        ? await _upload(babyId, input.mediaFile!, input.mediaType, onProgress)
        : null;

    onProgress?.call(const UploadProgress(UploadPhase.saving));

    try {
      final row = await _db
          .from(_table)
          .insert({
            'baby_id': babyId,
            ..._fields(input),
            'media_url': mediaUrl,
            'media_type': mediaUrl != null ? input.mediaType : 'none',
            'metadata': const <String, dynamic>{},
          })
          .select()
          .single();
      return Milestone.fromJson(row);
    } catch (_) {
      await _removeMedia(mediaUrl); // no dejar huérfana la subida
      rethrow;
    }
  }

  Future<Milestone> update(
    Milestone original,
    MilestoneInput input, {
    UploadProgressCallback? onProgress,
  }) async {
    final newMediaUrl = input.mediaFile != null
        ? await _upload(
            original.babyId,
            input.mediaFile!,
            input.mediaType,
            onProgress,
          )
        : null;

    onProgress?.call(const UploadProgress(UploadPhase.saving));

    final Map<String, dynamic> row;
    try {
      row = await _db
          .from(_table)
          .update({
            ..._fields(input),
            'media_url': ?newMediaUrl,
            'media_type': input.mediaType,
          })
          .eq('id', original.id)
          .select()
          .single();
    } catch (_) {
      await _removeMedia(newMediaUrl);
      rethrow;
    }

    // La foto anterior ya no la referencia nadie.
    if (newMediaUrl != null) await _removeMedia(original.mediaUrl);
    return Milestone.fromJson(row);
  }

  /// Borra el hito y, después, su foto/vídeo de Storage.
  Future<void> delete(Milestone milestone) async {
    await _db.from(_table).delete().eq('id', milestone.id);
    await _removeMedia(milestone.mediaUrl);
  }

  Map<String, dynamic> _fields(MilestoneInput input) => {
    'title': input.title,
    'description': input.description,
    'date': _formatDate(input.date),
    'category': input.category,
    'emoji': input.emoji,
  };

  /// Comprime el fichero (ver [MediaCompressor]) y lo sube a Storage.
  Future<String> _upload(
    String babyId,
    File file,
    String mediaType,
    UploadProgressCallback? onProgress,
  ) async {
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
      final ext = p.extension(toUpload.path).toLowerCase();
      final path = '$babyId/${DateTime.now().millisecondsSinceEpoch}$ext';
      await _db.storage
          .from(_bucket)
          .upload(
            path,
            toUpload,
            // Los ficheros nunca se sobrescriben (nombre único), así que
            // pueden cachearse un año en CDN y en el móvil.
            fileOptions: const FileOptions(cacheControl: '31536000'),
          );
      return _db.storage.from(_bucket).getPublicUrl(path);
    } finally {
      if (toUpload.path != file.path) {
        toUpload.delete().catchError((Object e) {
          debugPrint('No se pudo borrar el temporal comprimido: $e');
          return toUpload;
        });
      }
    }
  }

  Future<void> _removeMedia(String? url) =>
      removePublicStorageFile(_db, _bucket, url);

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
