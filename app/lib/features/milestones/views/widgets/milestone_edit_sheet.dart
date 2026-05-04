import 'dart:io';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/milestone_service.dart';

class MilestoneEditSheet extends StatefulWidget {
  final Milestone milestone;
  final String babyId;
  final DateTime babyDob;
  final void Function(Milestone) onUpdated;

  const MilestoneEditSheet({
    super.key,
    required this.milestone,
    required this.babyId,
    required this.babyDob,
    required this.onUpdated,
  });

  @override
  State<MilestoneEditSheet> createState() => _MilestoneEditSheetState();
}

class _MilestoneEditSheetState extends State<MilestoneEditSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _date;
  late String _category;
  File? _newMedia;
  bool _loading = false;
  final _picker = ImagePicker();
  final _service = MilestoneService();

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

  String _ageLabel() {
    int months = (_date.year - widget.babyDob.year) * 12 +
        _date.month - widget.babyDob.month;
    int days = _date.day - widget.babyDob.day;
    if (days < 0) { months--; days += 30; }
    if (months <= 0) return '$days días';
    if (months < 12) return months == 1 ? '1 mes' : '$months meses';
    final y = months ~/ 12, m = months % 12;
    if (m == 0) return y == 1 ? '1 año' : '$y años';
    return '${y == 1 ? '1 año' : '$y años'} y ${m == 1 ? '1 mes' : '$m meses'}';
  }

  String _fmtDate(DateTime d) {
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _pickImage() async {
    final xf = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (xf != null) setState(() => _newMedia = File(xf.path));
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final updated = await _service.update(
        id: widget.milestone.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        date: _date,
        category: _category,
        newMediaFile: _newMedia,
        existingMediaUrl: widget.milestone.mediaUrl,
        mediaType: _newMedia != null ? 'image' : widget.milestone.mediaType,
        emoji: catFor(_category).emoji,
      );
      widget.onUpdated(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

    final previewImage = _newMedia != null
        ? DecorationImage(image: FileImage(_newMedia!), fit: BoxFit.cover)
        : (widget.milestone.mediaUrl != null
            ? DecorationImage(
                image: NetworkImage(widget.milestone.mediaUrl!),
                fit: BoxFit.cover)
            : null);

    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Editar recuerdo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPri)),
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
                      color: const Color(0xFF4A90D9).withOpacity(0.25)),
                  ),
                  child: previewImage == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: const Color(0xFF4A90D9), size: 28),
                              const SizedBox(height: 6),
                              Text('Añadir foto',
                                  style: TextStyle(
                                      color: const Color(0xFF4A90D9),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text('Cambiar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri),
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
                      horizontal: 14, vertical: 12),
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
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Fecha
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: widget.babyDob,
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9).withOpacity(isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF4A90D9).withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Color(0xFF4A90D9), size: 18),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmtDate(_date),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A90D9))),
                          Text('Tenía ${_ageLabel()}',
                              style: TextStyle(fontSize: 11, color: textSec)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_rounded,
                          size: 14, color: Color(0xFF4A90D9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Categorías
              Text('Categoría',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: textSec)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
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
                          horizontal: 12, vertical: 7),
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
                                  color: const Color(0xFF4A90D9).withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Text('${cat.emoji} ${cat.label}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : textSec)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar cambios',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}