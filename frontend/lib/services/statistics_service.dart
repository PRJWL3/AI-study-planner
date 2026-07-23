import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_statistics.dart';
import 'persistence_service.dart';

class StatisticsService {
  static final StatisticsService instance = StatisticsService._();
  StatisticsService._();

  Box get _box => PersistenceService.instance.getBox('study_statistics');

  int get streakDays => _box.get('streakDays', defaultValue: 14) as int;
  set streakDays(int value) => _box.put('streakDays', value);

  int get todayEnergy => _box.get('todayEnergy', defaultValue: 1860) as int;
  set todayEnergy(int value) => _box.put('todayEnergy', value);

  int get weeklyEnergy => _box.get('weeklyEnergy', defaultValue: 12450) as int;
  set weeklyEnergy(int value) => _box.put('weeklyEnergy', value);

  int get sessionsCompleted => _box.get('sessionsCompleted', defaultValue: 3) as int;
  set sessionsCompleted(int value) => _box.put('sessionsCompleted', value);

  int get sessionsGoal => _box.get('sessionsGoal', defaultValue: 6) as int;
  set sessionsGoal(int value) => _box.put('sessionsGoal', value);

  Map<String, double> getWeeklyProgress() {
    final val = _box.get('weeklyProgress');
    if (val == null) {
      return {"Mon": 0.0, "Tue": 0.0, "Wed": 0.0, "Thu": 0.0, "Fri": 0.0, "Sat": 0.0, "Sun": 0.0};
    }
    return Map<String, double>.from((val as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
  }

  set weeklyProgress(Map<String, double> val) {
    _box.put('weeklyProgress', val);
  }

  /// Builds display statistics from the persisted activity log and schedule.
  /// Values are deliberately calculated on demand so they remain current while
  /// the active timer counts down.
  StudyStatistics calculate({
    required List<String> studyPlan,
    required List<bool> completedTasks,
    required List<Map<String, dynamic>> studyEvents,
    required int plannerHoursPerDay,
    required bool isTimerActive,
    required int timerDurationMinutes,
    required int timerSecondsRemaining,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final weekStart = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dayIndex = date.weekday - 1;

    int todayGoalTotal = 0;
    int todayGoalCompleted = 0;
    int weeklyGoalMinutes = 0;
    int weeklyCompletedMinutes = 0;
    final weeklyHours = <String, double>{
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
    };

    for (var index = 0; index < studyPlan.length; index++) {
      final item = _planItem(studyPlan[index]);
      if (item.isBreak) continue;
      weeklyGoalMinutes += item.minutes;
      if (item.dayIndex == dayIndex) {
        todayGoalTotal++;
      }
      final done = index < completedTasks.length && completedTasks[index];
      if (done) {
        weeklyCompletedMinutes += item.minutes;
        if (item.dayIndex == dayIndex) todayGoalCompleted++;
      }
    }

    int todayMinutes = 0;
    int totalMinutes = 0;
    int sessionsToday = 0;
    int totalSessions = 0;
    int todayEnergy = 0;
    int weeklyEnergy = 0;
    final activeDays = <DateTime>{};

    for (final event in studyEvents) {
      final timestamp = DateTime.tryParse(event['timestamp']?.toString() ?? '');
      if (timestamp == null) continue;
      final eventDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final minutes = (event['value'] as num?)?.toDouble() ?? 0;
      final isSession = event['type'] == 'session';
      final isTask = event['type'] == 'task';
      if (!isSession && !isTask) continue;
      activeDays.add(eventDay);
      if (isSession) {
        totalMinutes += minutes.round();
        totalSessions++;
      }
      if (!timestamp.isBefore(weekStart) && timestamp.isBefore(weekEnd)) {
        weeklyEnergy += isSession ? 300 : 100;
        final dayKey = _dayKey(timestamp.weekday);
        weeklyHours[dayKey] = (weeklyHours[dayKey] ?? 0) + minutes / 60;
      }
      if (_sameDay(timestamp, date)) {
        todayEnergy += isSession ? 300 : 100;
        if (isSession) {
          todayMinutes += minutes.round();
          sessionsToday++;
        }
      }
    }

    final currentProgress = !isTimerActive || timerDurationMinutes <= 0
        ? 0.0
        : (1 - (timerSecondsRemaining / (timerDurationMinutes * 60))).clamp(0.0, 1.0);

    double week4Hours = weeklyHours.values.fold(0.0, (sum, val) => sum + val);
    double week3Hours = 0;
    double week2Hours = 0;
    double week1Hours = 0;

    final w4Start = weekStart;
    final w3Start = w4Start.subtract(const Duration(days: 7));
    final w2Start = w3Start.subtract(const Duration(days: 7));
    final w1Start = w2Start.subtract(const Duration(days: 7));

    for (final event in studyEvents) {
      final timestamp = DateTime.tryParse(event['timestamp']?.toString() ?? '');
      if (timestamp == null) continue;
      final minutes = (event['value'] as num?)?.toDouble() ?? 0;
      final isSession = event['type'] == 'session';
      if (!isSession) continue;

      if (timestamp.isBefore(w4Start)) {
        if (!timestamp.isBefore(w3Start)) {
          week3Hours += minutes / 60.0;
        } else if (!timestamp.isBefore(w2Start)) {
          week2Hours += minutes / 60.0;
        } else if (!timestamp.isBefore(w1Start)) {
          week1Hours += minutes / 60.0;
        }
      }
    }

    return StudyStatistics(
      streakDays: _streak(activeDays, date),
      todayEnergy: todayEnergy,
      weeklyEnergy: weeklyEnergy,
      sessionsCompleted: sessionsToday,
      sessionsGoal: todayGoalTotal,
      weeklyProgress: weeklyHours,
      todayGoalCompleted: todayGoalCompleted,
      todayGoalTotal: todayGoalTotal,
      weeklyGoalMinutes: weeklyGoalMinutes,
      weeklyCompletedMinutes: weeklyCompletedMinutes,
      todayStudyMinutes: todayMinutes,
      totalStudyMinutes: totalMinutes,
      sessionsToday: sessionsToday,
      averageFocusMinutes: totalSessions == 0 ? 0 : (totalMinutes / totalSessions).round(),
      currentSessionProgress: currentProgress,
      monthlyProgress: [week1Hours, week2Hours, week3Hours, week4Hours],
    );
  }

  int durationMinutes(String planItem) => _planItem(planItem).minutes;

  _ScheduledItem _planItem(String value) {
    final parts = value.split('|');
    final main = parts.first.trim();
    final minutesMatch = RegExp(r'([\d.]+)\s*(mins?|hrs?(?:/day)?)', caseSensitive: false).firstMatch(main);
    final number = double.tryParse(minutesMatch?.group(1) ?? '') ?? 0;
    final unit = minutesMatch?.group(2)?.toLowerCase() ?? 'mins';
    final minutes = unit.startsWith('h') ? (number * 60).round() : number.round();
    final dayIndex = parts.length > 2 ? int.tryParse(parts[2].trim()) ?? -1 : -1;
    return _ScheduledItem(minutes: minutes, dayIndex: dayIndex, isBreak: main.toLowerCase().startsWith('break '));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _streak(Set<DateTime> activeDays, DateTime today) {
    var cursor = DateTime(today.year, today.month, today.day);
    if (!activeDays.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dayKey(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

class _ScheduledItem {
  final int minutes;
  final int dayIndex;
  final bool isBreak;
  const _ScheduledItem({required this.minutes, required this.dayIndex, required this.isBreak});
}
