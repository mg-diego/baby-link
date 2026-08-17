import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app/shared/models/event_type.dart';
import 'biological_action_button.dart';

class BiologicalActionBar extends StatelessWidget {
  final bool isNightMode;
  final bool isNapActive;
  final bool isWakingActive;
  final bool isLoading;
  final DateTime? Function(EventType) getLastTimeFor;
  final Function(EventType) onTriggerAction;

  const BiologicalActionBar({
    super.key,
    required this.isNightMode,
    required this.isNapActive,
    required this.isWakingActive,
    required this.isLoading,
    required this.getLastTimeFor,
    required this.onTriggerAction,
  });

  List<Widget> _buildActionButtons() {
    Widget btn(EventType type, {bool isDisabled = false}) => BiologicalActionButton(
          eventType: type,
          isNight: isNightMode,
          isDisabled: isDisabled,
          lastEventTime: getLastTimeFor(type),
          isLoading: isLoading,
          onTap: () => onTriggerAction(type),
        );

    final divider = _divider(isNightMode);

    if (isNightMode) {
      return [
        btn(EventType.bottle),
        divider,
        btn(EventType.nursing),
        divider,
        btn(EventType.diaper),
        divider,
        btn(EventType.nightWaking, isDisabled: isWakingActive),
        divider,
        btn(EventType.wokeUp, isDisabled: isWakingActive),
      ];
    }

    return [
      btn(EventType.bottle),
      divider,
      btn(EventType.solids),
      divider,
      btn(EventType.diaper),
      divider,
      btn(EventType.nap, isDisabled: isNapActive),
      divider,
      btn(EventType.bedtime, isDisabled: isNapActive),
    ];
  }

  Widget _divider(bool isNightMode) {
    return Container(
      width: 1,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            isNightMode
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFF2D3142).withOpacity(0.06),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.015,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isNightMode
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E2235).withOpacity(0.70),
                        const Color(0xFF141625).withOpacity(0.85),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.40),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
              border: Border.all(
                color: isNightMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.35),
                width: 0.5,
              ),
              boxShadow: isNightMode
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0A0D1A).withOpacity(0.50),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF546E7A).withOpacity(0.06),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildActionButtons(),
            ),
          ),
        ),
      ),
    );
  }
}