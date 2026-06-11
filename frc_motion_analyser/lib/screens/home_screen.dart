import 'package:flutter/material.dart';

import '../data/clients_repository.dart';
import '../models/client_summary.dart';
import '../theme/tokens.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/start_assessment_card.dart';
import '../widgets/today_clients_card.dart';
import '../widgets/weekly_stats_row.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Thursday · 11 Jun".
String formatEyebrowDate(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return '$weekday · ${date.day} $month';
}

/// 早晨 (morning) / 午安 (afternoon) / 夜晚好 (evening) greeting.
String greetingForHour(int hour) {
  if (hour < 12) return '早晨';
  if (hour < 18) return '午安';
  return '夜晚好';
}

/// Screen 01 — Home (DESIGN SPEC.md §3).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository = const MockClientsRepository(),
    this.userName = 'Ani',
  });

  final ClientsRepository repository;
  final String userName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DateTime _now = DateTime.now();
  AppTab _tab = AppTab.home;

  late final Future<List<ClientSummary>> _clients =
      widget.repository.todaysClients();
  late final Future<WeeklyStats> _stats = widget.repository.weeklyStats();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: AppSpacing.tabBarHeight + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatEyebrowDate(_now),
                  style: AppText.data(
                    size: 10,
                    color: AppColors.muted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${greetingForHour(_now.hour)}，${widget.userName}',
                  style: AppText.display(size: 24),
                ),
                StartAssessmentCard(onSelectClient: () {}),
                const _SectionHeader(title: '今日客戶', action: '全部 →'),
                FutureBuilder<List<ClientSummary>>(
                  future: _clients,
                  builder: (context, snapshot) {
                    final clients = snapshot.data ?? const [];
                    return TodayClientsCard(
                      clients: clients,
                      now: _now,
                      onAddClient: () {},
                      onSelectClient: (client) {},
                    );
                  },
                ),
                const _SectionHeader(title: '本週數據'),
                FutureBuilder<WeeklyStats>(
                  future: _stats,
                  builder: (context, snapshot) {
                    final stats = snapshot.data ??
                        const WeeklyStats(
                          assessmentCount: 0,
                          avgAromGainDeg: 0,
                        );
                    return WeeklyStatsRow(stats: stats);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onTap: (tab) => setState(() => _tab = tab),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: AppText.display(size: 15, weight: FontWeight.w600)),
          if (action != null)
            Text(action!, style: AppText.data(size: 11, color: AppColors.orange)),
        ],
      ),
    );
  }
}
