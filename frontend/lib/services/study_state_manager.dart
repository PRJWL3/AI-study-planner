import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../models/study_availability.dart';
import '../models/study_statistics.dart';
import '../widgets/global_eggy.dart';
import 'persistence_service.dart';
import 'planner_service.dart';
import 'statistics_service.dart';
import 'crystal_progress_service.dart';

class StudyStateManager extends ChangeNotifier {
  static final StudyStateManager instance = StudyStateManager._internal();
  StudyStateManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Onboarding / Profile state
  String userName = "";
  int userAge = 18;
  String userCourse = "";
  String userYear = "";
  String userMascot = "assets/images/mascot_boy.png";
  String onboardingStrategy = "";
  bool isLoggedIn = false;
  bool isProfileSetup = false;
  bool onboarded = false;

  // Subjects state
  List<Subject> subjects = [];

  // Study Plan & Tasks state
  List<String> studyPlan = [];
  List<bool> completedTasks = [];

  // Weekly Progress (Hours per weekday) delegated to StatisticsService
  Map<String, double> get weeklyProgressHours => StatisticsService.instance.getWeeklyProgress();
  set weeklyProgressHours(Map<String, double> val) {
    StatisticsService.instance.weeklyProgress = val;
    notifyListeners();
  }

  // Planner Settings delegated to PlannerService
  int plannerHoursPerDay = 4;
  
  String get plannerStudyStyle => PlannerService.instance.studyStyle;
  set plannerStudyStyle(String val) {
    PlannerService.instance.studyStyle = val;
    notifyListeners();
  }

  int get plannerBreakDuration => PlannerService.instance.breakDuration;
  set plannerBreakDuration(int val) {
    PlannerService.instance.breakDuration = val;
    notifyListeners();
  }

  String get plannerDifficultyPref => PlannerService.instance.difficultyPref;
  set plannerDifficultyPref(String val) {
    PlannerService.instance.difficultyPref = val;
    notifyListeners();
  }

  String plannerPreferredTime = "Morning";

  DateTime? get selectedDate => PlannerService.instance.examDate;
  set selectedDate(DateTime? val) {
    PlannerService.instance.examDate = val;
    notifyListeners();
  }

  String selectedDifficulty = "Medium";

  // Study Room / Pomodoro focus timer state
  String studyRoomSelectedSubject = "General Study";
  int studyRoomDurationMinutes = 25;
  String studyRoomActiveTopic = "Focus Session";

  // Persistent live timer state fields
  bool isTimerActive = false;
  bool isTimerPaused = false;
  int timerSecondsRemaining = 0;
  int timerDurationMinutes = 25;
  String timerSelectedSubject = "General Study";
  String timerActiveChapter = "";
  String timerActiveTopic = "";
  int timerTaskIndex = -1;
  DateTime? timerEndTimestamp;

  // Persistent analytics values delegated to StatisticsService
  int get streakDays => StatisticsService.instance.streakDays;
  set streakDays(int val) {
    StatisticsService.instance.streakDays = val;
    notifyListeners();
  }

  int get todayEnergyValue => StatisticsService.instance.todayEnergy;
  set todayEnergyValue(int val) {
    StatisticsService.instance.todayEnergy = val;
    notifyListeners();
  }

  int get weeklyEnergyValue => StatisticsService.instance.weeklyEnergy;
  set weeklyEnergyValue(int val) {
    StatisticsService.instance.weeklyEnergy = val;
    notifyListeners();
  }

  int get sessionsCompleted => StatisticsService.instance.sessionsCompleted;
  set sessionsCompleted(int val) {
    StatisticsService.instance.sessionsCompleted = val;
    notifyListeners();
  }

  int get sessionsGoal => StatisticsService.instance.sessionsGoal;
  set sessionsGoal(int val) {
    StatisticsService.instance.sessionsGoal = val;
    notifyListeners();
  }

  // List of logged study events (task or session)
  List<Map<String, dynamic>> studyEvents = [];

  /// The manager only supplies state to the statistics service; calculations
  /// remain in the service so every screen reads the same live values.
  StudyStatistics get statistics => StatisticsService.instance.calculate(
        studyPlan: studyPlan,
        completedTasks: completedTasks,
        studyEvents: studyEvents,
        plannerHoursPerDay: plannerHoursPerDay,
        isTimerActive: isTimerActive,
        timerDurationMinutes: timerDurationMinutes,
        timerSecondsRemaining: timerSecondsRemaining,
      );

