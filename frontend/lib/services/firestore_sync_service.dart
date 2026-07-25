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
  static final List<String> syncErrors = [];

  /// Saves the user state map to Firestore under both nested subcollections and a flat fallback map.
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

      // 1. Prepare data segments
      final String nowStr = DateTime.now().toIso8601String();

      final Map<String, dynamic> profileDetails = {
        "displayName": state.userName,
        "email": state.userEmail,
        "photoURL": state.userPhotoUrl,
        "onboardingCompleted": state.onboardingCompleted,
        "user_age": state.userAge,
        "user_course": state.userCourse,
        "user_year": state.userYear,
        "onboarding_strategy": state.onboardingStrategy,
        "updatedAt": nowStr,
      };

      final Map<String, dynamic> subjectsData = {
        "subjects": state.subjects.map((e) => e.toJson()).toList(),
        "updatedAt": nowStr,
      };

      final Map<String, dynamic> schedulesData = {
        "studyPlan": state.studyPlan,
        "completedTasks": state.completedTasks,
        "availability": availabilityList,
        "updatedAt": nowStr,
      };

      final Map<String, dynamic> sessionsData = {
        "sessions": sessionsList,
        "updatedAt": nowStr,
      };

      final Map<String, dynamic> achievementsData = {
        "studyEvents": state.studyEvents,
        "updatedAt": nowStr,
      };

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
        "updatedAt": nowStr,
      };

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
        "updatedAt": nowStr,
      };

      // --- SAVE TO NESTED SUBCOLLECTIONS ---
      try {
        debugPrint("FirestoreSyncService: Saving to nested subcollections...");
        await _db.collection("users").doc(uid).collection("profile").doc("details").set(profileDetails, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").set({"selectedMascot": state.userMascot}, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("subjects").doc("data").set(subjectsData, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("schedules").doc("data").set(schedulesData, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("studySessions").doc("data").set(sessionsData, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("achievements").doc("data").set(achievementsData, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("statistics").doc("data").set(statisticsData, SetOptions(merge: true));
        await _db.collection("users").doc(uid).collection("settings").doc("data").set(settingsData, SetOptions(merge: true));
        debugPrint("FirestoreSyncService: Nested subcollections saved successfully.");
      } catch (e) {
        debugPrint("FirestoreSyncService WARNING: Subcollection save failed (likely Firestore rules restriction): $e");
        syncErrors.add("Subcollection save warning: $e");
      }

      // --- SAVE TO FLAT USER DOCUMENT (FAIL-SAFE FALLBACK) ---
      try {
        debugPrint("FirestoreSyncService: Saving fallback data to flat user document users/$uid...");
        final Map<String, dynamic> flatData = {
          "profile": profileDetails,
          "selectedMascot": state.userMascot,
          "subjects": subjectsData,
          "schedules": schedulesData,
          "studySessions": sessionsData,
          "achievements": achievementsData,
          "statistics": statisticsData,
          "settings": settingsData,
          "onboardingCompleted": state.onboardingCompleted,
          "updatedAt": nowStr,
        };
        await _db.collection("users").doc(uid).set(flatData, SetOptions(merge: true));
        debugPrint("FirestoreSyncService: Flat fallback document saved successfully.");
      } catch (e) {
        debugPrint("FirestoreSyncService ERROR: Flat fallback document save failed: $e");
        syncErrors.add("Flat save error: $e");
      }
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to prepare user data: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Updates only the selectedMascot field in Firestore.
  Future<void> saveMascot(String uid, String mascot) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").set({
        "selectedMascot": mascot,
      }, SetOptions(merge: true));
    } catch (_) {}

    try {
      await _db.collection("users").doc(uid).set({
        "selectedMascot": mascot,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Loads user data. Tries subcollections first, then falls back to the flat user document to bypass any strict Firestore rules.
  Future<void> loadUserData(String uid) async {
    if (uid.isEmpty) return;

    final state = StudyStateManager.instance;
    bool loadedFromSubcollections = false;
    bool loadedFromFlat = false;

    // --- TRY NESTED SUBCOLLECTIONS ---
    try {
      debugPrint("FirestoreSyncService: Fetching profile details from users/$uid/profile/details...");
      final detailsDoc = await _db.collection("users").doc(uid).collection("profile").doc("details").get();
      
      if (detailsDoc.exists) {
        final profileData = detailsDoc.data() as Map<String, dynamic>;
        state.userName = profileData["displayName"] ?? state.userName;
        state.userEmail = profileData["email"] ?? state.userEmail;
        state.onboardingCompleted = profileData["onboardingCompleted"] ?? false;
        
        if (state.onboardingCompleted) {
          state.isProfileSetup = true;
          state.onboarded = true;
        }
        if (state.userPhotoUrl.isEmpty) {
          state.userPhotoUrl = profileData["photoURL"] ?? "";
        }
        state.userAge = profileData["user_age"] ?? state.userAge;
        state.userCourse = profileData["user_course"] ?? state.userCourse;
        state.userYear = profileData["user_year"] ?? state.userYear;
        state.onboardingStrategy = profileData["onboarding_strategy"] ?? state.onboardingStrategy;
        
        loadedFromSubcollections = true;
        debugPrint("FirestoreSyncService: Loaded profile successfully from subcollections.");
      }
    } catch (e) {
      debugPrint("FirestoreSyncService WARNING: Subcollection read failed (likely rule restriction): $e");
      syncErrors.add("Subcollection read warning: $e");
    }

    if (loadedFromSubcollections) {
      try {
        final mascotDoc = await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").get();
        if (mascotDoc.exists) {
          state.userMascot = mascotDoc.data()?["selectedMascot"] ?? state.userMascot;
        }
      } catch (_) {}

      try {
        final subjectsDoc = await _db.collection("users").doc(uid).collection("subjects").doc("data").get();
        if (subjectsDoc.exists && subjectsDoc.data()?["subjects"] != null) {
          final List<dynamic> subsJson = subjectsDoc.data()!["subjects"];
          state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        }
      } catch (_) {}

      try {
        final schedulesDoc = await _db.collection("users").doc(uid).collection("schedules").doc("data").get();
        if (schedulesDoc.exists) {
          final data = schedulesDoc.data()!;
          if (data["studyPlan"] != null) state.studyPlan = List<String>.from(data["studyPlan"]);
          if (data["completedTasks"] != null) state.completedTasks = List<bool>.from(data["completedTasks"]);
          if (data["availability"] != null) {
            final availabilityBox = PersistenceService.instance.getBox('study_availability');
            await availabilityBox.put('windows', data["availability"]);
          }
        }
      } catch (_) {}

      try {
        final sessionsDoc = await _db.collection("users").doc(uid).collection("studySessions").doc("data").get();
        if (sessionsDoc.exists && sessionsDoc.data()?["sessions"] != null) {
          final sessionsBox = PersistenceService.instance.getBox('study_sessions');
          await sessionsBox.put('sessions', sessionsDoc.data()!["sessions"]);
        }
      } catch (_) {}

      try {
        final achievementsDoc = await _db.collection("users").doc(uid).collection("achievements").doc("data").get();
        if (achievementsDoc.exists && achievementsDoc.data()?["studyEvents"] != null) {
          state.studyEvents = List<Map<String, dynamic>>.from(
            (achievementsDoc.data()!["studyEvents"] as List).map((e) => Map<String, dynamic>.from(e as Map))
          );
        }
      } catch (_) {}

      try {
        final statisticsDoc = await _db.collection("users").doc(uid).collection("statistics").doc("data").get();
        if (statisticsDoc.exists) {
          final data = statisticsDoc.data()!;
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
      } catch (_) {}

      try {
        final settingsDoc = await _db.collection("users").doc(uid).collection("settings").doc("data").get();
        if (settingsDoc.exists) {
          final data = settingsDoc.data()!;
          state.plannerHoursPerDay = data["planner_hours_per_day"] ?? state.plannerHoursPerDay;
          state.plannerStudyStyle = data["planner_study_style"] ?? state.plannerStudyStyle;
          state.plannerBreakDuration = data["planner_break_duration"] ?? state.plannerBreakDuration;
          state.plannerDifficultyPref = data["planner_difficulty_pref"] ?? state.plannerDifficultyPref;
          state.plannerPreferredTime = data["planner_preferred_time"] ?? state.plannerPreferredTime;
          if (data["examDate"] != null) state.selectedDate = DateTime.tryParse(data["examDate"]);
          state.selectedDifficulty = data["difficulty"] ?? state.selectedDifficulty;
          state.studyRoomSelectedSubject = data["sr_selected_subject"] ?? state.studyRoomSelectedSubject;
          state.studyRoomDurationMinutes = data["sr_duration_minutes"] ?? state.studyRoomDurationMinutes;
          state.studyRoomActiveTopic = data["sr_active_topic"] ?? state.studyRoomActiveTopic;

          final plannerBox = PersistenceService.instance.getBox('planner_settings');
          await plannerBox.put('breakDuration', state.plannerBreakDuration);
          await plannerBox.put('studyStyle', state.plannerStudyStyle);
          await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
          if (state.selectedDate != null) await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
        }
      } catch (_) {}
    } else {
      // --- TRY FLAT FALLBACK DOCUMENT ---
      try {
        debugPrint("FirestoreSyncService: Falling back to fetch flat root document users/$uid...");
        final doc = await _db.collection("users").doc(uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;

          // Restore Profile details
          if (data["profile"] != null) {
            final profile = data["profile"] as Map<String, dynamic>;
            state.userName = profile["displayName"] ?? state.userName;
            state.userEmail = profile["email"] ?? state.userEmail;
            state.onboardingCompleted = profile["onboardingCompleted"] ?? false;
            if (state.onboardingCompleted) {
              state.isProfileSetup = true;
              state.onboarded = true;
            }
            if (state.userPhotoUrl.isEmpty) state.userPhotoUrl = profile["photoURL"] ?? "";
            state.userAge = profile["user_age"] ?? state.userAge;
            state.userCourse = profile["user_course"] ?? state.userCourse;
            state.userYear = profile["user_year"] ?? state.userYear;
            state.onboardingStrategy = profile["onboarding_strategy"] ?? state.onboardingStrategy;
          } else {
            state.onboardingCompleted = data["onboardingCompleted"] ?? false;
            if (state.onboardingCompleted) {
              state.isProfileSetup = true;
              state.onboarded = true;
            }
          }

          state.userMascot = data["selectedMascot"] ?? state.userMascot;

          // Restore Subjects
          if (data["subjects"] != null && data["subjects"]["subjects"] != null) {
            final List<dynamic> subsJson = data["subjects"]["subjects"];
            state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }

          // Restore Schedules
          if (data["schedules"] != null) {
            final schedules = data["schedules"] as Map<String, dynamic>;
            if (schedules["studyPlan"] != null) state.studyPlan = List<String>.from(schedules["studyPlan"]);
            if (schedules["completedTasks"] != null) state.completedTasks = List<bool>.from(schedules["completedTasks"]);
            if (schedules["availability"] != null) {
              final availabilityBox = PersistenceService.instance.getBox('study_availability');
              await availabilityBox.put('windows', schedules["availability"]);
            }
          }

          // Restore Sessions
          if (data["studySessions"] != null && data["studySessions"]["sessions"] != null) {
            final sessionsBox = PersistenceService.instance.getBox('study_sessions');
            await sessionsBox.put('sessions', data["studySessions"]["sessions"]);
          }

          // Restore Achievements
          if (data["achievements"] != null && data["achievements"]["studyEvents"] != null) {
            state.studyEvents = List<Map<String, dynamic>>.from(
              (data["achievements"]["studyEvents"] as List).map((e) => Map<String, dynamic>.from(e as Map))
            );
          }

          // Restore Statistics
          if (data["statistics"] != null) {
            final stats = data["statistics"] as Map<String, dynamic>;
            state.streakDays = stats["streakDays"] ?? state.streakDays;
            state.todayEnergyValue = stats["todayEnergy"] ?? state.todayEnergyValue;
            state.weeklyEnergyValue = stats["weeklyEnergy"] ?? state.weeklyEnergyValue;
            state.sessionsCompleted = stats["sessionsCompleted"] ?? state.sessionsCompleted;
            state.sessionsGoal = stats["sessionsGoal"] ?? state.sessionsGoal;
            if (stats["weeklyProgressHours"] != null) {
              final Map<String, dynamic> rawHours = stats["weeklyProgressHours"];
              state.weeklyProgressHours = rawHours.map((k, v) => MapEntry(k, (v as num).toDouble()));
            }
            final crystalBox = PersistenceService.instance.getBox('crystal_progress');
            await crystalBox.put('focusProgress', (stats["crystal_focus_progress"] as num?)?.toDouble() ?? 0.0);
            await crystalBox.put('wisdomProgress', (stats["crystal_wisdom_progress"] as num?)?.toDouble() ?? 0.0);
            await crystalBox.put('masteryProgress', (stats["crystal_mastery_progress"] as num?)?.toDouble() ?? 0.0);

            final statisticsBox = PersistenceService.instance.getBox('study_statistics');
            await statisticsBox.put('streakDays', state.streakDays);
            await statisticsBox.put('todayEnergy', state.todayEnergyValue);
            await statisticsBox.put('weeklyEnergy', state.weeklyEnergyValue);
            await statisticsBox.put('sessionsCompleted', state.sessionsCompleted);
            await statisticsBox.put('sessionsGoal', state.sessionsGoal);
            await statisticsBox.put('weeklyProgress', state.weeklyProgressHours);
          }

          // Restore Settings
          if (data["settings"] != null) {
            final settings = data["settings"] as Map<String, dynamic>;
            state.plannerHoursPerDay = settings["planner_hours_per_day"] ?? state.plannerHoursPerDay;
            state.plannerStudyStyle = settings["planner_study_style"] ?? state.plannerStudyStyle;
            state.plannerBreakDuration = settings["planner_break_duration"] ?? state.plannerBreakDuration;
            state.plannerDifficultyPref = settings["planner_difficulty_pref"] ?? state.plannerDifficultyPref;
            state.plannerPreferredTime = settings["planner_preferred_time"] ?? state.plannerPreferredTime;
            if (settings["examDate"] != null) state.selectedDate = DateTime.tryParse(settings["examDate"]);
            state.selectedDifficulty = settings["difficulty"] ?? state.selectedDifficulty;
            state.studyRoomSelectedSubject = settings["sr_selected_subject"] ?? state.studyRoomSelectedSubject;
            state.studyRoomDurationMinutes = settings["sr_duration_minutes"] ?? state.studyRoomDurationMinutes;
            state.studyRoomActiveTopic = settings["sr_active_topic"] ?? state.studyRoomActiveTopic;

            final plannerBox = PersistenceService.instance.getBox('planner_settings');
            await plannerBox.put('breakDuration', state.plannerBreakDuration);
            await plannerBox.put('studyStyle', state.plannerStudyStyle);
            await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
            if (state.selectedDate != null) await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
          }

          loadedFromFlat = true;
          debugPrint("FirestoreSyncService: Loaded user data from flat fallback successfully.");
        }
      } catch (e) {
        debugPrint("FirestoreSyncService ERROR: Failed to load user data from flat document fallback: $e");
        syncErrors.add("Flat read error: $e");
      }
    }

    if (!loadedFromSubcollections && !loadedFromFlat) {
      debugPrint("FirestoreSyncService: No user data found. Treating as new user.");
      state.onboardingCompleted = false;
      state.isProfileSetup = false;
      state.onboarded = false;
      return;
    }

    // Save locally to SharedPreferences so the device has the cached offline copy.
    try {
      await state.saveDataLocalOnly();
      debugPrint("FirestoreSyncService: Local SharedPreferences updated.");
    } catch (e) {
      debugPrint("FirestoreSyncService ERROR: Failed to save cached local copy: $e");
    }
  }

  /// Force deletes/resets all documents under users/{uid} to clear old corrupted FieldValue.serverTimestamp() objects.
  Future<void> forceResetCloudData(String uid) async {
    if (uid.isEmpty) return;
    debugPrint("FirestoreSyncService: Performing force reset of cloud data for $uid...");
    // 1. Delete nested subcollection documents
    await _db.collection("users").doc(uid).collection("profile").doc("details").delete();
    await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").delete();
    await _db.collection("users").doc(uid).collection("subjects").doc("data").delete();
    await _db.collection("users").doc(uid).collection("schedules").doc("data").delete();
    await _db.collection("users").doc(uid).collection("studySessions").doc("data").delete();
    await _db.collection("users").doc(uid).collection("achievements").doc("data").delete();
    await _db.collection("users").doc(uid).collection("statistics").doc("data").delete();
    await _db.collection("users").doc(uid).collection("settings").doc("data").delete();
    // 2. Delete the flat root document
    await _db.collection("users").doc(uid).delete();
    debugPrint("FirestoreSyncService: Force reset completed successfully.");
  }
}
