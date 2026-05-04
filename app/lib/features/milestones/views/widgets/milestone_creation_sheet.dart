import 'dart:io';
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/milestone_service.dart';

class MilestoneCreationSheet extends StatefulWidget {
  final String babyId;
  final DateTime babyDob;
  final void Function(Milestone) onCreated;

  const MilestoneCreationSheet({
    super.key,
    required this.babyId,
    required this.babyDob,
    required this.onCreated,
  });

  @override
  State<MilestoneCreationSheet> createState() => _MilestoneCreationSheetState();
}

class _MilestoneCreationSheetState extends State<MilestoneCreationSheet> {
  final _pageCtrl = PageController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _service = MilestoneService();

  File? _mediaFile;
  String _mediaType = 'none';
  DateTime _date = DateTime.now();
  String _category = 'physical';
  bool _loading = false;
  int _step = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
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

  Future<void> _pickImage() async {
    final xf = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (xf != null) {
      setState(() {
        _mediaFile = File(xf.path);
        _mediaType = 'image';
      });
      _nextStep();
    }
  }

  Future<void> _pickVideo() async {
    final xf = await _picker.pickVideo(source: ImageSource.gallery);
    if (xf != null) {
      setState(() {
        _mediaFile = File(xf.path);
        _mediaType = 'video';
      });
      _nextStep();
    }
  }

  void _skipMedia() {
    setState(() { _mediaFile = null; _mediaType = 'none'; });
    _nextStep();
  }

  void _nextStep() {
    setState(() => _step++);
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final m = await _service.create(
        babyId: widget.babyId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        date: _date,
        category: _category,
        mediaFile: _mediaFile,
        mediaType: _mediaType,
        emoji: catFor(_category).emoji,
      );
      widget.onCreated(m);
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
    final surfColor =
        isDark ? const Color(0xFF1A1D2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    _step == 0 ? 'Elige el media' : 'Completa el recuerdo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE8EAF6) : const Color(0xFF2D3142),
                    ),
                  ),
                  const Spacer(),
                  _StepDots(current: _step, total: 2, isDark: isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 460,
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1Media(
                    isDark: isDark,
                    onPickImage: _pickImage,
                    onPickVideo: _pickVideo,
                    onSkip: _skipMedia,
                  ),
                  _Step2Details(
                    isDark: isDark,
                    mediaFile: _mediaFile,
                    mediaType: _mediaType,
                    titleCtrl: _titleCtrl,
                    descCtrl: _descCtrl,
                    date: _date,
                    ageLabel: _ageLabel(),
                    category: _category,
                    loading: _loading,
                    onDateTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: widget.babyDob,
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    onCategoryChanged: (c) => setState(() => _category = c),
                    onSave: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Media picker ──────────────────────────────────────────────────────

class _Step1Media extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPickImage, onPickVideo, onSkip;

  const _Step1Media({
    required this.isDark,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _MediaOption(
            icon: Icons.photo_rounded,
            label: 'Foto',
            subtitle: 'JPG, PNG, HEIC',
            color: const Color(0xFF4A90D9),
            isDark: isDark,
            onTap: onPickImage,
          ),
          const SizedBox(height: 12),
          _MediaOption(
            icon: Icons.videocam_rounded,
            label: 'Vídeo',
            subtitle: 'Máximo 60 segundos',
            color: const Color(0xFF7F77DD),
            isDark: isDark,
            onTap: onPickVideo,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Continuar sin media',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.40)
                    : Colors.black.withOpacity(0.35),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.30 : 0.20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFE8EAF6)
                            : const Color(0xFF2D3142))),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.45)
                            : Colors.black.withOpacity(0.40))),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Details ───────────────────────────────────────────────────────────

class _Step2Details extends StatelessWidget {
  final bool isDark;
  final File? mediaFile;
  final String mediaType;
  final TextEditingController titleCtrl, descCtrl;
  final DateTime date;
  final String ageLabel, category;
  final bool loading;
  final VoidCallback onDateTap, onSave;
  final ValueChanged<String> onCategoryChanged;

  const _Step2Details({
    required this.isDark,
    required this.mediaFile,
    required this.mediaType,
    required this.titleCtrl,
    required this.descCtrl,
    required this.date,
    required this.ageLabel,
    required this.category,
    required this.loading,
    required this.onDateTap,
    required this.onSave,
    required this.onCategoryChanged,
  });

  String _fmtDate(DateTime d) {
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textPri = isDark ? const Color(0xFFE8EAF6) : const Color(0xFF2D3142);
    final textSec = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.black.withOpacity(0.40);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview polaroid mini
          if (mediaFile != null)
            Center(
              child: Container(
                width: 100, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        child: Image.file(mediaFile!, fit: BoxFit.cover,
                            width: double.infinity),
                      ),
                    ),
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      child: Text(
                        titleCtrl.text.isEmpty ? '...' : titleCtrl.text,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Título
          TextField(
            controller: titleCtrl,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPri),
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
            controller: descCtrl,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: textPri),
            decoration: InputDecoration(
              hintText: 'Añade una nota (opcional)',
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

          // Fecha + edad
          GestureDetector(
            onTap: onDateTap,
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
                      Text(_fmtDate(date),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A90D9))),
                      Text('Tenía $ageLabel',
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textSec)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kMilestoneCategories.map((cat) {
              final selected = category == cat.key;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onCategoryChanged(cat.key);
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar recuerdo',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current, total;
  final bool isDark;
  const _StepDots({required this.current, required this.total, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4A90D9)
                : (isDark
                    ? Colors.white.withOpacity(0.20)
                    : Colors.black.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}