  Future<void> init() async {
    debugPrint("APP_START: StudyStateManager.init() called");
    if (_initialized) {
      debugPrint("APP_START: StudyStateManager already initialized");
      return;
    }

    // Initialize Persistence/Hive
    debugPrint("APP_START: Initializing PersistenceService...");
    await PersistenceService.instance.init();
    debugPrint("APP_START: PersistenceService initialized");

    debugPrint("APP_START: Fetching SharedPreferences...");
    _prefs = await SharedPreferences.getInstance();
    debugPrint("APP_START: SharedPreferences fetched");

    // Copy / migrate data from SharedPreferences to Hive if not already present
    final statisticsBox = PersistenceService.instance.getBox('study_statistics');
    if (!statisticsBox.containsKey('streakDays')) {
      debugPrint("APP_START: Migrating statistics to Hive...");
      await statisticsBox.put('streakDays', _prefs!.getInt("streak_days") ?? 0);
      await statisticsBox.put('todayEnergy', _prefs!.getInt("today_energy") ?? 0);
      await statisticsBox.put('weeklyEnergy', _prefs!.getInt("weekly_energy") ?? 0);
      await statisticsBox.put('sessionsCompleted', _prefs!.getInt("sessions_completed") ?? 0);
      await statisticsBox.put('sessionsGoal', _prefs!.getInt("sessions_goal") ?? 0);
      
      final progStr = _prefs!.getString("weeklyProgressHours");
      if (progStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(progStr);
          await statisticsBox.put('weeklyProgress', decoded.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
        } catch (_) {}
      }
    }

    final plannerBox = PersistenceService.instance.getBox('planner_settings');
    if (!plannerBox.containsKey('breakDuration')) {
      debugPrint("APP_START: Migrating planner settings to Hive...");
      await plannerBox.put('breakDuration', _prefs!.getInt("planner_break_duration") ?? 10);
      await plannerBox.put('studyStyle', _prefs!.getString("planner_study_style") ?? "Balanced");
      await plannerBox.put('difficultyPref', _prefs!.getString("planner_difficulty_pref") ?? "Moderate");
      final examDateStr = _prefs!.getString("examDate");
      if (examDateStr != null) {
        await plannerBox.put('examDate', examDateStr);
      }
    }

    final crystalBox = PersistenceService.instance.getBox('crystal_progress');
    if (!crystalBox.containsKey('focusProgress')) {
      debugPrint("APP_START: Initializing crystal progress in Hive...");
      await crystalBox.put('focusProgress', 0.0);
      await crystalBox.put('wisdomProgress', 0.0);
      await crystalBox.put('masteryProgress', 0.0);
    }
    
    debugPrint("APP_START: Loading from prefs...");
    _loadFromPrefs();
    debugPrint("APP_START: Refreshing crystal progress...");
    await _refreshCrystalProgress();
    
    // Check if a timer was running in the background and completed while app was closed
    if (isTimerActive && !isTimerPaused && timerEndTimestamp != null) {
      debugPrint("APP_START: Processing active background timer...");
      final now = DateTime.now();
      final diff = timerEndTimestamp!.difference(now).inSeconds;
      if (diff > 0) {
        timerSecondsRemaining = diff;
      } else {
        // Completed while app was closed!
        final double completedHours = timerDurationMinutes / 60.0;
        await completeFocusSession(completedHours, timerSelectedSubject, timerDurationMinutes);
        if (timerTaskIndex >= 0 && timerTaskIndex < studyPlan.length) {
          completedTasks[timerTaskIndex] = true;
        }
        isTimerActive = false;
        isTimerPaused = false;
        timerSecondsRemaining = 0;
        await saveData();
      }
    }
    
    _initialized = true;
    debugPrint("APP_START: StudyStateManager init finished");
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    userName = _prefs!.getString("user_name") ?? "";
    userAge = _prefs!.getInt("user_age") ?? 18;
    userCourse = _prefs!.getString("user_course") ?? "";
    userYear = _prefs!.getString("user_year") ?? "";
    userMascot = _prefs!.getString("user_mascot") ?? "assets/images/mascot_boy.png";
    onboardingStrategy = _prefs!.getString("onboarding_strategy") ?? "";
    isLoggedIn = _prefs!.getBool("is_logged_in") ?? false;
    isProfileSetup = _prefs!.getBool("is_profile_setup") ?? false;
    onboarded = _prefs!.getBool("onboarded") ?? false;

    final subjectsData = _prefs!.getString("subjects");
    if (subjectsData != null) {
      try {
        subjects = (jsonDecode(subjectsData) as List)
            .map((e) => Subject.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint("Error parsing subjects: $e");
      }
    }

    studyPlan = _prefs!.getStringList("studyPlan") ?? [];
    
    final tasksData = _prefs!.getString("completedTasks");
    if (tasksData != null) {
      try {
        completedTasks = List<bool>.from(jsonDecode(tasksData));
      } catch (e) {
        debugPrint("Error parsing completedTasks: $e");
      }
    }

    if (studyPlan.length != completedTasks.length) {
      completedTasks = List.generate(studyPlan.length, (_) => false);
    }

    final progressData = _prefs!.getString("weeklyProgressHours");
    if (progressData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(progressData);
        weeklyProgressHours = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      } catch (e) {
        debugPrint("Error parsing weeklyProgressHours: $e");
      }
    }

    plannerHoursPerDay = _prefs!.getInt("planner_hours_per_day") ?? 4;
    plannerStudyStyle = _prefs!.getString("planner_study_style") ?? "Balanced";
    plannerBreakDuration = _prefs!.getInt("planner_break_duration") ?? 10;
    plannerDifficultyPref = _prefs!.getString("planner_difficulty_pref") ?? "Moderate";
    plannerPreferredTime = _prefs!.getString("planner_preferred_time") ?? "Morning";
    
    final examDateStr = _prefs!.getString("examDate");
    if (examDateStr != null) {
      selectedDate = DateTime.tryParse(examDateStr);
    }
    
    selectedDifficulty = _prefs!.getString("difficulty") ?? "Medium";

    studyRoomSelectedSubject = _prefs!.getString("sr_selected_subject") ?? "General Study";
    studyRoomDurationMinutes = _prefs!.getInt("sr_duration_minutes") ?? 25;
    studyRoomActiveTopic = _prefs!.getString("sr_active_topic") ?? "Focus Session";

    isTimerActive = _prefs!.getBool("timer_is_active") ?? false;
    isTimerPaused = _prefs!.getBool("timer_is_paused") ?? false;
    timerSecondsRemaining = _prefs!.getInt("timer_seconds_remaining") ?? 0;
    timerDurationMinutes = _prefs!.getInt("timer_duration_minutes") ?? 25;
    timerSelectedSubject = _prefs!.getString("timer_selected_subject") ?? "General Study";
    timerActiveChapter = _prefs!.getString("timer_active_chapter") ?? "";
    timerActiveTopic = _prefs!.getString("timer_active_topic") ?? "";
    timerTaskIndex = _prefs!.getInt("timer_task_index") ?? -1;
    final endTimestampStr = _prefs!.getString("timer_end_timestamp");
    if (endTimestampStr != null) {
      timerEndTimestamp = DateTime.tryParse(endTimestampStr);
    }

    streakDays = _prefs!.getInt("streak_days") ?? 14;
    todayEnergyValue = _prefs!.getInt("today_energy") ?? 1860;
    weeklyEnergyValue = _prefs!.getInt("weekly_energy") ?? 12450;
    sessionsCompleted = _prefs!.getInt("sessions_completed") ?? 3;
    sessionsGoal = _prefs!.getInt("sessions_goal") ?? 6;

    final eventsData = _prefs!.getString("study_events");
    if (eventsData != null) {
      try {
        studyEvents = List<Map<String, dynamic>>.from(jsonDecode(eventsData));
      } catch (e) {
        debugPrint("Error parsing study_events: $e");
      }
    }

    // Update global eggy controller settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EggyController.instance.userCourse = userCourse;
      EggyController.instance.userMascot = userMascot;
    });
  }

  Future<void> saveData() async {
    if (_prefs == null) return;

    await _prefs!.setString("user_name", userName);
    await _prefs!.setInt("user_age", userAge);
    await _prefs!.setString("user_course", userCourse);
    await _prefs!.setString("user_year", userYear);
    await _prefs!.setString("user_mascot", userMascot);
    await _prefs!.setString("onboarding_strategy", onboardingStrategy);
    await _prefs!.setBool("is_logged_in", isLoggedIn);
    await _prefs!.setBool("is_profile_setup", isProfileSetup);
    await _prefs!.setBool("onboarded", onboarded);

    await _prefs!.setString("subjects", jsonEncode(subjects.map((e) => e.toJson()).toList()));
    await _prefs!.setStringList("studyPlan", studyPlan);
    await _prefs!.setString("completedTasks", jsonEncode(completedTasks));
    await _prefs!.setString("weeklyProgressHours", jsonEncode(weeklyProgressHours));

    await _prefs!.setInt("planner_hours_per_day", plannerHoursPerDay);
    await _prefs!.setString("planner_study_style", plannerStudyStyle);
    await _prefs!.setInt("planner_break_duration", plannerBreakDuration);
    await _prefs!.setString("planner_difficulty_pref", plannerDifficultyPref);
    await _prefs!.setString("planner_preferred_time", plannerPreferredTime);
    
    if (selectedDate != null) {
      await _prefs!.setString("examDate", selectedDate!.toIso8601String());
    } else {
      await _prefs!.remove("examDate");
    }

    await _prefs!.setString("difficulty", selectedDifficulty);

    await _prefs!.setString("sr_selected_subject", studyRoomSelectedSubject);
    await _prefs!.setInt("sr_duration_minutes", studyRoomDurationMinutes);
    await _prefs!.setString("sr_active_topic", studyRoomActiveTopic);

    await _prefs!.setBool("timer_is_active", isTimerActive);
    await _prefs!.setBool("timer_is_paused", isTimerPaused);
    await _prefs!.setInt("timer_seconds_remaining", timerSecondsRemaining);
    await _prefs!.setInt("timer_duration_minutes", timerDurationMinutes);
    await _prefs!.setString("timer_selected_subject", timerSelectedSubject);
    await _prefs!.setString("timer_active_chapter", timerActiveChapter);
    await _prefs!.setString("timer_active_topic", timerActiveTopic);
    await _prefs!.setInt("timer_task_index", timerTaskIndex);
    if (timerEndTimestamp != null) {
      await _prefs!.setString("timer_end_timestamp", timerEndTimestamp!.toIso8601String());
    } else {
      await _prefs!.remove("timer_end_timestamp");
    }

    await _prefs!.setInt("streak_days", streakDays);
    await _prefs!.setInt("today_energy", todayEnergyValue);
    await _prefs!.setInt("weekly_energy", weeklyEnergyValue);
    await _prefs!.setInt("sessions_completed", sessionsCompleted);
    await _prefs!.setInt("sessions_goal", sessionsGoal);

    await _prefs!.setString("study_events", jsonEncode(studyEvents));

    // Keep global eggy controller in sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EggyController.instance.userCourse = userCourse;
      EggyController.instance.userMascot = userMascot;
    });
  }

  // Mutators

  Future<void> login(bool loggedIn) async {
    isLoggedIn = loggedIn;
    await saveData();
    notifyListeners();
  }

  Future<void> logout() async {
    isLoggedIn = false;
    isProfileSetup = false;
    onboarded = false;
    userName = "";
    userCourse = "";
    subjects = [];
    studyPlan = [];
    completedTasks = [];
    weeklyProgressHours = {
      "Mon": 0.0,
      "Tue": 0.0,
      "Wed": 0.0,
      "Thu": 0.0,
      "Fri": 0.0,
      "Sat": 0.0,
      "Sun": 0.0,
    };
    studyEvents = [];
    streakDays = 14;
    todayEnergyValue = 1860;
    weeklyEnergyValue = 12450;
    sessionsCompleted = 3;
    await saveData();
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required int age,
    required String course,
    required String mascot,
  }) async {
    userName = name;
    userAge = age;
    userCourse = course;
    userMascot = mascot;
    isProfileSetup = true;
    onboarded = true;

    // Trigger mascot animation
    EggyController.instance.userCourse = course;
    EggyController.instance.userMascot = mascot;
    EggyController.instance.triggerJoyBounce();

    await saveData();
    notifyListeners();
  }

  Future<void> setSyllabusAndStrategy({
    required List<Subject> selectedSubjects,
    required String course,
    required String year,
    required String strategy,
  }) async {
    subjects = selectedSubjects;
    userCourse = course;
    userYear = year;
    onboardingStrategy = strategy;
    onboarded = true;

    // Clear old plan when syllabus changes
    studyPlan = [];
    completedTasks = [];

    await saveData();
    notifyListeners();
  }

  Future<void> addSubject(Subject subject) async {
    subjects.add(subject);
    await saveData();
    notifyListeners();
  }

  Future<void> deleteSubject(int index) async {
    if (index >= 0 && index < subjects.length) {
      subjects.removeAt(index);
      await saveData();
      notifyListeners();
    }
  }

  Future<void> toggleTopicCompletion(String subjectName, String topicName, bool isCompleted) async {
    for (var subject in subjects) {
      if (subject.name == subjectName) {
        for (var topic in subject.topics) {
          if (topic.name == topicName) {
            topic.isCompleted = isCompleted;
            break;
          }
        }
      }
    }
    await _refreshCrystalProgress();
    await saveData();
    notifyListeners();
  }

  Future<void> updateSubjectTopics(String subjectName, List<Topic> newTopics) async {
    for (var subject in subjects) {
      if (subject.name == subjectName) {
        subject.topics = newTopics;
        break;
      }
    }
    await _refreshCrystalProgress();
    await saveData();
    notifyListeners();
  }

  Future<void> toggleTask(int index, bool value, {String? dayKey}) async {
    if (index >= 0 && index < studyPlan.length) {
      completedTasks[index] = value;

      final taskMinutes = StatisticsService.instance.durationMinutes(studyPlan[index]);

      final String day = dayKey ?? _getCurrentDayKey();
      final Map<String, double> progress = Map<String, double>.from(weeklyProgressHours);
      if (value) {
        progress[day] = (progress[day] ?? 0.0) + taskMinutes / 60.0;
        weeklyProgressHours = progress;
        todayEnergyValue += 100;
        weeklyEnergyValue += 100;
        _logEvent('task', taskMinutes.toDouble());
      } else {
        progress[day] = (progress[day] ?? 0.0) - taskMinutes / 60.0;
        if (progress[day]! < 0) progress[day] = 0.0;
        weeklyProgressHours = progress;
        todayEnergyValue -= 100;
        weeklyEnergyValue -= 100;
        if (todayEnergyValue < 0) todayEnergyValue = 0;
        if (weeklyEnergyValue < 0) weeklyEnergyValue = 0;
      }

      await _refreshCrystalProgress();
      await saveData();
      notifyListeners();
    }
  }

  Future<void> addTask(String subject, String difficulty, int duration) async {
    studyPlan.add("$subject ($difficulty) - $duration mins");
    completedTasks.add(false);
    await saveData();
    notifyListeners();
  }

  Future<void> deleteTask(int index) async {
    if (index >= 0 && index < studyPlan.length) {
      studyPlan.removeAt(index);
      completedTasks.removeAt(index);
      await saveData();
      notifyListeners();
    }
  }

  Future<void> editTask(int index, String subject, String difficulty, String hours) async {
    if (index >= 0 && index < studyPlan.length) {
      // Reformat to correct string representation
      studyPlan[index] = "$subject ($difficulty) - $hours hrs/day";
      await saveData();
      notifyListeners();
    }
  }

  Future<void> completeFocusSession(double hours, String subject, int durationMinutes) async {
    final String dayKey = _getCurrentDayKey();
    final Map<String, double> progress = Map<String, double>.from(weeklyProgressHours);
    progress[dayKey] = (progress[dayKey] ?? 0.0) + hours;
    weeklyProgressHours = progress;
    
    // Increment energy points
    todayEnergyValue += 300;
    weeklyEnergyValue += 300;
    sessionsCompleted = (sessionsCompleted + 1).clamp(0, sessionsGoal);

    // Update streak calendar
    _updateStreak();

    // Log study event
    _logEvent('session', durationMinutes.toDouble(), subject: subject);

    // Mark active chapter as completed
    if (timerActiveChapter.isNotEmpty) {
      for (var s in subjects) {
        if (s.name.toLowerCase() == subject.toLowerCase()) {
          for (var t in s.topics) {
            if (t.name.toLowerCase() == timerActiveChapter.toLowerCase()) {
              t.isCompleted = true;
              break;
            }
          }
        }
      }
    }

    await _refreshCrystalProgress();
    await saveData();
    notifyListeners();
  }

  List<StudyAvailability> getAvailability() {
    return PlannerService.instance.getAvailability();
  }

  Future<void> addAvailabilityWindow(StudyAvailability window) async {
    await PlannerService.instance.addWindow(window);
    notifyListeners();
  }

  Future<void> deleteAvailabilityWindow(int index) async {
    await PlannerService.instance.deleteWindow(index);
    notifyListeners();
  }

  Future<void> editAvailabilityWindow(int index, StudyAvailability window) async {
    await PlannerService.instance.editWindow(index, window);
    notifyListeners();
  }

  double calculateAverageHoursPerDay() {
    final list = getAvailability();
    if (list.isEmpty) return 4.0;
    
    double totalMins = 0.0;
    for (final window in list) {
      final startParts = window.startTime.split(':');
      final endParts = window.endTime.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;
      
      final startHr = int.tryParse(startParts[0]) ?? 0;
      final startMin = int.tryParse(startParts[1]) ?? 0;
      final endHr = int.tryParse(endParts[0]) ?? 0;
      final endMin = int.tryParse(endParts[1]) ?? 0;
      
      final startTotal = startHr * 60 + startMin;
      final endTotal = endHr * 60 + endMin;
      
      if (endTotal > startTotal) {
        totalMins += (endTotal - startTotal);
      }
    }
    return (totalMins / 60.0) / 7.0;
  }

  Future<void> generatePlanFromAvailability() async {
    final List<Subject> currentSubjects = subjects;
    if (currentSubjects.isEmpty) return;
    
    final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final List<String> newPlan = [];
    final availability = getAvailability();
    
    // Sort availability windows by day and start time
    final Map<String, List<StudyAvailability>> grouped = {};
    for (final day in weekdays) {
      grouped[day] = availability.where((w) => w.weekday == day).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    
    int subjectIdx = 0;
    
    for (int dayIdx = 0; dayIdx < 7; dayIdx++) {
      final dayName = weekdays[dayIdx];
      final List<StudyAvailability> windows = grouped[dayName] ?? [];
      
      for (final window in windows) {
        final startParts = window.startTime.split(':');
        final endParts = window.endTime.split(':');
        if (startParts.length < 2 || endParts.length < 2) continue;
        
        final startHr = int.tryParse(startParts[0]) ?? 0;
        final startMin = int.tryParse(startParts[1]) ?? 0;
        final endHr = int.tryParse(endParts[0]) ?? 0;
        final endMin = int.tryParse(endParts[1]) ?? 0;
        
        int currentTotalMins = startHr * 60 + startMin;
        final endTotalMins = endHr * 60 + endMin;
        
        while (currentTotalMins < endTotalMins) {
          final remainingMins = endTotalMins - currentTotalMins;
          if (remainingMins < 15) {
            break;
          }
          
          final subject = currentSubjects[subjectIdx % currentSubjects.length];
          subjectIdx++;
          
          int sessionLength = 45;
          switch (subject.difficulty.toLowerCase()) {
            case 'hard':
              sessionLength = 60;
              break;
            case 'easy':
              sessionLength = 30;
              break;
            default:
              sessionLength = 45;
          }
          
          if (sessionLength > remainingMins) {
            sessionLength = remainingMins;
          }
          
          final sessionStartStr = "${(currentTotalMins ~/ 60).toString().padLeft(2, '0')}:${(currentTotalMins % 60).toString().padLeft(2, '0')}";
          currentTotalMins += sessionLength;
          final sessionEndStr = "${(currentTotalMins ~/ 60).toString().padLeft(2, '0')}:${(currentTotalMins % 60).toString().padLeft(2, '0')}";
          
          newPlan.add("${subject.name} (${subject.difficulty}) - $sessionLength mins | $sessionStartStr - $sessionEndStr | $dayIdx");
          
          final nextRemainingMins = endTotalMins - currentTotalMins;
          if (nextRemainingMins >= (plannerBreakDuration + 15)) {
            final breakStartStr = "${(currentTotalMins ~/ 60).toString().padLeft(2, '0')}:${(currentTotalMins % 60).toString().padLeft(2, '0')}";
            currentTotalMins += plannerBreakDuration;
            final breakEndStr = "${(currentTotalMins ~/ 60).toString().padLeft(2, '0')}:${(currentTotalMins % 60).toString().padLeft(2, '0')}";
            
            newPlan.add("Break (Easy) - $plannerBreakDuration mins | $breakStartStr - $breakEndStr | $dayIdx");
          }
        }
      }
    }
    
    await saveStudyPlan(newPlan);
  }

  Future<void> updatePlannerSettings({
    required int hours,
    required String style,
    required int breakDuration,
    required String difficulty,
    required String preferredTime,
    DateTime? examDate,
    String? globalDiff,
  }) async {
    plannerHoursPerDay = hours;
    plannerStudyStyle = style;
    plannerBreakDuration = breakDuration;
    plannerDifficultyPref = difficulty;
    plannerPreferredTime = preferredTime;
    if (examDate != null) selectedDate = examDate;
    if (globalDiff != null) selectedDifficulty = globalDiff;

    await saveData();
    notifyListeners();
  }

  Future<void> setStudyRoomTimerSettings(String subject, int minutes) async {
    studyRoomSelectedSubject = subject;
    studyRoomDurationMinutes = minutes;
    await saveData();
    notifyListeners();
  }

  Future<void> saveStudyPlan(List<String> plan) async {
    studyPlan = plan;
    completedTasks = List.generate(studyPlan.length, (_) => false);
    weeklyProgressHours = {
      "Mon": 0.0,
      "Tue": 0.0,
      "Wed": 0.0,
      "Thu": 0.0,
      "Fri": 0.0,
      "Sat": 0.0,
      "Sun": 0.0,
    };
    await saveData();
    notifyListeners();
  }

  /// Updates plan strings in-place without resetting completedTasks or
  /// weekly progress.  Used when adjusting session start/end times after
  /// a duration override.
  Future<void> updateStudyPlanInPlace(List<String> newPlan) async {
    studyPlan = newPlan;
    // Reconcile completedTasks length
    while (completedTasks.length < studyPlan.length) {
      completedTasks.add(false);
    }
    if (completedTasks.length > studyPlan.length) {
      completedTasks = completedTasks.sublist(0, studyPlan.length);
    }
    await saveData();
    notifyListeners();
  }

  double get focusCharge => CrystalProgressService.instance.focusProgress;
  double get wisdomCharge => CrystalProgressService.instance.wisdomProgress;
  double get masteryCharge => CrystalProgressService.instance.masteryProgress;

  Future<void> _refreshCrystalProgress() => CrystalProgressService.instance.update(
        subjects: subjects,
        statistics: statistics,
      );

  // Helpers

  String _getTodayStr() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getCurrentDayKey() {
    switch (DateTime.now().weekday) {
      case DateTime.monday: return "Mon";
      case DateTime.tuesday: return "Tue";
      case DateTime.wednesday: return "Wed";
      case DateTime.thursday: return "Thu";
      case DateTime.friday: return "Fri";
      case DateTime.saturday: return "Sat";
      case DateTime.sunday: return "Sun";
      default: return "Mon";
    }
  }

  void _logEvent(String type, double value, {String? subject}) {
    studyEvents.add({
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'value': value,
      'subject': subject ?? '',
    });
  }

  void _updateStreak() {
    final todayStr = _getTodayStr();
    final lastActiveDay = _prefs?.getString("last_active_day") ?? "";
    if (lastActiveDay == todayStr) {
      return; // Already active today
    }
    
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    
    if (lastActiveDay == yesterdayStr) {
      streakDays++;
    } else if (lastActiveDay.isNotEmpty) {
      streakDays = 1; // Streak broken
    } else {
      // Default initial state or seed
      streakDays = 14;
    }
    _prefs?.setString("last_active_day", todayStr);
  }

  Map<String, String> parsePlanItem(String planStr) {
    final parts = planStr.split('|');
    final mainPlan = parts[0].trim();
    
    final regex = RegExp(r'^(.+)\s+\((Easy|Medium|Hard)\)\s+-\s+(.+)$', caseSensitive: false);
    final match = regex.firstMatch(mainPlan);
    
    String subject = mainPlan;
    String difficulty = 'Medium';
    String hours = '60 mins';
    
    if (match != null) {
      subject = match.group(1)!.trim();
      difficulty = match.group(2)!.trim();
      hours = match.group(3)!.trim();
    }
    
    String startTime = "";
    String endTime = "";
    String dayIndex = "";
    
    if (parts.length >= 2) {
      final times = parts[1].split('-');
      if (times.length >= 2) {
        startTime = times[0].trim();
        endTime = times[1].trim();
      }
    }
    
    if (parts.length >= 3) {
      dayIndex = parts[2].trim();
    }
    
    return {
      'subject': subject,
      'difficulty': difficulty,
      'hours': hours,
      'startTime': startTime,
      'endTime': endTime,
      'dayIndex': dayIndex,
    };
  }
}
