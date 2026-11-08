import 'dart:io';
import 'package:app/shared/models/milestone.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/milestones_provider.dart';
import '../../services/media_metadata.dart';
import '../../services/media_picker.dart';
import '../../services/milestone_service.dart';
import 'save_progress_button.dart';

class MilestoneEditSheet extends ConsumerStatefulWidget {
  final Milestone milestone;
  final DateTime? babyDob;

  const MilestoneEditSheet({
    super.key,
    required this.milestone,
    required this.babyDob,
  });

  @override
  ConsumerState<MilestoneEditSheet> createState() => _MilestoneEditSheetState();
}

class _MilestoneEditSheetState extends ConsumerState<MilestoneEditSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _date;
  late String _category;
  File? _newMedia;

  /// La fecha actual se ha tomado de los metadatos de la foto nueva.
  bool _dateFromMedia = false;
  bool _loading = false;
  UploadProgress? _progress;
  final _picker = MediaPicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.milestone.title);
    _descCtrl = TextEditingController(text: widget.milestone.description ?? '');
    _date = widget.milestone.date;
    _category = widget.milestone.category;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _ageLabel() {
    final dob = widget.babyDob;
    return dob != null ? formatBabyAge(dob, _date) : null;
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  // Se comprime al subir (ver MediaCompressor).
  Future<void> _pickImage() async {
    final picked = await _picker.pick('image');
    if (picked == null) return;
    final file = picked.file;
    final check = checkCaptureDate(await picked.captureDate(), widget.babyDob);
    if (!mounted) return;
    final captured = check is ValidCaptureDate ? check.date : null;
    setState(() {
      _newMedia = file;
      if (captured != null) _date = captured;
      _dateFromMedia = captured != null;
    });
    if (check is OutOfRangeCaptureDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outOfRangeMessage(check, 'image'))),
      );
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _progress = null;
    });
    try {
      final original = widget.milestone;
      await ref
          .read(milestonesProvider(original.babyId).notifier)
          .edit(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
            original,
            MilestoneInput(
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              date: _date,
              category: _category,
              mediaFile: _newMedia,
              mediaType: _newMedia != null ? 'image' : original.mediaType,
              emoji: catFor(_category).emoji,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el recuerdo')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfColor = isDark ? const Color(0xFF1A1D2E) : Colors.white;
    final textPri = isDark ? const Color(0xFFE8EAF6) : const Color(0xFF2D3142);
    final textSec = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.black.withOpacity(0.40);

    // Foto nueva, foto actual o fotograma de portada si es un vídeo.
    final currentUrl = widget.milestone.previewImageUrl;
    final previewImage = _newMedia != null
        ? DecorationImage(image: FileImage(_newMedia!), fit: BoxFit.cover)
        : currentUrl != null
        ? DecorationImage(
            image: CachedNetworkImageProvider(currentUrl),
            fit: BoxFit.cover,
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Editar recuerdo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPri,
                ),
              ),
              const SizedBox(height: 20),

              // Preview foto + cambiar
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    image: previewImage,
                    border: Border.all(
                      color: const Color(0xFF4A90D9).withOpacity(0.25),
                    ),
                  ),
                  child: previewImage == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                color: const Color(0xFF4A90D9),
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Añadir foto',
                                style: TextStyle(
                                  color: const Color(0xFF4A90D9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Cambiar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Título
              TextField(
                controller: _titleCtrl,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
                decoration: InputDecoration(
                  hintText: 'Nombre del hito',
                  hintStyle: TextStyle(color: textSec),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Descripción
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: textPri),
                decoration: InputDecoration(
                  hintText: 'Nota (opcional)',
                  hintStyle: TextStyle(color: textSec),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Fecha
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: widget.babyDob ?? DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(() {
                      _date = d;
                      _dateFromMedia = false;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF4A90D9,
                    ).withOpacity(isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4A90D9).withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF4A90D9),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmtDate(_date),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A90D9),
                            ),
                          ),
                          if (_ageLabel() case final age?)
                            Text(
                              'Tenía $age',
                              style: TextStyle(fontSize: 11, color: textSec),
                            ),
                          if (_dateFromMedia)
                            Text(
                              'Fecha leída de la foto',
                              style: TextStyle(fontSize: 11, color: textSec),
                            ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: Color(0xFF4A90D9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Categorías
              Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textSec,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kMilestoneCategories.map((cat) {
                  final selected = _category == cat.key;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _category = cat.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4A90D9)
                            : (isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04)),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4A90D9,
                                  ).withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        '${cat.emoji} ${cat.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : textSec,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Guardar
              SaveProgressButton(
                label: 'Guardar cambios',
                busy: _loading,
                progress: _progress,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
