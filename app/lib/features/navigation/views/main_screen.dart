import 'package:app/core/network/api_service.dart';
import 'package:app/features/analytics/views/stats_screen.dart';
import 'package:app/features/events/providers/events_provider.dart';
import 'package:app/features/events/views/event_logger_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../events/views/home_screen.dart';

const Color inActiveIconColor = Color(0xFFB6B6B6);

class MainScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> baby;
  
  const MainScreen({super.key, required this.baby});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {

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
      } 
      else if (category == 'night_waking') {
        ref.read(activeNightWakingProvider.notifier).start(eventId, startTime);
      }
      else if (category == 'feed' && event['metadata']?['type'] == 'breast') {
        ref.read(activeBreastfeedingProvider.notifier).start(eventId, startTime);
      }
      else if (category == 'pumping') {
        ref.read(activePumpingProvider.notifier).start(eventId, startTime);
      }
    }
  }
  
  int currentSelectedIndex = 0;

  void updateCurrentIndex(int index) {
    if (index == 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => EventLoggerSheet(babyId: widget.baby["id"].toString()),
      );
      return;
    }
    setState(() {
      currentSelectedIndex = index;
    });
  }

  Widget _buildBody(String babyId) {
    if (currentSelectedIndex == 0) return HomeScreen(babyId: babyId);
    if (currentSelectedIndex == 2) return StatsScreen(babyId: babyId);
    return HomeScreen(babyId: babyId);
  }

  @override
  Widget build(BuildContext context) {
    final String babyId = widget.baby["id"].toString();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _buildBody(babyId),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: updateCurrentIndex,
        currentIndex: currentSelectedIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: const Color(0xFFFF7643),
        unselectedItemColor: inActiveIconColor,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.string(
              homeIcon,
              colorFilter: const ColorFilter.mode(inActiveIconColor, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.string(
              homeIcon,
              colorFilter: const ColorFilter.mode(Color(0xFFFF7643), BlendMode.srcIn),
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.string(
              addIcon,
              colorFilter: const ColorFilter.mode(inActiveIconColor, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.string(
              addIcon,
              colorFilter: const ColorFilter.mode(Color(0xFFFF7643), BlendMode.srcIn),
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.string(
              statsIcon,
              colorFilter: const ColorFilter.mode(inActiveIconColor, BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.string(
              statsIcon,
              colorFilter: const ColorFilter.mode(Color(0xFFFF7643), BlendMode.srcIn),
            ),
            label: "",
          ),
        ],
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