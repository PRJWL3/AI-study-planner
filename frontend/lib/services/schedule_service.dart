import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_session.dart';
import 'persistence_service.dart';

class ScheduleService {
  static final ScheduleService instance = ScheduleService._();
  ScheduleService._();

  Box get _box => PersistenceService.instance.getBox('study_sessions');

  List<StudySession> getSessions() {
    final List<dynamic>? list = _box.get('sessions') as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => StudySession.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> saveSessions(List<StudySession> sessions) async {
    await _box.put('sessions', sessions.map((s) => s.toJson()).toList());
  }

  Future<void> toggleSessionCompletion(String id, bool completed) async {
    final List<StudySession> sessions = getSessions();
    final updated = sessions.map((s) {
      if (s.id == id) {
        return StudySession(
          id: s.id,
          subject: s.subject,
          chapter: s.chapter,
          topic: s.topic,
          startTime: s.startTime,
          endTime: s.endTime,
          durationMinutes: s.durationMinutes,
          difficulty: s.difficulty,
          isBreak: s.isBreak,
          isCompleted: completed,
        );
      }
      return s;
    }).toList();
    await saveSessions(updated);
  }
}
