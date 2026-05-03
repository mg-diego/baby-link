import 'package:app/core/network/api_service.dart';
import 'package:app/features/analytics/views/stats_screen.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/views/event_logger_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

import '../../events/views/home_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> baby;

  const MainScreen({super.key, required this.baby});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int currentSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _syncActiveEvents());
  }

  Future<void> _syncActiveEvents() async {
    final activeEvents = await ApiService.getActiveEvents(widget.baby["id"]);
    for (var event in activeEvents) {
      final category = event['category'];
      final eventId = event['id'].toString();
      final startTime = DateTime.parse(event['start_time']).toLocal();
      if (category == 'nap') {
        ref.read(activeNapProvider.notifier).start(eventId, startTime);
      } else if (category == 'night_waking') {
        ref.read(activeNightWakingProvider.notifier).start(eventId, startTime);
      } else if (category == 'feed' &&
          event['metadata']?['type'] == 'nursing') {
        ref.read(activeNursingProvider.notifier).start(eventId, startTime);
      } else if (category == 'pumping') {
        ref.read(activePumpingProvider.notifier).start(eventId, startTime);
      }
    }
  }

  void _onNavTap(int index) {
    if (index == 1) {
      HapticFeedback.mediumImpact();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) =>
            EventLoggerSheet(babyId: widget.baby["id"].toString()),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => currentSelectedIndex = index);
  }

  Widget _buildBody(String babyId) {
    if (currentSelectedIndex == 0) return HomeScreen(babyId: babyId);
    if (currentSelectedIndex == 2) return StatsScreen(babyId: babyId);
    return HomeScreen(babyId: babyId);
  }

  @override
  Widget build(BuildContext context) {
    final String babyId = widget.baby["id"].toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // el body se extiende bajo la navbar
      body: _buildBody(babyId),
      bottomNavigationBar: _CustomNavBar(
        selectedIndex: currentSelectedIndex,
        isDark: isDark,
        onTap: _onNavTap,
      ),
    );
  }
}

// ─── Custom nav bar ────────────────────────────────────────────────────────────

class _CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _CustomNavBar({
    required this.selectedIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1D2E).withOpacity(0.92)
                    : Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.70),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF0F1222).withOpacity(0.60)
                        : const Color(0xFF4A90D9).withOpacity(0.10),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ── Home ──────────────────────────────────────────────────
                  Expanded(
                    child: _NavItem(
                      svgData: homeIcon,
                      label: 'Inicio',
                      isSelected: selectedIndex == 0,
                      isDark: isDark,
                      onTap: () => onTap(0),
                    ),
                  ),

                  // ── Add (central) ─────────────────────────────────────────
                  _CenterAddButton(onTap: () => onTap(1)),

                  // ── Stats ─────────────────────────────────────────────────
                  Expanded(
                    child: _NavItem(
                      svgData: statsIcon,
                      label: 'Stats',
                      isSelected: selectedIndex == 2,
                      isDark: isDark,
                      onTap: () => onTap(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String svgData;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.svgData,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? const Color(0xFF7BB8F0) : const Color(0xFF4A90D9);
    final inactiveColor =
        isDark ? const Color(0xFF4A5068) : const Color(0xFFB0BEC5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(isDark ? 0.15 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SvgPicture.string(
                svgData,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  isSelected ? activeColor : inactiveColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CenterAddButton({required this.onTap});

  @override
  State<_CenterAddButton> createState() => _CenterAddButtonState();
}

class _CenterAddButtonState extends State<_CenterAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6EB0F5), Color(0xFF4A90D9)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90D9).withOpacity(0.45),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF4A90D9).withOpacity(0.20),
                  blurRadius: 32,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

const homeIcon =
    '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path fill-rule="evenodd" clip-rule="evenodd" d="M21.4498 10.275L11.9998 3.1875L2.5498 10.275L2.9998 11.625H3.7498V20.25H20.2498V11.625H20.9998L21.4498 10.275ZM5.2498 18.75V10.125L11.9998 5.0625L18.7498 10.125V18.75H14.9999V14.3333L14.2499 13.5833H9.74988L8.99988 14.3333V18.75H5.2498ZM10.4999 18.75H13.4999V15.0833H10.4999V18.75Z" fill="#080341"></path> </g></svg>''';

const addIcon =
    '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <circle opacity="0.5" cx="12" cy="12" r="10" stroke="#1C274C" stroke-width="1.5"></circle> <path d="M15 12L12 12M12 12L9 12M12 12L12 9M12 12L12 15" stroke="#1C274C" stroke-width="1.5" stroke-linecap="round"></path> </g></svg>''';

const statsIcon =
    '''<svg fill="#000000" width="181px" height="181px" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"><path d="M1.75 13.25V1.5H.5v12a1.24 1.24 0 0 0 1.22 1H15.5v-1.25z"></path><path d="M3.15 8H4.4v3.9H3.15zm3.26-4h1.26v7.9H6.41zm3.27 2h1.25v5.9H9.68zm3.27-3.5h1.25v9.4h-1.25z"></path></g></svg>''';