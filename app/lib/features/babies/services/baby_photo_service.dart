import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:app/core/network/api_service.dart';

/// Sube la foto de perfil del bebé al storage y guarda su URL en `babies.photo_url`.
class BabyPhotoService {
  static const _bucket = 'milestones';
  final _db = Supabase.instance.client;

  Future<String> upload(String babyId, File file, {String? previousUrl}) async {
    // Nombre único: así la URL cambia y la caché de imágenes no muestra la antigua.
    final path = '$babyId/avatar/${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
    await _db.storage.from(_bucket).upload(path, file);
    final url = _db.storage.from(_bucket).getPublicUrl(path);

    try {
      await ApiService.updateBaby(babyId, {'photo_url': url});
    } catch (_) {
      await _deleteFromStorage(url);
      rethrow;
    }
    await _deleteFromStorage(previousUrl);
    return url;
  }

  Future<void> remove(String babyId, String? currentUrl) async {
    await ApiService.updateBaby(babyId, {'photo_url': null});
    await _deleteFromStorage(currentUrl);
  }

  /// Borrado "best effort": si falla, la foto vieja solo ocupa espacio.
  Future<void> _deleteFromStorage(String? publicUrl) async {
    if (publicUrl == null) return;
    final marker = '/object/public/$_bucket/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return;
    try {
      await _db.storage.from(_bucket).remove([publicUrl.substring(idx + marker.length)]);
    } catch (_) {}
  }
}
