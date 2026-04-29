import 'package:flutter/material.dart';
import 'package:app/core/models/event_type.dart';

class EventGridButton extends StatelessWidget {
  final EventType eventType;
  final bool isActive;
  final VoidCallback onTap;

  const EventGridButton({
    super.key,
    required this.eventType,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = eventType.accentColor;
    final Color activeAccent = Colors.red.shade400;

    final Color bgColor = isActive ? activeAccent.withOpacity(0.08) : accent.withOpacity(0.08);
    final Color borderColor = isActive ? activeAccent.withOpacity(0.5) : accent.withOpacity(0.25);
    final Color iconColor = isActive ? activeAccent : accent;
    final Color textColor = isActive ? activeAccent : Theme.of(context).colorScheme.onSurface;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.stop_circle_outlined : eventType.icon,
                  size: 17,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isActive ? 'Detener' : eventType.uiLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) _PulseDot(color: activeAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_anim.value),
        ),
      ),
    );
  }
}