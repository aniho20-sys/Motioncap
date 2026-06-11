import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frc_motion_analyser/data/clients_repository.dart';
import 'package:frc_motion_analyser/models/client_summary.dart';
import 'package:frc_motion_analyser/screens/home_screen.dart';

class _FakeClientsRepository implements ClientsRepository {
  const _FakeClientsRepository(this._clients, this._stats);

  final List<ClientSummary> _clients;
  final WeeklyStats _stats;

  @override
  Future<List<ClientSummary>> todaysClients() async => _clients;

  @override
  Future<WeeklyStats> weeklyStats() async => _stats;
}

void main() {
  const stats = WeeklyStats(assessmentCount: 14, avgAromGainDeg: 4.2);

  testWidgets('shows empty state inviting the first client when none today',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: const _FakeClientsRepository([], stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日未有預約客戶'), findsOneWidget);
    expect(find.text('+ 新增客戶'), findsOneWidget);
  });

  testWidgets('renders today\'s clients with retest-due override',
      (tester) async {
    final now = DateTime.now();
    final clients = [
      ClientSummary(
        id: 'on-track',
        name: 'Marcus Lee',
        age: 52,
        focus: '髖關節重點',
        weekNumber: 6,
        scheduledFor: now,
        lastFullAssessmentDate: now.subtract(const Duration(days: 14)),
        worstJoint: const JointHighlight(
          label: 'HIP ER',
          arom: 62,
          prom: 67,
          previousDeficit: 5,
        ),
      ),
      ClientSummary(
        id: 'due',
        name: 'David Kwan',
        age: 58,
        focus: '腰椎活動度',
        weekNumber: 9,
        scheduledFor: now.add(const Duration(hours: 1)),
        lastFullAssessmentDate: now.subtract(const Duration(days: 60)),
        worstJoint: const JointHighlight(
          label: 'TSPINE ROT',
          arom: 30,
          prom: 38,
          previousDeficit: 4,
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: _FakeClientsRepository(clients, stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcus Lee'), findsOneWidget);
    expect(find.text('62°'), findsOneWidget);
    expect(find.text('HIP ER'), findsOneWidget);

    expect(find.text('David Kwan'), findsOneWidget);
    expect(find.text('58 · 8週重評到期'), findsOneWidget);
    expect(find.text('RE-TEST'), findsOneWidget);
    expect(find.text('DUE'), findsOneWidget);
  });
}
