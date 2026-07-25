import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'study_state_manager.dart';
import 'persistence_service.dart';
import '../models/subject.dart';

class FirestoreSyncService {
  FirestoreSyncService._privateConstructor();
  static final FirestoreSyncService instance = FirestoreSyncService._privateConstructor();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
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
    final state = StudyStateManager.instance;
    
    // Track per-section loading success
    bool loadedProfile = false;
    bool loadedMascot = false;
    bool loadedSubjects = false;
    bool loadedSchedules = false;
    bool loadedSessions = false;
    bool loadedAchievements = false;
    bool loadedStatistics = false;
    bool loadedSettings = false;

    // Binary search control flags: toggle these to isolate blocks
    const bool enableProfile = true;
    const bool enableMascot = true;
    const bool enableSubjects = true;
    const bool enableSchedules = true;
    const bool enableSessions = true;
    const bool enableAchievements = true;
    const bool enableStatistics = true;
    const bool enableSettings = true;

    // Pre-fetch the flat fallback document once
    Map<String, dynamic>? flatData;
    try {
      debugPrint("INVESTIGATION: Pre-fetching flat fallback document users/$uid...");
      final flatDoc = await _db.collection("users").doc(uid).get();
      if (flatDoc.exists) {
        flatData = flatDoc.data() as Map<String, dynamic>?;
        debugPrint("INVESTIGATION: Pre-fetched flat document successfully. Keys: ${flatData?.keys}");
      }
    } catch (e, stack) {
      debugPrint("INVESTIGATION WARNING: Pre-fetching flat document failed: $e\n$stack");
    }

