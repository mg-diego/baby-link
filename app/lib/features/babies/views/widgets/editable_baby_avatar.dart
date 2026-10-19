import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/features/babies/providers/baby_provider.dart';
import 'package:app/features/babies/services/baby_photo_service.dart';
import 'package:app/features/babies/views/widgets/baby_avatar.dart';

enum _PhotoAction { gallery, camera, remove }

/// Avatar del bebé que al pulsarlo permite elegir, hacer o eliminar la foto.
class EditableBabyAvatar extends ConsumerStatefulWidget {
  final String babyId;
  final String name;
  final String? photoUrl;
  final double size;

  const EditableBabyAvatar({
    super.key,
    required this.babyId,
    required this.name,
    required this.photoUrl,
    this.size = 72,
  });

  @override
  ConsumerState<EditableBabyAvatar> createState() => _EditableBabyAvatarState();
}

class _EditableBabyAvatarState extends ConsumerState<EditableBabyAvatar> {
  final _picker = ImagePicker();
  final _service = BabyPhotoService();
  bool _uploading = false;

  Future<void> _onTap() async {
    if (_uploading) return;
    final hasPhoto = widget.photoUrl?.isNotEmpty ?? false;

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                title: Text('Eliminar foto', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    try {
      if (action == _PhotoAction.remove) {
        setState(() => _uploading = true);
        await _service.remove(widget.babyId, widget.photoUrl);
      } else {
        final picked = await _picker.pickImage(
          source: action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked == null) return;

        setState(() => _uploading = true);
        await _service.upload(widget.babyId, File(picked.path), previousUrl: widget.photoUrl);
      }

      ref.invalidate(babyProvider);
      await ref.read(babyProvider.future);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          children: [
            BabyAvatar(
              photoUrl: widget.photoUrl,
              size: widget.size,
              backgroundColor: scheme.primary,
              fallback: Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: widget.size * 0.42, fontWeight: FontWeight.bold, color: scheme.onPrimary),
              ),
            ),
            if (_uploading)
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primaryContainer, width: 2),
                ),
                child: Icon(Icons.photo_camera_rounded, size: 14, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
