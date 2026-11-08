import 'package:supabase_flutter/supabase_flutter.dart';

/// Borra de Storage el fichero al que apunta una URL pública de [bucket].
///
/// Es "best effort": si la URL no pertenece al bucket o el borrado falla, no
/// lanza; como mucho queda un fichero huérfano ocupando espacio.
Future<void> removePublicStorageFile(
  SupabaseClient db,
  String bucket,
  String? publicUrl,
) async {
  if (publicUrl == null) return;
  final marker = '/object/public/$bucket/';
  final idx = publicUrl.indexOf(marker);
  if (idx == -1) return;
  final path = Uri.decodeComponent(
    publicUrl.substring(idx + marker.length).split('?').first,
  );
  try {
    await db.storage.from(bucket).remove([path]);
  } catch (_) {}
}
