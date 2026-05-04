import 'dart:io';
import 'package:app/shared/models/milestone.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class MilestoneService {
  final _db = Supabase.instance.client;

  Future<List<Milestone>> fetchAll(String babyId) async {
    final data = await _db
        .from('milestones')
        .select()
        .eq('baby_id', babyId)
        .order('date', ascending: true)
        .order('created_at', ascending: true);
    return (data as List).map((e) => Milestone.fromJson(e)).toList();
  }

  Future<Milestone> create({
    required String babyId,
    required String title,
    String? description,
    required DateTime date,
    required String category,
    String? subcategory,
    File? mediaFile,
    String mediaType = 'none',
    String? emoji,
    Map<String, dynamic> metadata = const {},
  }) async {
    String? mediaUrl;

    if (mediaFile != null) {
      final ext = p.extension(mediaFile.path);
      final path = '$babyId/${DateTime.now().millisecondsSinceEpoch}$ext';
      await _db.storage.from('milestones').upload(path, mediaFile);
      mediaUrl = _db.storage.from('milestones').getPublicUrl(path);
    }

    final row = await _db
        .from('milestones')
        .insert({
          'baby_id': babyId,
          'title': title,
          'description': description,
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'category': category,
          'subcategory': subcategory,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'emoji': emoji,
          'metadata': metadata,
        })
        .select()
        .single();

    return Milestone.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _db.from('milestones').delete().eq('id', id);
  }

  Future<Milestone> update({
    required String id,
    required String title,
    String? description,
    required DateTime date,
    required String category,
    File? newMediaFile,
    String? existingMediaUrl,
    String mediaType = 'none',
    String? emoji,
  }) async {
    String? mediaUrl = existingMediaUrl;

    if (newMediaFile != null) {
      final ext = p.extension(newMediaFile.path);
      final path = '${DateTime.now().millisecondsSinceEpoch}$ext';
      await _db.storage.from('milestones').upload(path, newMediaFile);
      mediaUrl = _db.storage.from('milestones').getPublicUrl(path);
    }

    final row = await _db
        .from('milestones')
        .update({
          'title': title,
          'description': description,
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'category': category,
          if (mediaUrl != null) 'media_url': mediaUrl,
          'media_type': mediaType,
          'emoji': emoji,
        })
        .eq('id', id)
        .select()
        .single();

    return Milestone.fromJson(row);
  }
}
