import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'study_state_manager.dart';
import 'persistence_service.dart';
import '../models/subject.dart';

class FirestoreSyncService {
  FirestoreSyncService._privateConstructor();
  static final FirestoreSyncService instance = FirestoreSyncService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isSyncing = false;

  /// Saves the user state map to Firestore.
  Future<void> saveUserData(String email) async {
    if (email.isEmpty) return;
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final state = StudyStateManager.instance;

      final crystalBox = PersistenceService.instance.getBox('crystal_progress');
      final double focusProgress = (crystalBox.get('focusProgress') as num?)?.toDouble() ?? 0.0;
      final double wisdomProgress = (crystalBox.get('wisdomProgress') as num?)?.toDouble() ?? 0.0;
      final double masteryProgress = (crystalBox.get('masteryProgress') as num?)?.toDouble() ?? 0.0;

      final Map<String, dynamic> data = {
        "user_name": state.userName,
        "user_email": state.userEmail,
        "user_age": state.userAge,
        "user_course": state.userCourse,
        "user_year": state.userYear,
        "user_mascot": state.userMascot,
        "onboarding_strategy": state.onboardingStrategy,
        "is_profile_setup": state.isProfileSetup,
        "onboarded": state.onboarded,
        "subjects": state.subjects.map((e) => e.toJson()).toList(),
        "studyPlan": state.studyPlan,
        "completedTasks": state.completedTasks,
        "weeklyProgressHours": state.weeklyProgressHours,
        "planner_hours_per_day": state.plannerHoursPerDay,
        "planner_study_style": state.plannerStudyStyle,
        "planner_break_duration": state.plannerBreakDuration,
        "planner_difficulty_pref": state.plannerDifficultyPref,
        "planner_preferred_time": state.plannerPreferredTime,
        "examDate": state.selectedDate?.toIso8601String(),
        "difficulty": state.selectedDifficulty,
        "sr_selected_subject": state.studyRoomSelectedSubject,
        "sr_duration_minutes": state.studyRoomDurationMinutes,
        "sr_active_topic": state.studyRoomActiveTopic,
        "streak_days": state.streakDays,
        "today_energy": state.todayEnergyValue,
        "weekly_energy": state.weeklyEnergyValue,
        "sessions_completed": state.sessionsCompleted,
        "sessions_goal": state.sessionsGoal,
        "study_events": state.studyEvents,
        "crystal_focus_progress": focusProgress,
        "crystal_wisdom_progress": wisdomProgress,
        "crystal_mastery_progress": masteryProgress,
        "updatedAt": FieldValue.serverTimestamp(),
      };

      debugPrint("FirestoreSyncService: Saving user data to users/$email...");
      await _db.collection("users").doc(email).set(data, SetOptions(merge: true));
      debugPrint("FirestoreSyncService: User data saved successfully.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to save user data: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Loads the user state map from Firestore and updates all local states.
  Future<void> loadUserData(String email) async {
    if (email.isEmpty) return;

    try {
      debugPrint("FirestoreSyncService: Fetching user data from users/$email...");
      final doc = await _db.collection("users").doc(email).get();

      if (!doc.exists) {
        debugPrint("FirestoreSyncService: No user document found for $email. Initializing with defaults...");
        await saveUserData(email);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final state = StudyStateManager.instance;

      state.userName = data["user_name"] ?? state.userName;
      state.userEmail = data["user_email"] ?? state.userEmail;
      state.userAge = data["user_age"] ?? state.userAge;
      state.userCourse = data["user_course"] ?? state.userCourse;
      state.userYear = data["user_year"] ?? state.userYear;
      state.userMascot = data["user_mascot"] ?? state.userMascot;
      state.onboardingStrategy = data["onboarding_strategy"] ?? state.onboardingStrategy;
      state.isProfileSetup = data["is_profile_setup"] ?? state.isProfileSetup;
      state.onboarded = data["onboarded"] ?? state.onboarded;

      if (data["subjects"] != null) {
        final List<dynamic> subsJson = data["subjects"];
        state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      if (data["studyPlan"] != null) {
        state.studyPlan = List<String>.from(data["studyPlan"]);
      }
      if (data["completedTasks"] != null) {
        state.completedTasks = List<bool>.from(data["completedTasks"]);
      }
      if (data["weeklyProgressHours"] != null) {
        final Map<String, dynamic> rawHours = data["weeklyProgressHours"];
        state.weeklyProgressHours = rawHours.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }

      state.plannerHoursPerDay = data["planner_hours_per_day"] ?? state.plannerHoursPerDay;
      state.plannerStudyStyle = data["planner_study_style"] ?? state.plannerStudyStyle;
      state.plannerBreakDuration = data["planner_break_duration"] ?? state.plannerBreakDuration;
      state.plannerDifficultyPref = data["planner_difficulty_pref"] ?? state.plannerDifficultyPref;
      state.plannerPreferredTime = data["planner_preferred_time"] ?? state.plannerPreferredTime;

      if (data["examDate"] != null) {
        state.selectedDate = DateTime.tryParse(data["examDate"]);
      }
      state.selectedDifficulty = data["difficulty"] ?? state.selectedDifficulty;
      state.studyRoomSelectedSubject = data["sr_selected_subject"] ?? state.studyRoomSelectedSubject;
      state.studyRoomDurationMinutes = data["sr_duration_minutes"] ?? state.studyRoomDurationMinutes;
      state.studyRoomActiveTopic = data["sr_active_topic"] ?? state.studyRoomActiveTopic;

      state.streakDays = data["streak_days"] ?? state.streakDays;
      state.todayEnergyValue = data["today_energy"] ?? state.todayEnergyValue;
      state.weeklyEnergyValue = data["weekly_energy"] ?? state.weeklyEnergyValue;
      state.sessionsCompleted = data["sessions_completed"] ?? state.sessionsCompleted;
      state.sessionsGoal = data["sessions_goal"] ?? state.sessionsGoal;

      if (data["study_events"] != null) {
        state.studyEvents = List<Map<String, dynamic>>.from(
          (data["study_events"] as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
      }

      // Restore Hive values
      final crystalBox = PersistenceService.instance.getBox('crystal_progress');
      await crystalBox.put('focusProgress', (data["crystal_focus_progress"] as num?)?.toDouble() ?? 0.0);
      await crystalBox.put('wisdomProgress', (data["crystal_wisdom_progress"] as num?)?.toDouble() ?? 0.0);
      await crystalBox.put('masteryProgress', (data["crystal_mastery_progress"] as num?)?.toDouble() ?? 0.0);

      final statisticsBox = PersistenceService.instance.getBox('study_statistics');
      await statisticsBox.put('streakDays', state.streakDays);
      await statisticsBox.put('todayEnergy', state.todayEnergyValue);
      await statisticsBox.put('weeklyEnergy', state.weeklyEnergyValue);
      await statisticsBox.put('sessionsCompleted', state.sessionsCompleted);
      await statisticsBox.put('sessionsGoal', state.sessionsGoal);
      await statisticsBox.put('weeklyProgress', state.weeklyProgressHours);

      final plannerBox = PersistenceService.instance.getBox('planner_settings');
      await plannerBox.put('breakDuration', state.plannerBreakDuration);
      await plannerBox.put('studyStyle', state.plannerStudyStyle);
      await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
      if (state.selectedDate != null) {
        await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
      }

      // Save locally to SharedPreferences so the device has the cached offline copy
      await state.saveDataLocalOnly();
      debugPrint("FirestoreSyncService: User data loaded and synced successfully.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to load user data: $e");
    }
  }
}
