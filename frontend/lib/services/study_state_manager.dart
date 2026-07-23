import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subject.dart';
import '../widgets/global_eggy.dart';

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

  // Weekly Progress (Hours per weekday)
  Map<String, double> weeklyProgressHours = {
    "Mon": 0.0,
    "Tue": 0.0,
    "Wed": 0.0,
    "Thu": 0.0,
    "Fri": 0.0,
    "Sat": 0.0,
    "Sun": 0.0,
  };

  // Planner Settings
  int plannerHoursPerDay = 4;
  String plannerStudyStyle = "Balanced";
  int plannerBreakDuration = 10;
  String plannerDifficultyPref = "Moderate";
  String plannerPreferredTime = "Morning";
  DateTime? selectedDate;
  String selectedDifficulty = "Medium";

  // Study Room / Pomodoro focus timer state
  String studyRoomSelectedSubject = "General Study";
  int studyRoomDurationMinutes = 25;
  String studyRoomActiveTopic = "Focus Session";

  // Persistent analytics values (seeded with mockup values)
  int streakDays = 14;
  int todayEnergyValue = 1860;
  int weeklyEnergyValue = 12450;
  int sessionsCompleted = 3;
  int sessionsGoal = 6;

  // List of logged study events (task or session)
  List<Map<String, dynamic>> studyEvents = [];

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _initialized = true;
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
    EggyController.instance.userCourse = userCourse;
    EggyController.instance.userMascot = userMascot;
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

    await _prefs!.setInt("streak_days", streakDays);
    await _prefs!.setInt("today_energy", todayEnergyValue);
    await _prefs!.setInt("weekly_energy", weeklyEnergyValue);
    await _prefs!.setInt("sessions_completed", sessionsCompleted);
    await _prefs!.setInt("sessions_goal", sessionsGoal);

    await _prefs!.setString("study_events", jsonEncode(studyEvents));

    // Keep global eggy controller in sync
    EggyController.instance.userCourse = userCourse;
    EggyController.instance.userMascot = userMascot;
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
    await saveData();
    notifyListeners();
  }

  Future<void> toggleTask(int index, bool value, {String? dayKey}) async {
    if (index >= 0 && index < studyPlan.length) {
      completedTasks[index] = value;

      // Extract duration/hours from plan item
      final parsed = _parsePlanItem(studyPlan[index]);
      final hoursStr = parsed['hours'] ?? '';
      double taskHours = 0.0;
      final hoursMatch = RegExp(r'([\d.]+)').firstMatch(hoursStr);
      if (hoursMatch != null) {
        taskHours = double.tryParse(hoursMatch.group(1)!) ?? 0.0;
      }

      final String day = dayKey ?? _getCurrentDayKey();
      if (value) {
        weeklyProgressHours[day] = (weeklyProgressHours[day] ?? 0.0) + taskHours;
        todayEnergyValue += 100;
        weeklyEnergyValue += 100;
        _logEvent('task', taskHours);
      } else {
        weeklyProgressHours[day] = (weeklyProgressHours[day] ?? 0.0) - taskHours;
        if (weeklyProgressHours[day]! < 0) weeklyProgressHours[day] = 0.0;
        todayEnergyValue -= 100;
        weeklyEnergyValue -= 100;
        if (todayEnergyValue < 0) todayEnergyValue = 0;
        if (weeklyEnergyValue < 0) weeklyEnergyValue = 0;
      }

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
    weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) + hours;
    
    // Increment energy points
    todayEnergyValue += 300;
    weeklyEnergyValue += 300;
    sessionsCompleted = (sessionsCompleted + 1).clamp(0, sessionsGoal);

    // Update streak calendar
    _updateStreak();

    // Log study event
    _logEvent('session', durationMinutes.toDouble(), subject: subject);

    await saveData();
    notifyListeners();
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

  // Dynamic Focus Indicators

  double get focusCharge {
    if (studyPlan.isEmpty) return 59.0;
    int completed = completedTasks.where((t) => t).length;
    return (completed / studyPlan.length) * 100.0;
  }

  double get wisdomCharge {
    int total = 0;
    int completed = 0;
    for (var s in subjects) {
      total += s.topics.length;
      completed += s.topics.where((t) => t.isCompleted).length;
    }
    if (total == 0) return 34.0;
    return (completed / total) * 100.0;
  }

  double get masteryCharge {
    int totalHard = 0;
    int completedHard = 0;
    for (var s in subjects) {
      for (var t in s.topics) {
        if (t.difficulty.toLowerCase() == 'hard') {
          totalHard++;
          if (t.isCompleted) completedHard++;
        }
      }
    }
    if (totalHard == 0) {
      if (studyPlan.isEmpty) return 14.0;
      return (completedTasks.where((t) => t).length / studyPlan.length) * 100.0;
    }
    return (completedHard / totalHard) * 100.0;
  }

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

  Map<String, String> _parsePlanItem(String planStr) {
    final regex = RegExp(r'^(.+)\s+\((Easy|Medium|Hard)\)\s+-\s+(.+)$', caseSensitive: false);
    final match = regex.firstMatch(planStr);
    if (match != null) {
      return {
        'subject': match.group(1)!,
        'difficulty': match.group(2)!,
        'hours': match.group(3)!,
      };
    }
    return {
      'subject': planStr,
      'difficulty': '',
      'hours': '',
    };
  }
}
