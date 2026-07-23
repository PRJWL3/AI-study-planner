import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_session.dart';
import 'persistence_service.dart';

class ScheduleService {
  static final ScheduleService instance = ScheduleService._();
  ScheduleService._();

  bool hasOverlap(String start1, String end1, String start2, String end2) {
    if (start1.isEmpty || end1.isEmpty || start2.isEmpty || end2.isEmpty) return false;
    final t1Start = _parseTimeToMinutes(start1);
    final t1End = _parseTimeToMinutes(end1);
    final t2Start = _parseTimeToMinutes(start2);
    final t2End = _parseTimeToMinutes(end2);
    return t1Start < t2End && t2Start < t1End;
  }

  int _parseTimeToMinutes(String timeStr) {
    final cleanTime = timeStr.replaceAll(RegExp(r'[a-zA-Z\s]'), ''); // Remove PM/AM if any
    final parts = cleanTime.split(':');
    if (parts.length < 2) return 0;
    int hr = int.tryParse(parts[0]) ?? 0;
    final min = int.tryParse(parts[1]) ?? 0;
    
    // Support 12h formats if PM/AM was parsed (optional fallback)
    if (timeStr.toLowerCase().contains('pm') && hr < 12) hr += 12;
    if (timeStr.toLowerCase().contains('am') && hr == 12) hr = 0;
    
    return hr * 60 + min;
  }

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
