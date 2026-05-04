import 'package:app/core/network/api_service.dart';
import 'package:app/features/analytics/views/stats_screen.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/views/event_logger_sheet.dart';
import 'package:app/features/milestones/views/milestones_screen.dart';
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
    if (index == 2) {
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
    if (currentSelectedIndex == 1) return StatsScreen(babyId: babyId);    
    if (currentSelectedIndex == 3) return MilestonesScreen(babyId: babyId);
    if (currentSelectedIndex == 4) return StatsScreen(babyId: babyId);
    return HomeScreen(babyId: babyId);
  }

  @override
  Widget build(BuildContext context) {
    final String babyId = widget.baby["id"].toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
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

                  // ── Stats ─────────────────────────────────────────────────
                  Expanded(
                    child: _NavItem(
                      svgData: learnIcon,
                      label: 'Aprendizaje',
                      isSelected: selectedIndex == 1,
                      isDark: isDark,
                      onTap: () => onTap(1),
                    ),
                  ),

                  // ── Add (central) ─────────────────────────────────────────
                  _CenterAddButton(onTap: () => onTap(2)),

                   // ── Stats ─────────────────────────────────────────────────
                  Expanded(
                    child: _NavItem(
                      svgData: milestoneIcon,
                      label: 'Recuerdos',
                      isSelected: selectedIndex == 3,
                      isDark: isDark,
                      onTap: () => onTap(3),
                    ),
                  ),

                  // ── Stats ─────────────────────────────────────────────────
                  Expanded(
                    child: _NavItem(
                      svgData: statsIcon,
                      label: 'Stats',
                      isSelected: selectedIndex == 4,
                      isDark: isDark,
                      onTap: () => onTap(4),
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

const learnIcon =
    '''<svg version="1.1" id="Icons" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 32 32" xml:space="preserve" fill="#000000"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <style type="text/css"> .st0{fill:none;stroke:#000000;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;stroke-miterlimit:10;} </style> <line class="st0" x1="23" y1="24" x2="23" y2="29"></line> <path class="st0" d="M10,21V10c0-1.7-1.3-3-3-3H1v11h6C8.7,18,10,19.3,10,21L10,21"></path> <path class="st0" d="M10,21V10c0-1.7,1.3-3,3-3h6v11h-6C11.3,18,10,19.3,10,21L10,21"></path> <path class="st0" d="M12.2,18.1c0.3,0.3,0.5,0.6,0.8,0.9v8"></path> <path class="st0" d="M22,24h4c1.1,0,2-0.9,2-2v-4h3l-3-6c0-5-4-9-9-9c-3.4,0-6.4,1.9-7.9,4.7"></path> </g></svg>''';

const addIcon =
    '''<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <circle opacity="0.5" cx="12" cy="12" r="10" stroke="#1C274C" stroke-width="1.5"></circle> <path d="M15 12L12 12M12 12L9 12M12 12L12 9M12 12L12 15" stroke="#1C274C" stroke-width="1.5" stroke-linecap="round"></path> </g></svg>''';

const milestoneIcon = 
    '''<svg viewBox="0 -0.5 17 17" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" class="si-glyph si-glyph-picture" fill="#000000"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <title>661</title> <defs> </defs> <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"> <g transform="translate(1.000000, 1.000000)" fill="#434343"> <path d="M13.842,4 L9.912,1.15 C9.755,0.491 9.166,0 8.458,0 C7.717,0 7.106,0.537 6.984,1.243 L2.918,4 L0.0209999999,4 L0.0209999999,13.96 L15.959,13.96 L15.959,4 L13.842,4 L13.842,4 Z M8.458,3 C9.014,3 9.492,2.695 9.752,2.247 L11.8945312,4.00000002 L5.04663086,4.00000002 L7.213,2.336 C7.483,2.736 7.94,3 8.458,3 Z M11.9605786,10.0845944 L8.719654,11.7576284 L4.99291992,7.03894043 L1,13 L1,5 L15,5 L15,13 L11.9605786,10.0845944 Z" class="si-glyph-fill"> </path> <circle cx="12.963" cy="6.963" r="0.963" class="si-glyph-fill"> </circle> </g> </g> </g></svg>''';

const statsIcon =
    '''<svg fill="#000000" width="181px" height="181px" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"><path d="M1.75 13.25V1.5H.5v12a1.24 1.24 0 0 0 1.22 1H15.5v-1.25z"></path><path d="M3.15 8H4.4v3.9H3.15zm3.26-4h1.26v7.9H6.41zm3.27 2h1.25v5.9H9.68zm3.27-3.5h1.25v9.4h-1.25z"></path></g></svg>''';