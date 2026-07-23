import 'package:hive_flutter/hive_flutter.dart';

class PersistenceService {
  static final PersistenceService instance = PersistenceService._();
  PersistenceService._();

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('study_sessions');
    await Hive.openBox('study_availability');
    await Hive.openBox('study_statistics');
    await Hive.openBox('crystal_progress');
    await Hive.openBox('planner_settings');
  }

  Box getBox(String name) => Hive.box(name);
}
