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

  /// Saves the user state map to Firestore under nested subcollections for users/{uid}.
  Future<void> saveUserData(String uid) async {
    if (uid.isEmpty) return;
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      final state = StudyStateManager.instance;

      final crystalBox = PersistenceService.instance.getBox('crystal_progress');
      final double focusProgress = (crystalBox.get('focusProgress') as num?)?.toDouble() ?? 0.0;
      final double wisdomProgress = (crystalBox.get('wisdomProgress') as num?)?.toDouble() ?? 0.0;
      final double masteryProgress = (crystalBox.get('masteryProgress') as num?)?.toDouble() ?? 0.0;

      final availabilityBox = PersistenceService.instance.getBox('study_availability');
      final List<dynamic> availabilityList = availabilityBox.get('windows') ?? [];

      final sessionsBox = PersistenceService.instance.getBox('study_sessions');
      final List<dynamic> sessionsList = sessionsBox.get('sessions') ?? [];

      // 1. Profile information - users/{uid}/profile/details
      final Map<String, dynamic> profileDetails = {
        "displayName": state.userName,
        "email": state.userEmail,
        "photoURL": state.userPhotoUrl,
        "onboardingCompleted": state.onboardingCompleted,
        "user_age": state.userAge,
        "user_course": state.userCourse,
        "user_year": state.userYear,
        "onboarding_strategy": state.onboardingStrategy,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving profile/details to users/$uid/profile/details...");
      await _db.collection("users").doc(uid).collection("profile").doc("details").set(profileDetails, SetOptions(merge: true));

      // 2. Selected mascot - users/{uid}/profile/selectedMascot
      debugPrint("FirestoreSyncService: Saving selectedMascot to users/$uid/profile/selectedMascot...");
      await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").set({
        "selectedMascot": state.userMascot,
      }, SetOptions(merge: true));

      // 3. Subjects - users/{uid}/subjects/data
      final Map<String, dynamic> subjectsData = {
        "subjects": state.subjects.map((e) => e.toJson()).toList(),
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving subjects to users/$uid/subjects/data...");
      await _db.collection("users").doc(uid).collection("subjects").doc("data").set(subjectsData, SetOptions(merge: true));

      // 4. Schedules - users/{uid}/schedules/data
      final Map<String, dynamic> schedulesData = {
        "studyPlan": state.studyPlan,
        "completedTasks": state.completedTasks,
        "availability": availabilityList,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving schedules to users/$uid/schedules/data...");
      await _db.collection("users").doc(uid).collection("schedules").doc("data").set(schedulesData, SetOptions(merge: true));

      // 5. Study Sessions - users/{uid}/studySessions/data
      final Map<String, dynamic> sessionsData = {
        "sessions": sessionsList,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving studySessions to users/$uid/studySessions/data...");
      await _db.collection("users").doc(uid).collection("studySessions").doc("data").set(sessionsData, SetOptions(merge: true));

      // 6. Achievements - users/{uid}/achievements/data
      final Map<String, dynamic> achievementsData = {
        "studyEvents": state.studyEvents,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving achievements to users/$uid/achievements/data...");
      await _db.collection("users").doc(uid).collection("achievements").doc("data").set(achievementsData, SetOptions(merge: true));

      // 7. Statistics - users/{uid}/statistics/data
      final Map<String, dynamic> statisticsData = {
        "streakDays": state.streakDays,
        "todayEnergy": state.todayEnergyValue,
        "weeklyEnergy": state.weeklyEnergyValue,
        "sessionsCompleted": state.sessionsCompleted,
        "sessionsGoal": state.sessionsGoal,
        "weeklyProgressHours": state.weeklyProgressHours,
        "crystal_focus_progress": focusProgress,
        "crystal_wisdom_progress": wisdomProgress,
        "crystal_mastery_progress": masteryProgress,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving statistics to users/$uid/statistics/data...");
      await _db.collection("users").doc(uid).collection("statistics").doc("data").set(statisticsData, SetOptions(merge: true));

      // 8. Settings - users/{uid}/settings/data
      final Map<String, dynamic> settingsData = {
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
        "updatedAt": FieldValue.serverTimestamp(),
      };
      debugPrint("FirestoreSyncService: Saving settings to users/$uid/settings/data...");
      await _db.collection("users").doc(uid).collection("settings").doc("data").set(settingsData, SetOptions(merge: true));

      debugPrint("FirestoreSyncService: User data saved successfully under nested subcollections.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to save user data: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Updates only the selectedMascot field in Firestore without modifying any profile or photoURL.
  Future<void> saveMascot(String uid, String mascot) async {
    if (uid.isEmpty) return;
    try {
      debugPrint("FirestoreSyncService: Updating selectedMascot in users/$uid/profile/selectedMascot...");
      await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").set({
        "selectedMascot": mascot,
      }, SetOptions(merge: true));
      debugPrint("FirestoreSyncService: Mascot updated successfully.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to update mascot: $e");
    }
  }

  /// Loads the user state map and mascot from nested subcollections under users/{uid} and updates all local states.
  Future<void> loadUserData(String uid) async {
    if (uid.isEmpty) return;

    try {
      debugPrint("FirestoreSyncService: Fetching profile details from users/$uid/profile/details...");
      final detailsDoc = await _db.collection("users").doc(uid).collection("profile").doc("details").get();
      final state = StudyStateManager.instance;

      if (!detailsDoc.exists) {
        debugPrint("FirestoreSyncService: No profile details found for $uid. Treating as a new user.");
        state.onboardingCompleted = false;
        state.isProfileSetup = false;
        state.onboarded = false;
        return;
      }

      final profileData = detailsDoc.data() as Map<String, dynamic>;

      state.userName = profileData["displayName"] ?? state.userName;
      state.userEmail = profileData["email"] ?? state.userEmail;
      state.onboardingCompleted = profileData["onboardingCompleted"] ?? false;
      // Skip setup screen if onboardingCompleted is true
      if (state.onboardingCompleted) {
        state.isProfileSetup = true;
        state.onboarded = true;
      }

      // Load photoURL only if not already loaded from Firebase Auth
      if (state.userPhotoUrl.isEmpty) {
        state.userPhotoUrl = profileData["photoURL"] ?? "";
      }

      state.userAge = profileData["user_age"] ?? state.userAge;
      state.userCourse = profileData["user_course"] ?? state.userCourse;
      state.userYear = profileData["user_year"] ?? state.userYear;
      state.onboardingStrategy = profileData["onboarding_strategy"] ?? state.onboardingStrategy;

      // 2. Load mascot separately
      debugPrint("FirestoreSyncService: Fetching selectedMascot from users/$uid/profile/selectedMascot...");
      final mascotDoc = await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").get();
      if (mascotDoc.exists) {
        final mascotData = mascotDoc.data() as Map<String, dynamic>;
        state.userMascot = mascotData["selectedMascot"] ?? state.userMascot;
      }

      // 3. Load Subjects
      debugPrint("FirestoreSyncService: Fetching subjects from users/$uid/subjects/data...");
      final subjectsDoc = await _db.collection("users").doc(uid).collection("subjects").doc("data").get();
      if (subjectsDoc.exists) {
        final data = subjectsDoc.data() as Map<String, dynamic>;
        if (data["subjects"] != null) {
          final List<dynamic> subsJson = data["subjects"];
          state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        }
      }

      // 4. Load Schedules
      debugPrint("FirestoreSyncService: Fetching schedules from users/$uid/schedules/data...");
      final schedulesDoc = await _db.collection("users").doc(uid).collection("schedules").doc("data").get();
      if (schedulesDoc.exists) {
        final data = schedulesDoc.data() as Map<String, dynamic>;
        if (data["studyPlan"] != null) {
          state.studyPlan = List<String>.from(data["studyPlan"]);
        }
        if (data["completedTasks"] != null) {
          state.completedTasks = List<bool>.from(data["completedTasks"]);
        }
        if (data["availability"] != null) {
          final availabilityBox = PersistenceService.instance.getBox('study_availability');
          await availabilityBox.put('windows', data["availability"]);
        }
      }

      // 5. Load Study Sessions
      debugPrint("FirestoreSyncService: Fetching studySessions from users/$uid/studySessions/data...");
      final sessionsDoc = await _db.collection("users").doc(uid).collection("studySessions").doc("data").get();
      if (sessionsDoc.exists) {
        final data = sessionsDoc.data() as Map<String, dynamic>;
        if (data["sessions"] != null) {
          final sessionsBox = PersistenceService.instance.getBox('study_sessions');
          await sessionsBox.put('sessions', data["sessions"]);
        }
      }

      // 6. Load Achievements
      debugPrint("FirestoreSyncService: Fetching achievements from users/$uid/achievements/data...");
      final achievementsDoc = await _db.collection("users").doc(uid).collection("achievements").doc("data").get();
      if (achievementsDoc.exists) {
        final data = achievementsDoc.data() as Map<String, dynamic>;
        if (data["studyEvents"] != null) {
          state.studyEvents = List<Map<String, dynamic>>.from(
            (data["studyEvents"] as List).map((e) => Map<String, dynamic>.from(e as Map))
          );
        }
      }

      // 7. Load Statistics
      debugPrint("FirestoreSyncService: Fetching statistics from users/$uid/statistics/data...");
      final statisticsDoc = await _db.collection("users").doc(uid).collection("statistics").doc("data").get();
      if (statisticsDoc.exists) {
        final data = statisticsDoc.data() as Map<String, dynamic>;
        state.streakDays = data["streakDays"] ?? state.streakDays;
        state.todayEnergyValue = data["todayEnergy"] ?? state.todayEnergyValue;
        state.weeklyEnergyValue = data["weeklyEnergy"] ?? state.weeklyEnergyValue;
        state.sessionsCompleted = data["sessionsCompleted"] ?? state.sessionsCompleted;
        state.sessionsGoal = data["sessionsGoal"] ?? state.sessionsGoal;

        if (data["weeklyProgressHours"] != null) {
          final Map<String, dynamic> rawHours = data["weeklyProgressHours"];
          state.weeklyProgressHours = rawHours.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }

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
      }

      // 8. Load Settings
      debugPrint("FirestoreSyncService: Fetching settings from users/$uid/settings/data...");
      final settingsDoc = await _db.collection("users").doc(uid).collection("settings").doc("data").get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;
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

        final plannerBox = PersistenceService.instance.getBox('planner_settings');
        await plannerBox.put('breakDuration', state.plannerBreakDuration);
        await plannerBox.put('studyStyle', state.plannerStudyStyle);
        await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
        if (state.selectedDate != null) {
          await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
        }
      }

      // Save locally to SharedPreferences so the device has the cached offline copy.
      await state.saveDataLocalOnly();
      debugPrint("FirestoreSyncService: User data loaded and synced successfully from nested subcollections.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to load user data: $e");
    }
  }
}
