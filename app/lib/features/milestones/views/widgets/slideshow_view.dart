import 'dart:async';
import 'package:app/shared/models/milestone.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideshowView extends StatefulWidget {
  final List<Milestone> milestones;
  final DateTime babyDob;

  const SlideshowView({
    super.key,
    required this.milestones,
    required this.babyDob,
  });

  @override
  State<SlideshowView> createState() => _SlideshowViewState();
}

class _SlideshowViewState extends State<SlideshowView>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _fadeCtrl;
  Timer? _timer;
  int _current = 0;
  bool _playing = true;

  static const _duration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    _startTimer();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_duration, (_) {
      if (!_playing) return;
      _advance();
    });
  }

  void _advance() {
    if (!mounted) return;
    final next = (_current + 1) % widget.milestones.length;
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() => _playing = !_playing);
    if (_playing) _startTimer();
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${d.day} de ${m[d.month - 1]} de ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Slides ─────────────────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.milestones.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final m = widget.milestones[i];
              return _Slide(
                milestone: m,
                babyDob: widget.babyDob,
                fmtDate: _fmtDate,
              );
            },
          ),

          // ── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Progress indicators
                    Expanded(
                      child: Row(
                        children: List.generate(
                          widget.milestones.length,
                          (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 3),
                              height: 2,
                              decoration: BoxDecoration(
                                color: i <= _current
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.30),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom: play/pause + nav ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleBtn(
                      icon: Icons.skip_previous_rounded,
                      onTap: () {
                        if (_current > 0) {
                          _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 20),
                    _CircleBtn(
                      icon: _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 56,
                      iconSize: 28,
                      onTap: _togglePlay,
                    ),
                    const SizedBox(width: 20),
                    _CircleBtn(icon: Icons.skip_next_rounded, onTap: _advance),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final Milestone milestone;
  final DateTime babyDob;
  final String Function(DateTime) fmtDate;

  const _Slide({
    required this.milestone,
    required this.babyDob,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final cat = catFor(milestone.category);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto de fondo
        if (milestone.mediaUrl != null)
          CachedNetworkImage(imageUrl: milestone.mediaUrl!, fit: BoxFit.cover)
        else
          Container(
            color: const Color(0xFF1A1D2E),
            child: Center(
              child: Text(
                milestone.emoji ?? cat.emoji,
                style: const TextStyle(fontSize: 100),
              ),
            ),
          ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.20),
                Colors.black.withOpacity(0.75),
              ],
              stops: const [0.40, 0.65, 1.0],
            ),
          ),
        ),

        // Polaroid centrado
        Center(
          child: Transform.rotate(
            angle: milestone.rotation,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.40),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (milestone.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: milestone.mediaUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      color: const Color(0xFFF0EDF8),
                      child: Center(
                        child: Text(
                          milestone.emoji ?? cat.emoji,
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                    child: Text(
                      milestone.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Info abajo
        Positioned(
          left: 24,
          right: 24,
          bottom: 110,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cat.emoji} ${cat.label}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                milestone.ageLabel(babyDob),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fmtDate(milestone.date),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
