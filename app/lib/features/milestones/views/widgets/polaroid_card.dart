import 'dart:math' as math;
import 'package:app/shared/models/milestone.dart';
import 'package:flutter/material.dart';

class PolaroidCard extends StatefulWidget {
  final Milestone milestone;
  final DateTime babyDob;
  final bool isLeft;

  const PolaroidCard({
    super.key,
    required this.milestone,
    required this.babyDob,
    required this.isLeft,
  });

  @override
  State<PolaroidCard> createState() => _PolaroidCardState();
}

class _PolaroidCardState extends State<PolaroidCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _anim = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flipped) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rotation = widget.milestone.rotation;

    return Padding(
      padding: EdgeInsets.only(
        left: widget.isLeft ? 8 : 16,
        right: widget.isLeft ? 16 : 8,
        top: 12,
        bottom: 12,
      ),
      child: Transform.rotate(
        angle: rotation,
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final angle = _anim.value;
              final showBack = angle > math.pi / 2;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(angle),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _Back(
                          milestone: widget.milestone,
                          babyDob: widget.babyDob,
                          isDark: isDark,
                        ),
                      )
                    : _Front(
                        milestone: widget.milestone,
                        isDark: isDark,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Front ─────────────────────────────────────────────────────────────────────

class _Front extends StatelessWidget {
  final Milestone milestone;
  final bool isDark;

  const _Front({required this.milestone, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.50 : 0.18),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Foto ──────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            child: SizedBox(
              height: 138,
              width: double.infinity,
              child: milestone.mediaUrl != null
                  ? Image.network(
                      milestone.mediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PhotoPlaceholder(
                        emoji: milestone.emoji ?? catFor(milestone.category).emoji,
                      ),
                    )
                  : _PhotoPlaceholder(
                      emoji: milestone.emoji ?? catFor(milestone.category).emoji,
                    ),
            ),
          ),

          // ── Parte blanca (título) ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Text(
              milestone.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PatrickHand', // fallback: sans-serif
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String emoji;
  const _PhotoPlaceholder({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0EDF8),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 48)),
      ),
    );
  }
}

// ─── Back ──────────────────────────────────────────────────────────────────────

class _Back extends StatelessWidget {
  final Milestone milestone;
  final DateTime babyDob;
  final bool isDark;

  const _Back({
    required this.milestone,
    required this.babyDob,
    required this.isDark,
  });

  String _fmtDate(DateTime d) {
    const m = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cat = catFor(milestone.category);
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.50 : 0.18),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categoría
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90D9).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${cat.emoji} ${cat.label}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A90D9),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Título
          Text(
            milestone.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2D2D),
              height: 1.2,
            ),
          ),

          if (milestone.description != null &&
              milestone.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              milestone.description!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
          const SizedBox(height: 10),

          // Fecha
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: Color(0xFF999999)),
              const SizedBox(width: 4),
              Text(
                _fmtDate(milestone.date),
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Edad
          Row(
            children: [
              const Text('👶', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  milestone.ageLabel(babyDob),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4A90D9),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Toca para volver',
              style: TextStyle(fontSize: 9, color: Color(0xFFBBBBBB)),
            ),
          ),
        ],
      ),
    );
  }
}