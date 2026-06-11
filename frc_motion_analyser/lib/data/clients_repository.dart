import '../models/client_summary.dart';

/// Provides "今日客戶" / "本週數據" data for Screen 01 — Home.
///
/// [MockClientsRepository] is the current implementation. DESIGN SPEC.md §3
/// 功能需求 calls for a Firestore-backed implementation (sorted by today's
/// schedule) — that will be added as a second implementation of this
/// interface once Firebase is wired up, without changing Screen 01's UI.
abstract class ClientsRepository {
  /// Today's scheduled clients, sorted by [ClientSummary.scheduledFor].
  Future<List<ClientSummary>> todaysClients();

  Future<WeeklyStats> weeklyStats();
}

class MockClientsRepository implements ClientsRepository {
  const MockClientsRepository();

  @override
  Future<List<ClientSummary>> todaysClients() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final clients = [
      ClientSummary(
        id: 'marcus-lee',
        name: 'Marcus Lee',
        age: 52,
        focus: '髖關節重點',
        weekNumber: 6,
        scheduledFor: today.add(const Duration(hours: 9)),
        lastFullAssessmentDate: now.subtract(const Duration(days: 14)),
        worstJoint: const JointHighlight(
          label: 'HIP ER',
          arom: 62,
          prom: 67,
          previousDeficit: 5,
        ),
      ),
      ClientSummary(
        id: 'sarah-wong',
        name: 'Sarah Wong',
        age: 47,
        focus: '肩胛控制',
        weekNumber: 3,
        scheduledFor: today.add(const Duration(hours: 11, minutes: 30)),
        lastFullAssessmentDate: now.subtract(const Duration(days: 7)),
        worstJoint: const JointHighlight(
          label: 'SH FLEX',
          arom: 168,
          prom: 172,
          previousDeficit: 8,
        ),
      ),
      ClientSummary(
        id: 'david-kwan',
        name: 'David Kwan',
        age: 58,
        focus: '腰椎活動度',
        weekNumber: 9,
        scheduledFor: today.add(const Duration(hours: 14)),
        lastFullAssessmentDate: now.subtract(const Duration(days: 60)),
        worstJoint: const JointHighlight(
          label: 'TSPINE ROT',
          arom: 30,
          prom: 38,
          previousDeficit: 4,
        ),
      ),
    ];

    clients.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return clients;
  }

  @override
  Future<WeeklyStats> weeklyStats() async {
    return const WeeklyStats(assessmentCount: 14, avgAromGainDeg: 4.2);
  }
}
