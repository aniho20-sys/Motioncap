import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/session_recording.dart';

/// Persists [SessionRecording]s — DESIGN SPEC.md §4 功能需求 "存Firestore".
///
/// [LocalSessionStorage] is the current implementation (device-local JSON).
/// A Firestore-backed implementation can be added once Ani sets up the
/// Firebase project (CLAUDE.md "之後"), without changing [LiveScreen].
abstract class SessionStorage {
  /// Persists [recording] and returns a path/identifier for user feedback.
  Future<String> save(SessionRecording recording);
}

class LocalSessionStorage implements SessionStorage {
  const LocalSessionStorage();

  @override
  Future<String> save(SessionRecording recording) async {
    final dir = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory('${dir.path}/sessions');
    await sessionsDir.create(recursive: true);

    final filename = 'session_${recording.startedAt.millisecondsSinceEpoch}.json';
    final file = File('${sessionsDir.path}/$filename');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(recording.toJson()),
    );
    return file.path;
  }
}