    // --- 1. PROFILE DETAILS ---
    if (enableProfile) {
      try {
        debugPrint("INVESTIGATION: Firebase.apps = ${Firebase.apps.map((a) => a.name).toList()}");
        if (Firebase.apps.isNotEmpty) {
          debugPrint("INVESTIGATION: Firebase.app().name = ${Firebase.app().name}");
          debugPrint("INVESTIGATION: Firebase.app().options.projectId = ${Firebase.app().options.projectId}");
          debugPrint("INVESTIGATION: Firebase.app().options.apiKey = ${Firebase.app().options.apiKey}");
        }
        debugPrint("INVESTIGATION: Current authenticated UID = $uid");
        debugPrint("INVESTIGATION: Firestore instance identity = ${_db.hashCode}");

        debugPrint("INVESTIGATION: Performing minimal reproduction test (ping query)...");
        try {
          final pingDoc = await _db.collection("test").doc("ping").get();
          debugPrint("INVESTIGATION: Ping document exists: ${pingDoc.exists}");
        } catch (pingErr, pingStack) {
          debugPrint("INVESTIGATION ERROR: Ping query failed: $pingErr\n$pingStack");
        }

        debugPrint("INVESTIGATION: Loading Profile Details from users/$uid/profile/details...");
        final detailsDoc = await _db.collection("users").doc(uid).collection("profile").doc("details").get();
        debugPrint("INVESTIGATION: Profile details document exists: ${detailsDoc.exists}");
        
        if (detailsDoc.exists) {
          final profileData = detailsDoc.data() as Map<String, dynamic>;
          debugPrint("INVESTIGATION: Profile Details keys: ${profileData.keys}");
          profileData.forEach((key, value) {
            debugPrint("INVESTIGATION: Field '$key' -> value: $value, runtimeType: ${value.runtimeType}");
          });

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
          state.userAge = (profileData["user_age"] as num?)?.toInt() ?? state.userAge;
          state.userCourse = profileData["user_course"] ?? state.userCourse;
          state.userYear = profileData["user_year"] ?? state.userYear;
          state.onboardingStrategy = profileData["onboarding_strategy"] ?? state.onboardingStrategy;
          
          loadedProfile = true;
          debugPrint("INVESTIGATION: Loaded Profile Details successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("FirestoreSyncService WARNING: Subcollection Profile read failed: $e\n$stack");
        syncErrors.add("Subcollection Profile read warning: $e\n$stack");
      }
    }

    if (!loadedProfile && flatData != null && flatData["profile"] != null) {
      try {
        final profile = flatData["profile"] as Map<String, dynamic>;
        state.userName = profile["displayName"] ?? state.userName;
        state.userEmail = profile["email"] ?? state.userEmail;
        state.onboardingCompleted = profile["onboardingCompleted"] ?? false;
        if (state.onboardingCompleted) {
          state.isProfileSetup = true;
          state.onboarded = true;
        }
        if (state.userPhotoUrl.isEmpty) state.userPhotoUrl = profile["photoURL"] ?? "";
        state.userAge = (profile["user_age"] as num?)?.toInt() ?? state.userAge;
        state.userCourse = profile["user_course"] ?? state.userCourse;
        state.userYear = profile["user_year"] ?? state.userYear;
        state.onboardingStrategy = profile["onboarding_strategy"] ?? state.onboardingStrategy;
        loadedProfile = true;
        debugPrint("INVESTIGATION: Restored Profile details from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Profile from flat fallback: $e");
      }
    }

    // --- 2. SELECTED MASCOT ---
    if (enableMascot) {
      try {
        debugPrint("INVESTIGATION: Loading Mascot from users/$uid/profile/selectedMascot...");
        final mascotDoc = await _db.collection("users").doc(uid).collection("profile").doc("selectedMascot").get();
        debugPrint("INVESTIGATION: Mascot document exists: ${mascotDoc.exists}");
        if (mascotDoc.exists) {
          final data = mascotDoc.data()!;
          state.userMascot = data["selectedMascot"] ?? state.userMascot;
          loadedMascot = true;
          debugPrint("INVESTIGATION: Loaded Mascot successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Mascot read failed: $e\n$stack");
      }
    }

    if (!loadedMascot && flatData != null && flatData["selectedMascot"] != null) {
      state.userMascot = flatData["selectedMascot"] ?? state.userMascot;
      loadedMascot = true;
      debugPrint("INVESTIGATION: Restored Mascot from flat document.");
    }

    // --- 3. SUBJECTS ---
    if (enableSubjects) {
      try {
        debugPrint("INVESTIGATION: Loading Subjects from users/$uid/subjects/data...");
        final subjectsDoc = await _db.collection("users").doc(uid).collection("subjects").doc("data").get();
        debugPrint("INVESTIGATION: Subjects document exists: ${subjectsDoc.exists}");
        if (subjectsDoc.exists && subjectsDoc.data()?["subjects"] != null) {
          final data = subjectsDoc.data()!;
          final List<dynamic> subsJson = data["subjects"];
          state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          loadedSubjects = true;
          debugPrint("INVESTIGATION: Loaded Subjects successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Subjects read failed: $e\n$stack");
      }
    }

    if (!loadedSubjects && flatData != null && flatData["subjects"] != null && flatData["subjects"]["subjects"] != null) {
      try {
        final List<dynamic> subsJson = flatData["subjects"]["subjects"];
        state.subjects = subsJson.map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        loadedSubjects = true;
        debugPrint("INVESTIGATION: Restored Subjects from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Subjects from flat fallback: $e");
      }
    }

    // --- 4. SCHEDULES ---
    if (enableSchedules) {
      try {
        debugPrint("INVESTIGATION: Loading Schedules from users/$uid/schedules/data...");
        final schedulesDoc = await _db.collection("users").doc(uid).collection("schedules").doc("data").get();
        debugPrint("INVESTIGATION: Schedules document exists: ${schedulesDoc.exists}");
        if (schedulesDoc.exists) {
          final data = schedulesDoc.data()!;
          if (data["studyPlan"] != null) state.studyPlan = List<String>.from(data["studyPlan"]);
          if (data["completedTasks"] != null) state.completedTasks = List<bool>.from(data["completedTasks"]);
          if (data["availability"] != null) {
            final availabilityBox = PersistenceService.instance.getBox('study_availability');
            await availabilityBox.put('windows', data["availability"]);
          }
          loadedSchedules = true;
          debugPrint("INVESTIGATION: Loaded Schedules successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Schedules read failed: $e\n$stack");
      }
    }

    if (!loadedSchedules && flatData != null && flatData["schedules"] != null) {
      try {
        final schedules = flatData["schedules"] as Map<String, dynamic>;
        if (schedules["studyPlan"] != null) state.studyPlan = List<String>.from(schedules["studyPlan"]);
        if (schedules["completedTasks"] != null) state.completedTasks = List<bool>.from(schedules["completedTasks"]);
        if (schedules["availability"] != null) {
          final availabilityBox = PersistenceService.instance.getBox('study_availability');
          await availabilityBox.put('windows', schedules["availability"]);
        }
        loadedSchedules = true;
        debugPrint("INVESTIGATION: Restored Schedules from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Schedules from flat fallback: $e");
      }
    }

    // --- 5. STUDY SESSIONS ---
    if (enableSessions) {
      try {
        debugPrint("INVESTIGATION: Loading Sessions from users/$uid/studySessions/data...");
        final sessionsDoc = await _db.collection("users").doc(uid).collection("studySessions").doc("data").get();
        debugPrint("INVESTIGATION: Sessions document exists: ${sessionsDoc.exists}");
        if (sessionsDoc.exists && sessionsDoc.data()?["sessions"] != null) {
          final data = sessionsDoc.data()!;
          final sessionsBox = PersistenceService.instance.getBox('study_sessions');
          await sessionsBox.put('sessions', data["sessions"]);
          loadedSessions = true;
          debugPrint("INVESTIGATION: Loaded Sessions successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Sessions read failed: $e\n$stack");
      }
    }

    if (!loadedSessions && flatData != null && flatData["studySessions"] != null && flatData["studySessions"]["sessions"] != null) {
      try {
        final sessionsBox = PersistenceService.instance.getBox('study_sessions');
        await sessionsBox.put('sessions', flatData["studySessions"]["sessions"]);
        loadedSessions = true;
        debugPrint("INVESTIGATION: Restored Sessions from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Sessions from flat fallback: $e");
      }
    }

    // --- 6. ACHIEVEMENTS ---
    if (enableAchievements) {
      try {
        debugPrint("INVESTIGATION: Loading Achievements from users/$uid/achievements/data...");
        final achievementsDoc = await _db.collection("users").doc(uid).collection("achievements").doc("data").get();
        debugPrint("INVESTIGATION: Achievements document exists: ${achievementsDoc.exists}");
        if (achievementsDoc.exists && achievementsDoc.data()?["studyEvents"] != null) {
          final data = achievementsDoc.data()!;
          state.studyEvents = List<Map<String, dynamic>>.from(
            (data["studyEvents"] as List).map((e) => Map<String, dynamic>.from(e as Map))
          );
          loadedAchievements = true;
          debugPrint("INVESTIGATION: Loaded Achievements successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Achievements read failed: $e\n$stack");
      }
    }

    if (!loadedAchievements && flatData != null && flatData["achievements"] != null && flatData["achievements"]["studyEvents"] != null) {
      try {
        state.studyEvents = List<Map<String, dynamic>>.from(
          (flatData["achievements"]["studyEvents"] as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
        loadedAchievements = true;
        debugPrint("INVESTIGATION: Restored Achievements from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Achievements from flat fallback: $e");
      }
    }

    // --- 7. STATISTICS ---
    if (enableStatistics) {
      try {
        debugPrint("INVESTIGATION: Loading Statistics from users/$uid/statistics/data...");
        final statisticsDoc = await _db.collection("users").doc(uid).collection("statistics").doc("data").get();
        debugPrint("INVESTIGATION: Statistics document exists: ${statisticsDoc.exists}");
        if (statisticsDoc.exists) {
          final data = statisticsDoc.data()!;
          state.streakDays = (data["streakDays"] as num?)?.toInt() ?? state.streakDays;
          state.todayEnergyValue = (data["todayEnergy"] as num?)?.toInt() ?? state.todayEnergyValue;
          state.weeklyEnergyValue = (data["weeklyEnergy"] as num?)?.toInt() ?? state.weeklyEnergyValue;
          state.sessionsCompleted = (data["sessionsCompleted"] as num?)?.toInt() ?? state.sessionsCompleted;
          state.sessionsGoal = (data["sessionsGoal"] as num?)?.toInt() ?? state.sessionsGoal;
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
          loadedStatistics = true;
          debugPrint("INVESTIGATION: Loaded Statistics successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Statistics read failed: $e\n$stack");
      }
    }

    if (!loadedStatistics && flatData != null && flatData["statistics"] != null) {
      try {
        final stats = flatData["statistics"] as Map<String, dynamic>;
        state.streakDays = (stats["streakDays"] as num?)?.toInt() ?? state.streakDays;
        state.todayEnergyValue = (stats["todayEnergy"] as num?)?.toInt() ?? state.todayEnergyValue;
        state.weeklyEnergyValue = (stats["weeklyEnergy"] as num?)?.toInt() ?? state.weeklyEnergyValue;
        state.sessionsCompleted = (stats["sessionsCompleted"] as num?)?.toInt() ?? state.sessionsCompleted;
        state.sessionsGoal = (stats["sessionsGoal"] as num?)?.toInt() ?? state.sessionsGoal;
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
        loadedStatistics = true;
        debugPrint("INVESTIGATION: Restored Statistics from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Statistics from flat fallback: $e");
      }
    }

    // --- 8. PLANNER SETTINGS ---
    if (enableSettings) {
      try {
        debugPrint("INVESTIGATION: Loading Settings from users/$uid/settings/data...");
        final settingsDoc = await _db.collection("users").doc(uid).collection("settings").doc("data").get();
        debugPrint("INVESTIGATION: Settings document exists: ${settingsDoc.exists}");
        if (settingsDoc.exists) {
          final data = settingsDoc.data()!;
          state.plannerHoursPerDay = (data["planner_hours_per_day"] as num?)?.toInt() ?? state.plannerHoursPerDay;
          state.plannerStudyStyle = data["planner_study_style"] ?? state.plannerStudyStyle;
          state.plannerBreakDuration = (data["planner_break_duration"] as num?)?.toInt() ?? state.plannerBreakDuration;
          state.plannerDifficultyPref = data["planner_difficulty_pref"] ?? state.plannerDifficultyPref;
          state.plannerPreferredTime = data["planner_preferred_time"] ?? state.plannerPreferredTime;
          if (data["examDate"] != null) state.selectedDate = DateTime.tryParse(data["examDate"]);
          state.selectedDifficulty = data["difficulty"] ?? state.selectedDifficulty;
          state.studyRoomSelectedSubject = data["sr_selected_subject"] ?? state.studyRoomSelectedSubject;
          state.studyRoomDurationMinutes = (data["sr_duration_minutes"] as num?)?.toInt() ?? state.studyRoomDurationMinutes;
          state.studyRoomActiveTopic = data["sr_active_topic"] ?? state.studyRoomActiveTopic;

          final plannerBox = PersistenceService.instance.getBox('planner_settings');
          await plannerBox.put('breakDuration', state.plannerBreakDuration);
          await plannerBox.put('studyStyle', state.plannerStudyStyle);
          await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
          if (state.selectedDate != null) await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
          loadedSettings = true;
          debugPrint("INVESTIGATION: Loaded Settings successfully from subcollection.");
        }
      } catch (e, stack) {
        debugPrint("INVESTIGATION ERROR: Settings read failed: $e\n$stack");
      }
    }

    if (!loadedSettings && flatData != null && flatData["settings"] != null) {
      try {
        final settings = flatData["settings"] as Map<String, dynamic>;
        state.plannerHoursPerDay = (settings["planner_hours_per_day"] as num?)?.toInt() ?? state.plannerHoursPerDay;
        state.plannerStudyStyle = settings["planner_study_style"] ?? state.plannerStudyStyle;
        state.plannerBreakDuration = (settings["planner_break_duration"] as num?)?.toInt() ?? state.plannerBreakDuration;
        state.plannerDifficultyPref = settings["planner_difficulty_pref"] ?? state.plannerDifficultyPref;
        state.plannerPreferredTime = settings["planner_preferred_time"] ?? state.plannerPreferredTime;
        if (settings["examDate"] != null) state.selectedDate = DateTime.tryParse(settings["examDate"]);
        state.selectedDifficulty = settings["difficulty"] ?? state.selectedDifficulty;
        state.studyRoomSelectedSubject = settings["sr_selected_subject"] ?? state.studyRoomSelectedSubject;
        state.studyRoomDurationMinutes = (settings["sr_duration_minutes"] as num?)?.toInt() ?? state.studyRoomDurationMinutes;
        state.studyRoomActiveTopic = settings["sr_active_topic"] ?? state.studyRoomActiveTopic;

        final plannerBox = PersistenceService.instance.getBox('planner_settings');
        await plannerBox.put('breakDuration', state.plannerBreakDuration);
        await plannerBox.put('studyStyle', state.plannerStudyStyle);
        await plannerBox.put('difficultyPref', state.plannerDifficultyPref);
        if (state.selectedDate != null) await plannerBox.put('examDate', state.selectedDate!.toIso8601String());
        loadedSettings = true;
        debugPrint("INVESTIGATION: Restored Settings from flat document.");
      } catch (e) {
        debugPrint("INVESTIGATION ERROR: Failed to restore Settings from flat fallback: $e");
      }
    }

    // Determine fallback/overall load state
    bool anyLoaded = loadedProfile || loadedMascot || loadedSubjects || loadedSchedules || loadedSessions || loadedAchievements || loadedStatistics || loadedSettings;

    if (!anyLoaded) {
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
