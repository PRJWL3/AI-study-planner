import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_availability.dart';
import 'persistence_service.dart';

class PlannerService {
  static final PlannerService instance = PlannerService._();
  PlannerService._();

  Box get _box => PersistenceService.instance.getBox('planner_settings');

  String get studyStyle => _box.get('studyStyle', defaultValue: 'Balanced') as String;
  set studyStyle(String value) => _box.put('studyStyle', value);

  int get breakDuration => _box.get('breakDuration', defaultValue: 10) as int;
  set breakDuration(int value) => _box.put('breakDuration', value);

  String get difficultyPref => _box.get('difficultyPref', defaultValue: 'Medium') as String;
  set difficultyPref(String value) => _box.put('difficultyPref', value);

  DateTime? get examDate {
    final val = _box.get('examDate') as String?;
    return val != null ? DateTime.tryParse(val) : null;
  }
  set examDate(DateTime? value) => _box.put('examDate', value?.toIso8601String());

  List<StudyAvailability> getAvailability() {
    final box = PersistenceService.instance.getBox('study_availability');
    final List<dynamic>? list = box.get('windows') as List<dynamic>?;
    if (list == null) {
      final defaults = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) =>
        StudyAvailability(weekday: day, startTime: "14:00", endTime: "16:00")
      ).toList();
      saveAvailability(defaults);
      return defaults;
    }
    return list.map((e) => StudyAvailability.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> saveAvailability(List<StudyAvailability> windows) async {
    final box = PersistenceService.instance.getBox('study_availability');
    await box.put('windows', windows.map((w) => w.toJson()).toList());
  }

  Future<void> addWindow(StudyAvailability window) async {
    final list = getAvailability();
    list.add(window);
    await saveAvailability(list);
  }

  Future<void> deleteWindow(int index) async {
    final list = getAvailability();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await saveAvailability(list);
    }
  }

  Future<void> editWindow(int index, StudyAvailability window) async {
    final list = getAvailability();
    if (index >= 0 && index < list.length) {
      list[index] = window;
      await saveAvailability(list);
    }
  }
}
