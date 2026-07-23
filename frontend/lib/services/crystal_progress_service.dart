import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';
import '../models/study_statistics.dart';
import 'persistence_service.dart';

class CrystalProgressService {
  static final CrystalProgressService instance = CrystalProgressService._();
  CrystalProgressService._();

  Box get _box => PersistenceService.instance.getBox('crystal_progress');

  double get focusProgress => (_box.get('focusProgress', defaultValue: 0.0) as num).toDouble();
  set focusProgress(double value) => _box.put('focusProgress', value);

  double get wisdomProgress => (_box.get('wisdomProgress', defaultValue: 0.0) as num).toDouble();
  set wisdomProgress(double value) => _box.put('wisdomProgress', value);

  double get masteryProgress => (_box.get('masteryProgress', defaultValue: 0.0) as num).toDouble();
  set masteryProgress(double value) => _box.put('masteryProgress', value);

  Future<void> update({required List<Subject> subjects, required StudyStatistics statistics}) async {
    final topics = subjects.expand((subject) => subject.topics).toList();
    final completedTopics = topics.where((topic) => topic.isCompleted).length;
    final subjectCompletion = subjects.isEmpty
        ? 0.0
        : subjects.where((subject) => subject.topics.isNotEmpty && subject.topics.every((topic) => topic.isCompleted)).length / subjects.length;
    final learningProgress = topics.isEmpty ? 0.0 : completedTopics / topics.length;
    final consistency = statistics.todayGoalTotal == 0
        ? 0.0
        : statistics.todayGoalCompleted / statistics.todayGoalTotal;
    final focus = ((statistics.sessionsToday * 10) + (consistency * 50)).clamp(0.0, 100.0);
    final wisdom = (learningProgress * 100).clamp(0.0, 100.0);
    final mastery = ((subjectCompletion * 60) + (learningProgress * 25) + (statistics.streakDays.clamp(0, 30) / 30 * 15)).clamp(0.0, 100.0);

    await _box.put('focusProgress', focus);
    await _box.put('wisdomProgress', wisdom);
    await _box.put('masteryProgress', mastery);
  }
}
