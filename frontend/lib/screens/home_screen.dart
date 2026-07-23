import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/study_timer_sheet.dart';
import '../models/subject.dart';
import '../models/study_availability.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import '../services/study_state_manager.dart';
import 'tasks_tab_screen.dart';
import '../widgets/global_eggy.dart';
import 'energy_chamber_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();

  List<Subject> subjects = [];
  List<String> studyPlan = [];
  List<bool> completedTasks = [];

  Map<String, double> weeklyProgressHours = {
    "Mon": 0.0,
    "Tue": 0.0,
    "Wed": 0.0,
    "Thu": 0.0,
    "Fri": 0.0,
    "Sat": 0.0,
    "Sun": 0.0,
  };

  String selectedDifficulty = "Medium";
  DateTime? selectedDate;
  int _currentTab = 0;
  bool _isLoading = false;

  // Planner Setup - local UI state only (not sent to backend yet)
  String _plannerStudyStyle = "Balanced";
  int _plannerBreakDuration = 10;
  String _plannerDifficultyPref = "Moderate";
  String _plannerPreferredTime = "Morning";
  int _plannerHoursPerDay = 4; // stepper - synced with hoursController
  String _selectedPlannerDay = "Mon";

  String userCourse = "";
  String userYear = "";
  String onboardingStrategy = "";
  String userName = "";
  String userMascot = "assets/images/mascot_boy.png";

  // Pomodoro Focus Timer states
  bool isTimerRunning = false;
  bool isBreakTime = false;
  int pomodoroDurationSeconds = 1500; // 25 mins by default
  int pomodoroSecondsRemaining = 1500;
  Timer? pomodoroTimer;

  // Toggle Period state
  String selectedPeriod = 'Weekly';

  // Pomodoro Focus stats
  int completedPomodorosToday = 3;
  double totalFocusHoursToday = 1.5;
  String activePresetProfile = '25m';
  final ScrollController _scrollController = ScrollController();
  String? activeTaskName;
  int breakDurationSeconds = 300; // default 5 mins
  int? activeTaskWorkMinutes;
  int? activeTaskBreakMinutes;

  // Subjects search and loading state
  String _subjectSearchQuery = "";
  bool _isAddingSubject = false;
  bool _showAddSubjectForm = false;
  final Set<int> _expandedSubjectIndices = {};
  final Set<String> _expandedChapterKeys = {};
  String _subjectsFilter = "All";
  String _subjectsSort = "Recent";
  bool _isSearchFocused = false;

  // Study Room state variables
  String _studyRoomSelectedSubject = "General Study";
  int _studyRoomDurationMinutes = 25;
  bool _studyRoomIsTimerActive = false;
  bool _studyRoomIsPaused = false;
  int _studyRoomSecondsRemaining = 1500;
  Timer? _studyRoomTimer;
  String _studyRoomActiveTopic = "Focus Session";

  @override
  void initState() {
    super.initState();
    StudyStateManager.instance.addListener(_onStateChanged);
    _onStateChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        EggyController.instance.isVisible = true;
        EggyController.instance.currentTab = _currentTab;
      }
    });
  }

  @override
  void dispose() {
    StudyStateManager.instance.removeListener(_onStateChanged);
    pomodoroTimer?.cancel();
    _studyRoomTimer?.cancel();
    subjectController.dispose();
    hoursController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = StudyStateManager.instance;
    setState(() {
      subjects = state.subjects;
      studyPlan = state.studyPlan;
      completedTasks = state.completedTasks;
      weeklyProgressHours = state.weeklyProgressHours;
      selectedDifficulty = state.selectedDifficulty;
      selectedDate = state.selectedDate;
      userName = state.userName;
      userCourse = state.userCourse;
      userYear = state.userYear;
      userMascot = state.userMascot;
      onboardingStrategy = state.onboardingStrategy;
      hoursController.text = state.plannerHoursPerDay.toString();
      _plannerHoursPerDay = state.plannerHoursPerDay;
      _plannerStudyStyle = state.plannerStudyStyle;
      _plannerBreakDuration = state.plannerBreakDuration;
      _plannerDifficultyPref = state.plannerDifficultyPref;
      _plannerPreferredTime = state.plannerPreferredTime;
    });
  }

  void _updateSettings({int? hours, String? style, int? breakDuration, String? difficulty, String? preferredTime}) {
    StudyStateManager.instance.updatePlannerSettings(
      hours: hours ?? StudyStateManager.instance.plannerHoursPerDay,
      style: style ?? StudyStateManager.instance.plannerStudyStyle,
      breakDuration: breakDuration ?? StudyStateManager.instance.plannerBreakDuration,
      difficulty: difficulty ?? StudyStateManager.instance.plannerDifficultyPref,
      preferredTime: preferredTime ?? StudyStateManager.instance.plannerPreferredTime,
    );
  }

  Future<void> saveData() async {
    await StudyStateManager.instance.saveData();
  }

  Future<void> loadData() async {
    await StudyStateManager.instance.init();
    _onStateChanged();
  }

  double getProgress() {
    if (completedTasks.isEmpty) {
      return 0.0;
    }
    int completed = completedTasks.where((task) => task).length;
    return completed / completedTasks.length;
  }

  int getDaysLeft() {
    if (selectedDate == null) return 0;
    final diff = selectedDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      await StudyStateManager.instance.updatePlannerSettings(
        hours: StudyStateManager.instance.plannerHoursPerDay,
        style: StudyStateManager.instance.plannerStudyStyle,
        breakDuration: StudyStateManager.instance.plannerBreakDuration,
        difficulty: StudyStateManager.instance.plannerDifficultyPref,
        preferredTime: StudyStateManager.instance.plannerPreferredTime,
        examDate: picked,
      );
    }
  }

  Future<void> _deleteSubject(int index) async {
    await StudyStateManager.instance.deleteSubject(index);
  }

  void _addTask(String subject, String difficulty, int duration, {int? dayIndex}) {
    StudyStateManager.instance.addTask(subject, difficulty, duration, dayIndex: dayIndex);
  }

  void _deleteTask(int index) {
    StudyStateManager.instance.deleteTask(index);
  }

  void _editTask(int index, String subject, String difficulty, String hours) {
    StudyStateManager.instance.editTask(index, subject, difficulty, hours);
  }

  Widget _buildPremiumStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateRecommendations() {
    final state = StudyStateManager.instance;
    final stats = state.statistics;
    final List<Map<String, dynamic>> list = [];

    // 1. Continue session (from Study Plan or Subjects list)
    String continueSubject = "Data Structures";
    String continueTopic = "Binary Trees";
    if (state.subjects.isNotEmpty) {
      final incompleteSubj = state.subjects.firstWhere(
        (s) => s.topics.any((t) => !t.isCompleted),
        orElse: () => state.subjects.first,
      );
      continueSubject = incompleteSubj.name;
      if (incompleteSubj.topics.isNotEmpty) {
        final incompleteTopic = incompleteSubj.topics.firstWhere(
          (t) => !t.isCompleted,
          orElse: () => incompleteSubj.topics.first,
        );
        continueTopic = incompleteTopic.name;
      }
    } else if (state.studyPlan.isNotEmpty) {
      final parsed = state.parsePlanItem(state.studyPlan.first);
      continueSubject = parsed['subject'] ?? 'Data Structures';
      continueTopic = "Core Chapters";
    }
    list.add({
      'type': 'continue',
      'icon': Icons.book_rounded,
      'iconColor': const Color(0xFF3B82F6),
      'title': 'Continue',
      'content': '$continueSubject ($continueTopic)',
    });

    // 2. Revision due
    String revisionSubject = "Operating Systems";
    if (state.subjects.length > 1) {
      final revSubj = state.subjects.firstWhere(
        (s) => s.name != continueSubject,
        orElse: () => state.subjects.last,
      );
      revisionSubject = revSubj.name;
    }
    list.add({
      'type': 'revision',
      'icon': Icons.warning_amber_rounded,
      'iconColor': const Color(0xFFEF4444),
      'title': 'Revision Due',
      'content': revisionSubject,
    });

    // 3. Best study time
    String bestTime = "7:00 PM – 8:30 PM";
    final prefTime = state.plannerPreferredTime.toLowerCase();
    if (prefTime.contains('morning')) {
      bestTime = "9:00 AM – 10:30 AM";
    } else if (prefTime.contains('afternoon')) {
      bestTime = "2:00 PM – 3:30 PM";
    } else if (prefTime.contains('evening') || prefTime.contains('night')) {
      bestTime = "7:00 PM – 8:30 PM";
    }
    list.add({
      'type': 'best_time',
      'icon': Icons.watch_later_rounded,
      'iconColor': const Color(0xFF10B981),
      'title': 'Best Study Time',
      'content': bestTime,
    });

    // 4. Upcoming exam
    String examSubject = "DBMS";
    int daysRemaining = 3;
    final examDate = state.selectedDate;
    if (examDate != null) {
      final diff = examDate.difference(DateTime.now()).inDays;
      if (diff >= 0) {
        daysRemaining = diff;
        if (state.subjects.isNotEmpty) {
          examSubject = state.subjects.first.name;
        }
      }
    }
    list.add({
      'type': 'exam',
      'icon': Icons.calendar_month_rounded,
      'iconColor': const Color(0xFFF59E0B),
      'title': 'Upcoming Exam',
      'content': '$examSubject - $daysRemaining Days Remaining',
    });

    // 5. Weekly progress
    double onTrackPct = 82.0;
    if (stats.weeklyGoalMinutes > 0) {
      onTrackPct = ((stats.weeklyCompletedMinutes / stats.weeklyGoalMinutes) * 100).clamp(0.0, 100.0);
    }
    list.add({
      'type': 'progress',
      'icon': Icons.trending_up_rounded,
      'iconColor': const Color(0xFF10B981),
      'title': 'Weekly Progress',
      'content': '${onTrackPct.round()}% On Track',
    });

    // 6. AI Tip
    int completedSessions = stats.sessionsCompleted;
    int target = 10;
    while (completedSessions >= target) {
      target += 10;
    }
    int remSessions = target - completedSessions;
    list.add({
      'type': 'tip',
      'icon': Icons.lightbulb_rounded,
      'iconColor': const Color(0xFFF59E0B),
      'title': 'AI Tip',
      'content': 'Complete $remSessions more study session${remSessions > 1 ? 's' : ''} today to unlock your next achievement.',
    });

    // 7. Crystal Goal
    int currentCrystals = stats.sessionsCompleted * 2 + (stats.totalStudyMinutes ~/ 20);
    String crystalGoalMsg = "Study for 45 minutes to earn another Wisdom Crystal.";
    if (currentCrystals % 3 == 0) {
      crystalGoalMsg = "Complete 1 focus session to earn a Focus Crystal.";
    } else if (currentCrystals % 3 == 1) {
      crystalGoalMsg = "Complete a quiz to earn a Mastery Crystal.";
    }
    list.add({
      'type': 'crystal',
      'icon': Icons.diamond_rounded,
      'iconColor': const Color(0xFF6366F1),
      'title': 'Crystal Goal',
      'content': crystalGoalMsg,
    });

    return list;
  }

  void _showRecommendationsInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFDF6).withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            "AI Smart Recommendations",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
          ),
          content: Text(
            "These tips are automatically tailored to your availability windows, exam deadlines, topic mastery progress, focus patterns, and crystal collection milestones to keep your learning optimal.",
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Got it", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF006A63))),
            ),
          ],
        );
      },
    );
  }

  void _showAchievementsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFDF6).withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            "All Achievements & Badges",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAchievementDialogRow("🛡️", "Crystal Guardian Badge", "Complete your Next Achievement to unlock this premium badge."),
                const Divider(),
                _buildAchievementDialogRow("🔥", "Streak Lord", "Maintain a study streak of 7 days. Completed!"),
                const Divider(),
                _buildAchievementDialogRow("📚", "Knowledge Seeker", "Complete 20 focus study sessions."),
                const Divider(),
                _buildAchievementDialogRow("💎", "Crystal Master", "Earn 100 focus crystals."),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF006A63))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementDialogRow(String icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF9F9FC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            "Weekly Study Report",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Here is your study hours distribution for this week:",
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF594042)),
                ),
                const SizedBox(height: 16),
                _buildWeeklyProgressCard(getProgress()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF006A63)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddTaskDialogOnDashboard(BuildContext context) {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    String selectedDifficulty = "Medium";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF9F9FC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Text(
                "Add New Task",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1C1E),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Task / Topic Title",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF594042),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.plusJakartaSans(),
                      decoration: InputDecoration(
                        hintText: "e.g. Biochemistry lecture 1",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Difficulty Level",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF594042),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: ["Easy", "Medium", "Hard"].map((difficulty) {
                        final bool isSelected = selectedDifficulty == difficulty;
                        Color color;
                        switch (difficulty) {
                          case "Easy":
                            color = const Color(0xFF006A63);
                            break;
                          case "Medium":
                            color = const Color(0xFF835500);
                            break;
                          default:
                            color = const Color(0xFFBA1A1A);
                        }
                        return ChoiceChip(
                          label: Text(difficulty, style: GoogleFonts.plusJakartaSans()),
                          selected: isSelected,
                          selectedColor: color.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? color : const Color(0xFF594042),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: isSelected ? color : const Color(0xFFE2E2E5),
                          ),
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedDifficulty = difficulty;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Estimated Work Duration (Minutes)",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF594042),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(),
                      decoration: InputDecoration(
                        hintText: "e.g. 60 or 45",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF594042),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String title = titleController.text.trim();
                    final int? duration = int.tryParse(durationController.text.trim());
                    if (title.isNotEmpty && duration != null && duration > 0) {
                      _addTask(title, selectedDifficulty, duration);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Task '$title' added successfully"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill in all fields with valid values"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C77), // Rose primary action
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    "Add Task",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addSubjectSuggestion(String name) {
    if (name.trim().isEmpty) return;
    if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject already exists!")),
      );
      return;
    }
    setState(() {
      subjects.add(Subject(name: name, difficulty: selectedDifficulty, topics: []));
      subjectController.clear();
    });
    saveData();
  }

  void addSubject() async {
    final name = subjectController.text.trim();
    if (name.isEmpty) return;
    if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subject already exists!")),
      );
      return;
    }
    setState(() {
      _isAddingSubject = true;
    });
    // Simulated premium 600ms processing delay
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        subjects.add(Subject(name: name, difficulty: selectedDifficulty, topics: []));
        subjectController.clear();
        _isAddingSubject = false;
      });
      saveData();
    }
  }

  Future<void> _toggleTask(int index, bool? value) async {
    final String planItem = studyPlan[index];
    final Map<String, String> parsed = _parsePlanItem(planItem);
    final String hoursStr = parsed['hours'] ?? '';

    // Parse hours (e.g. "1.8 hrs/day" -> 1.8)
    double taskHours = 0.0;
    final hoursMatch = RegExp(r'([\d.]+)').firstMatch(hoursStr);
    if (hoursMatch != null) {
      taskHours = double.tryParse(hoursMatch.group(1)!) ?? 0.0;
    }

    final String dayKey = _getCurrentDayKey();
    setState(() {
      completedTasks[index] = value ?? false;
      if (value == true) {
        weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) + taskHours;
      } else {
        weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) - taskHours;
        if (weeklyProgressHours[dayKey]! < 0) weeklyProgressHours[dayKey] = 0.0;
      }
    });
    await saveData();
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

  void _startTimer(String subjectName, String? topicName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudyTimerSheet(
        subjectName: subjectName,
        topicName: topicName,
      ),
    ).then((durationInSeconds) {
      if (durationInSeconds != null && durationInSeconds > 0) {
        final int secs = durationInSeconds as int;
        final double hrs = secs / 3600.0;
        final String dayKey = _getCurrentDayKey();

        setState(() {
          weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) + hrs;
        });
        saveData();

        final minutes = secs ~/ 60;
        final seconds = secs % 60;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Logged study session: ${minutes > 0 ? '$minutes min ' : ''}$seconds sec for ${topicName ?? subjectName}",
            ),
          ),
        );
      }
    });
  }

  void _togglePomodoro() {
    if (isTimerRunning) {
      pomodoroTimer?.cancel();
      setState(() {
        isTimerRunning = false;
      });
      EggyController.instance.isTimerRunning = false;
    } else {
      setState(() {
        isTimerRunning = true;
      });
      EggyController.instance.isTimerRunning = true;
      pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (pomodoroSecondsRemaining > 0) {
            pomodoroSecondsRemaining--;
          } else {
            // When timer hits 0
            if (!isBreakTime) {
              completedPomodorosToday++;
              totalFocusHoursToday += pomodoroDurationSeconds / 3600.0;
              
              isBreakTime = true;
              pomodoroDurationSeconds = breakDurationSeconds;
              pomodoroSecondsRemaining = breakDurationSeconds;
              
              _showPomodoroCompletionAlert();
            } else {
              isBreakTime = false;
              if (activeTaskWorkMinutes != null) {
                pomodoroDurationSeconds = activeTaskWorkMinutes! * 60;
              } else {
                if (activePresetProfile == "45m") {
                  pomodoroDurationSeconds = 45 * 60;
                } else if (activePresetProfile == "60m") {
                  pomodoroDurationSeconds = 60 * 60;
                } else {
                  pomodoroDurationSeconds = 25 * 60;
                }
              }
              pomodoroSecondsRemaining = pomodoroDurationSeconds;
              
              _showPomodoroCompletionAlert();
              pomodoroTimer?.cancel();
              isTimerRunning = false;
              EggyController.instance.isTimerRunning = false;
            }
          }
        });
      });
    }
  }

  void _setPreset(int minutes, bool isBreak) {
    pomodoroTimer?.cancel();
    setState(() {
      isBreakTime = isBreak;
      isTimerRunning = false;
      pomodoroDurationSeconds = minutes * 60;
      pomodoroSecondsRemaining = pomodoroDurationSeconds;
      activePresetProfile = "${minutes}m";

      // Map static break durations matching selected focus minutes
      if (minutes == 25) {
        breakDurationSeconds = 5 * 60;
      } else if (minutes == 45) {
        breakDurationSeconds = 10 * 60;
      } else if (minutes == 60) {
        breakDurationSeconds = 15 * 60;
      } else {
        breakDurationSeconds = 5 * 60;
      }

      // Overwrite active dynamic task variables
      activeTaskName = null;
      activeTaskWorkMinutes = null;
      activeTaskBreakMinutes = null;
    });
    EggyController.instance.isTimerRunning = false;
  }

  void _triggerTaskTimer(String hoursStr, String topicTitle) {
    final cleaned = hoursStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final double? parsedHours = double.tryParse(cleaned);
    if (parsedHours != null) {
      final int workMinutes = (parsedHours * 60).round();
      final int breakMinutes = (((5 / 25) * workMinutes).round()).clamp(1, 60);

      setState(() {
        activeTaskName = topicTitle;
      });

      _startDynamicTaskSession(workMinutes, breakMinutes);
    } else {
      setState(() {
        activeTaskName = topicTitle;
      });
      _startDynamicTaskSession(25, 5);
    }
  }

  void _startDynamicTaskSession(int workMinutes, int breakMinutes) {
    pomodoroTimer?.cancel();
    setState(() {
      isBreakTime = false;
      isTimerRunning = false;
      pomodoroDurationSeconds = workMinutes * 60;
      pomodoroSecondsRemaining = pomodoroDurationSeconds;
      breakDurationSeconds = breakMinutes * 60;
      activeTaskWorkMinutes = workMinutes;
      activeTaskBreakMinutes = breakMinutes;
      activePresetProfile = ""; // Clear preset pill highlight state
    });
    EggyController.instance.isTimerRunning = false;

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );

    if (!isTimerRunning) {
      _togglePomodoro();
    }
  }



  Widget _buildPresetPill(String label, int minutes, String presetProfile) {
    final bool isSelected = activePresetProfile == presetProfile;
    return GestureDetector(
      onTap: () => _setPreset(minutes, false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFF1B343) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: isSelected ? const Color(0xFF3B887C) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPomodoroCompletionAlert() {
    if (!isBreakTime) {
      completedPomodorosToday++;
      totalFocusHoursToday += pomodoroDurationSeconds / 3600.0;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D3142),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.alarm_on_rounded, color: Color(0xFFF1B343)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isBreakTime ? "Break completed! Ready to focus? ðŸŽ¯" : "Time for a short break! ðŸ§ ",
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPomodoroDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return "$minutesStr:$secondsStr";
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

  Widget _buildDifficultyBadge(String difficulty) {
    Color bgColor;
    Color textColor;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        break;
      case 'medium':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        break;
      case 'hard':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.fredoka(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<String> _getSubjectSuggestions() {
    final String query = subjectController.text.toLowerCase();
    if (query.isEmpty) return [];

    final allSuggestions = [
      "Anatomy",
      "Physiology",
      "Biochemistry",
      "Pathology",
      "Pharmacology",
      "Microbiology",
      "Forensic Medicine",
      "Community Medicine",
      "Ophthalmology",
      "ENT",
      "General Medicine",
      "General Surgery",
      "Pediatrics",
      "Obstetrics & Gynecology",
      "Computer Programming",
      "Data Structures",
      "Algorithms",
      "Discrete Mathematics",
      "Operating Systems",
      "Database Systems",
      "Computer Networks",
      "Machine Learning",
      "Software Engineering",
    ];

    return allSuggestions
        .where((s) => s.toLowerCase().startsWith(query) && !subjects.any((sub) => sub.name.toLowerCase() == s.toLowerCase()))
        .toList();
  }

  Widget _buildSuggestionsList() {
    final suggestions = _getSubjectSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: suggestions.map((s) {
            return ListTile(
              title: Text(s, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.add, size: 18),
              onTap: () => _addSubjectSuggestion(s),
            );
          }).toList(),
        ),
      ),
    );
  }



  Widget _buildWeeklyProgressCard(double progress) {
    final bool isWeekly = selectedPeriod == 'Weekly';
    final int completedCount = completedTasks.where((task) => task).length;
    final double loggedHoursTotal = weeklyProgressHours.values.fold(0.0, (sum, val) => sum + val);

    final statistics = StudyStateManager.instance.statistics;
    final int displayLessons = isWeekly ? completedCount : (completedCount * 4);
    final double displayHours = isWeekly
        ? loggedHoursTotal
        : (statistics.monthlyProgress[0] +
            statistics.monthlyProgress[1] +
            statistics.monthlyProgress[2] +
            statistics.monthlyProgress[3]);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2D3142),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
              ),
              // Interactive Toggle Switch UX
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedPeriod = 'Weekly';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWeekly ? const Color(0xFF2D3142) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "Weekly",
                          style: GoogleFonts.fredoka(
                            color: isWeekly ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedPeriod = 'Month';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: !isWeekly ? const Color(0xFF2D3142) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          "Month",
                          style: GoogleFonts.fredoka(
                            color: !isWeekly ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$displayLessons",
                    style: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                  ),
                  Text("lessons", style: GoogleFonts.fredoka(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayHours.toStringAsFixed(1),
                    style: GoogleFonts.fredoka(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                  ),
                  Text("hours completed", style: GoogleFonts.fredoka(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Conditional Chart Layout rendering (5 pillars for Weekly, 4 pillars for Monthly)
          if (isWeekly)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPillBar("Mon", weeklyProgressHours["Mon"] ?? 0.0, maxTarget: 4.0),
                _buildPillBar("Tue", weeklyProgressHours["Tue"] ?? 0.0, maxTarget: 4.0),
                _buildPillBar("Wed", weeklyProgressHours["Wed"] ?? 0.0, maxTarget: 4.0),
                _buildPillBar("Thu", weeklyProgressHours["Thu"] ?? 0.0, maxTarget: 4.0),
                _buildPillBar("Fri", weeklyProgressHours["Fri"] ?? 0.0, maxTarget: 4.0),
              ],
            )
          else
            Builder(
              builder: (context) {
                final statistics = StudyStateManager.instance.statistics;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildPillBar("Week 1", statistics.monthlyProgress[0], maxTarget: 12.0),
                    _buildPillBar("Week 2", statistics.monthlyProgress[1], maxTarget: 12.0),
                    _buildPillBar("Week 3", statistics.monthlyProgress[2], maxTarget: 12.0),
                    _buildPillBar("Week 4", statistics.monthlyProgress[3], maxTarget: 12.0),
                  ],
                );
              }
            ),
        ],
      ),
    );
  }

  Widget _buildPillBar(String day, double hoursLogged, {double maxTarget = 4.0}) {
    // Base target factor relative to maxTarget
    double factor = hoursLogged / maxTarget;
    if (factor > 1.0) factor = 1.0;

    // min height 45 (to fit top circle/label), max height 120
    final double height = 45 + (factor * 75);

    String badgeLabel;
    if (hoursLogged <= 0.0) {
      badgeLabel = "0";
    } else if (hoursLogged < 1.0) {
      badgeLabel = "${(hoursLogged * 60).toStringAsFixed(0)}m";
    } else {
      badgeLabel = "${hoursLogged.toStringAsFixed(1)}h";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Bottom Section of the pill representing active progression
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3B887C).withOpacity(0.3), // Muted Deep Teal tint
                  borderRadius: BorderRadius.circular(16),
                ),
                height: height * (0.3 + (factor * 0.5)),
              ),
              // Top Capsule Section (Badge styling)
              Positioned(
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B887C), // Muted Deep Teal
                    shape: BoxShape.circle,
                  ),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Text(
                      badgeLabel,
                      style: GoogleFonts.fredoka(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: GoogleFonts.fredoka(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }



  String _getDashboardBackdrop() {
    if (userMascot.contains("mascot_coder.png") || userMascot.contains("mascot_girl_login.png")) {
      return "assets/images/engineering_bg.jpg";
    } else if (userMascot.contains("mascot_traditional.png")) {
      return "assets/images/medical_bg.jpg";
    } else {
      return "assets/images/generic_bg.jpg";
    }
  }

  Widget _buildDashboardTab() {
    final statistics = StudyStateManager.instance.statistics;
    final double progress = statistics.todayGoalTotal == 0
        ? 0.0
        : statistics.todayGoalCompleted / statistics.todayGoalTotal;
    final int totalTasks = statistics.todayGoalTotal;
    final int completedCount = statistics.todayGoalCompleted;
    final int todayIndex = DateTime.now().weekday - 1;

    // Filter up to 3 uncompleted tasks for the dashboard checklist widget
    final List<Map<String, dynamic>> upcomingTasks = [];
    for (int i = 0; i < studyPlan.length; i++) {
      final parsedItem = StudyStateManager.instance.parsePlanItem(studyPlan[i]);
      final itemDay = int.tryParse(parsedItem['dayIndex'] ?? '');
      final isBreak = (parsedItem['subject'] ?? '').toLowerCase() == 'break';
      if (!isBreak && itemDay == todayIndex && !completedTasks[i]) {
        final planItem = studyPlan[i];
        final regex = RegExp(r'^(.+)\s+\((Easy|Medium|Hard)\)\s+-\s+(.+)$', caseSensitive: false);
        final match = regex.firstMatch(planItem);
        if (match != null) {
          upcomingTasks.add({
            'index': i,
            'subject': match.group(1)!,
            'difficulty': match.group(2)!,
            'hours': match.group(3)!,
            'startTime': parsedItem['startTime'] ?? '',
            'endTime': parsedItem['endTime'] ?? '',
          });
        } else {
          upcomingTasks.add({
            'index': i,
            'subject': planItem,
            'difficulty': 'Medium',
            'hours': '1 hr',
            'startTime': parsedItem['startTime'] ?? '',
            'endTime': parsedItem['endTime'] ?? '',
          });
        }
      }
      if (upcomingTasks.length >= 3) break;
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_getDashboardBackdrop()),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.85),
            BlendMode.lighten,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 120), // Clear bottom nav dock padding
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // LAYER 1: Lowest Layer (1st Layer) - Progress Card column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar
                _buildTopNav(),
                // Hero Greeting Section
                _buildGreeting(),
                // Today's Goal Progress Card (Glass Card)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 11, // occupies ~60% width
                        child: _buildGlassCard(
                          borderRadius: 32.0,
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 68,
                                        height: 68,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 8,
                                          backgroundColor: const Color(0xFFEEEEF0),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                                        ),
                                      ),
                                      Text(
                                        "${(progress * 100).round()}%",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1A1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Progress",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8D7072),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "TODAY'S GOAL",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF8D7072),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          "$completedCount",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF006A63),
                                          ),
                                        ),
                                        Text(
                                          " / $totalTasks",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Tasks",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF8D7072),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: const Color(0xFFEEEEF0),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Keep going! \u{1F4AA}",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF8D7072),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 7), // leaves ~40% space on the right for the mascot
                    ],
                  ),
                ),
              ],
            ),
            // LAYER 2: Middle Layer (2nd Layer) - 3D Character Mascot (Dynamic based on selected profile mascot)
            Positioned(
              right: -20,
              top: 45, // overlays the Progress Card from above, pushed higher
              child: SizedBox(
                width: 300,
                height: 400,
                child: Image.asset(
                  userMascot.isNotEmpty ? userMascot : "assets/images/mascot_boy.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person_rounded,
                      size: 100,
                      color: Color(0xFF006A63),
                    );
                  },
                ),
              ),
            ),
            // LAYER 3: Top Layer (3rd Layer) - Quick Actions & Remaining widgets Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push below the Progress card so it overlays the Mascot waist/torso area
                const SizedBox(height: 350),
                // Quick Actions Card (Glass card)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Quick Actions",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentTab = 4; // Planner setup tab
                                });
                                EggyController.instance.currentTab = 3;
                              },
                              child: Text(
                                "Edit",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006A63),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DashboardQuickActionItem(
                              icon: Icons.playlist_add_check_rounded,
                              label: "New Task",
                              bgColor: const Color(0xFFE8F5F1),
                              iconColor: const Color(0xFF006A63),
                              onTap: () => _showAddTaskDialogOnDashboard(context),
                            ),
                            DashboardQuickActionItem(
                              icon: Icons.calendar_today_rounded,
                              label: "Schedule",
                              bgColor: const Color(0xFFF3E8FF),
                              iconColor: const Color(0xFF7C3AED),
                              onTap: () {
                                setState(() {
                                  _currentTab = 1;
                                });
                                EggyController.instance.currentTab = 1;
                              },
                            ),
                            DashboardQuickActionItem(
                              icon: Icons.track_changes_rounded,
                              label: "Goals",
                              bgColor: const Color(0xFFFFEDD5),
                              iconColor: const Color(0xFFEA580C),
                              onTap: () {
                                setState(() {
                                  _currentTab = 4;
                                });
                                EggyController.instance.currentTab = 4;
                              },
                            ),
                            DashboardQuickActionItem(
                              icon: Icons.bar_chart_rounded,
                              label: "Reports",
                              bgColor: const Color(0xFFE0E7FF),
                              iconColor: const Color(0xFF4F46E5),
                              onTap: _showReportsDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DashboardMetric(value: '${statistics.weeklyCompletedMinutes}/${statistics.weeklyGoalMinutes}m', label: 'Weekly Goal'),
                        _DashboardMetric(value: '${statistics.todayStudyMinutes}m', label: 'Study Hours'),
                        _DashboardMetric(value: '${statistics.streakDays}', label: 'Current Streak'),
                        _DashboardMetric(value: '${statistics.sessionsToday}', label: 'Sessions'),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: _buildGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text("🔥", style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  "Learning Streak & Achievements",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1C1E),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                _showAchievementsDialog();
                              },
                              child: Text(
                                "See all",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006A63),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPremiumStatItem(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFF97316),
                              value: "${statistics.streakDays}",
                              label: "Day Streak",
                            ),
                            _buildPremiumStatItem(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFFBBF24),
                              value: "${(statistics.totalStudyMinutes * 15 + statistics.sessionsCompleted * 100 + statistics.streakDays * 50).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                              label: "XP Earned",
                            ),
                            _buildPremiumStatItem(
                              icon: Icons.menu_book_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              value: "${statistics.sessionsCompleted}",
                              label: "Sessions",
                            ),
                            _buildPremiumStatItem(
                              icon: Icons.watch_later_rounded,
                              iconColor: const Color(0xFF10B981),
                              value: "${(statistics.totalStudyMinutes / 60.0).toStringAsFixed(1)}",
                              label: "Focus Hours",
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Crystal Collection Section
                        Builder(
                          builder: (context) {
                            int completedTopics = 0;
                            for (final subject in subjects) {
                              completedTopics += subject.topics.where((t) => t.isCompleted).length;
                            }
                            int completedSubjects = subjects.where((subject) =>
                              subject.topics.isNotEmpty && subject.topics.every((t) => t.isCompleted)
                            ).length;

                            final int focusCrystals = statistics.sessionsCompleted * 2 + (statistics.totalStudyMinutes ~/ 20);
                            final int wisdomCrystals = completedTopics * 5;
                            final int masteryCrystals = completedSubjects * 10 + (completedTopics ~/ 2);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Crystal Collection",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text("💙", style: TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "$focusCrystals",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF1A1C1E),
                                                    ),
                                                  ),
                                                  Text(
                                                    "Focus",
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text("🟣", style: TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "$wisdomCrystals",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF1A1C1E),
                                                    ),
                                                  ),
                                                  Text(
                                                    "Wisdom",
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text("🟡", style: TextStyle(fontSize: 14)),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "$masteryCrystals",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF1A1C1E),
                                                    ),
                                                  ),
                                                  Text(
                                                    "Mastery",
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Next Achievement Section
                        Builder(
                          builder: (context) {
                            int targetSessions = 10;
                            int completed = statistics.sessionsCompleted;
                            while (completed >= targetSessions) {
                              targetSessions += 10; // Next tier
                            }
                            int remaining = targetSessions - completed;
                            double progressPct = (completed / targetSessions).clamp(0.0, 1.0);
                            int progressPctInt = (progressPct * 100).round();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEEF2F6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text("🏆", style: TextStyle(fontSize: 16)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Next Achievement",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            Text(
                                              "Focus Master",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1A1C1E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "$progressPctInt%",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF6366F1),
                                            ),
                                          ),
                                          Text(
                                            "$remaining study sessions remaining",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progressPct,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Next Unlock",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Crystal Guardian Badge",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1A1C1E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: _buildGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text("🤖", style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  "Smart Recommendations",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1C1E),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                _showRecommendationsInfoDialog();
                              },
                              child: Text(
                                "See all",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF006A63),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final recommendations = _generateRecommendations();
                            return Column(
                              children: List.generate(recommendations.length, (idx) {
                                final rec = recommendations[idx];
                                final isLast = idx == recommendations.length - 1;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(rec['icon'] as IconData, color: rec['iconColor'] as Color, size: 18),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  rec['title'] as String,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  rec['content'] as String,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF1A1C1E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(color: Colors.grey.shade300, height: 16),
                                  ],
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Weather & Quote side-by-side
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 110,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5F1).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFE8F5F1)),
                          ),
                          child: Builder(
                            builder: (context) {
                              final weather = _getDynamicWeather();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        weather['temp'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1A1C1E),
                                        ),
                                      ),
                                      Icon(weather['icon'] as IconData, color: weather['iconColor'] as Color, size: 20),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        weather['status'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF594042),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: Colors.grey, size: 10),
                                          const SizedBox(width: 2),
                                          Text(
                                            weather['location'] as String,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          height: 110,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.format_quote_rounded, color: Color(0xFF34D399), size: 20),
                              const SizedBox(height: 4),
                              Text(
                                "Small progress every day adds up to big results.",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyRoomTab() {
    final List<String> subjectNames = subjects.map((s) => s.name).toList();
    if (subjectNames.isEmpty) {
      subjectNames.add("General Study");
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_getDashboardBackdrop()),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.85),
            BlendMode.lighten,
          ),
        ),
      ),
      child: EnergyChamberScreen(
        subjects: subjectNames,
        onSessionComplete: (double hours, String subject) {
          setState(() {
            final String dayKey = _getCurrentDayKey();
            weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) + hours;
          });
          saveData();
        },
      ),
    );
  }

  void _startStudyRoomTimer() {
    setState(() {
      _studyRoomIsTimerActive = true;
      _studyRoomIsPaused = false;
      _studyRoomSecondsRemaining = _studyRoomDurationMinutes * 60;
    });

    _studyRoomTimer?.cancel();
    _studyRoomTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_studyRoomIsPaused) {
        setState(() {
          if (_studyRoomSecondsRemaining > 0) {
            _studyRoomSecondsRemaining--;
          } else {
            _studyRoomTimer?.cancel();
            _studyRoomIsTimerActive = false;

            // Log progress
            final double hrs = _studyRoomDurationMinutes / 60.0;
            final String dayKey = _getCurrentDayKey();
            weeklyProgressHours[dayKey] = (weeklyProgressHours[dayKey] ?? 0.0) + hrs;
            saveData();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("\u{1F389} Focus session completed: $_studyRoomDurationMinutes mins of $_studyRoomSelectedSubject!"),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    });
  }

  void _toggleStudyRoomPause() {
    setState(() {
      _studyRoomIsPaused = !_studyRoomIsPaused;
    });
  }

  void _cancelStudyRoomTimer() {
    _studyRoomTimer?.cancel();
    setState(() {
      _studyRoomIsTimerActive = false;
    });
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Lumina Study menu drawer toggled"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF1A1C1E), size: 22),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _showReportsDialog,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A1C1E), size: 22),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEA580C),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "2",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => EditProfileScreen(
                        currentName: userName,
                        currentCourse: userCourse,
                        currentYear: userYear,
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(0.0, 1.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                    ),
                  );
                  if (result != null && result is Map<String, String>) {
                    final prefs = await SharedPreferences.getInstance();
                    setState(() {
                      userName = result['name'] ?? "";
                      userCourse = result['course'] ?? "";
                      userYear = result['year'] ?? "";
                    });
                    EggyController.instance.userCourse = userCourse;
                    EggyController.instance.triggerJoyBounce();
                    await prefs.setString("user_name", userName);
                    await prefs.setString("user_course", userCourse);
                    await prefs.setString("user_year", userYear);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage(userMascot.isNotEmpty ? userMascot : "assets/images/mascot_boy.png"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getDynamicWeather() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return {
        'temp': "22\u{00B0}C",
        'status': "Fresh Morning",
        'icon': Icons.wb_sunny_rounded,
        'iconColor': const Color(0xFFF59E0B),
        'location': "Study Haven",
      };
    } else if (hour >= 12 && hour < 17) {
      return {
        'temp': "27\u{00B0}C",
        'status': "Bright Afternoon",
        'icon': Icons.wb_sunny_rounded,
        'iconColor': const Color(0xFFEA580C),
        'location': "Study Haven",
      };
    } else if (hour >= 17 && hour < 21) {
      return {
        'temp': "21\u{00B0}C",
        'status': "Calm Evening",
        'icon': Icons.wb_cloudy_outlined,
        'iconColor': const Color(0xFF64748B),
        'location': "Study Haven",
      };
    } else {
      return {
        'temp': "16\u{00B0}C",
        'status': "Quiet Night",
        'icon': Icons.nightlight_round,
        'iconColor': const Color(0xFF38BDF8),
        'location': "Study Haven",
      };
    }
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greetingWord;
    if (hour >= 5 && hour < 12) {
      greetingWord = "Good morning,";
    } else if (hour >= 12 && hour < 17) {
      greetingWord = "Good afternoon,";
    } else if (hour >= 17 && hour < 21) {
      greetingWord = "Good evening,";
    } else {
      greetingWord = "Good night,";
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingWord,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            "${userName.isNotEmpty ? userName : 'Student'}! \u{1F44B}",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF006A63),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You've got this. Let's make today count!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF8D7072),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8D7072),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double borderRadius = 24.0,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

    List<String> _getDefaultTopics(String subjectName) {
    final query = subjectName.toLowerCase();
    if (query.contains("data structure") || query.contains("algorithm") || query.contains("dsa")) {
      return ["Arrays", "Linked Lists", "Stacks", "Queues", "Trees", "Graphs"];
    } else if (query.contains("physics")) {
      return ["Mechanics", "Thermodynamics", "Electromagnetism", "Optics", "Modern Physics"];
    } else if (query.contains("chemistry")) {
      return ["Organic Chemistry", "Inorganic Chemistry", "Physical Chemistry", "Biochemistry"];
    } else if (query.contains("math") || query.contains("calculus") || query.contains("algebra")) {
      return ["Algebra", "Calculus", "Probability", "Linear Algebra", "Geometry"];
    } else if (query.contains("database") || query.contains("dbms") || query.contains("sql")) {
      return ["Introduction to DBMS", "Entity-Relationship Model", "Relational Database Design", "SQL Queries", "Indexing & Hashing", "Transactions"];
    } else if (query.contains("network")) {
      return ["Physical Layer", "Data Link Layer", "Network Layer", "Transport Layer", "Application Layer"];
    } else {
      return ["Introduction", "Fundamentals", "Core Concepts", "Advanced Topics", "Practical Applications", "Revision"];
    }
  }

  void _showAddSubjectModal(BuildContext context) {
    String localSubjectName = "";
    String localDifficulty = "Medium";
    bool aiGenerateSyllabus = true;
    final localController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              margin: EdgeInsets.only(bottom: keyboardHeight),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add New Subject",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8D7072)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "SUBJECT NAME",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8D7072),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: localController,
                        onChanged: (val) {
                          setModalState(() {
                            localSubjectName = val;
                          });
                        },
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF1A1C1E)),
                        decoration: InputDecoration(
                          hintText: "e.g., Data Structures & Algorithms",
                          hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "DIFFICULTY LEVEL",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8D7072),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ["Easy", "Medium", "Hard"].map((diff) {
                        final bool isSel = localDifficulty == diff;
                        Color badgeColor;
                        Color activeBg;
                        switch (diff) {
                          case "Easy":
                            badgeColor = const Color(0xFF10B981);
                            activeBg = const Color(0xFFE8F5E9);
                            break;
                          case "Medium":
                            badgeColor = const Color(0xFFD97706);
                            activeBg = const Color(0xFFFFF8E1);
                            break;
                          default:
                            badgeColor = const Color(0xFFEF4444);
                            activeBg = const Color(0xFFFFEBEE);
                        }
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  localDifficulty = diff;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSel ? activeBg : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel ? badgeColor : const Color(0xFFE2E8F0),
                                    width: isSel ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    diff,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? badgeColor : const Color(0xFF594042),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0D9488), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(
                                    "AI Syllabus Generator",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F766E),
                                    ),
                                  ),
                                  Text(
                                    "Automatically populate with standard core chapters",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: aiGenerateSyllabus,
                            activeColor: const Color(0xFF0D9488),
                            onChanged: (val) {
                              setModalState(() {
                                aiGenerateSyllabus = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: localSubjectName.trim().isEmpty
                            ? null
                            : () async {
                                final name = localSubjectName.trim();
                                if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Subject already exists!")),
                                  );
                                  return;
                                }
                                
                                Navigator.pop(context);
                                
                                setState(() {
                                  _isLoading = true;
                                });
                                
                                await Future.delayed(const Duration(milliseconds: 650));
                                
                                final List<Topic> generatedTopics = [];
                                if (aiGenerateSyllabus) {
                                  final defaultNames = _getDefaultTopics(name);
                                  for (final topicName in defaultNames) {
                                    generatedTopics.add(Topic(name: topicName, difficulty: localDifficulty, isCompleted: false));
                                  }
                                }
                                
                                setState(() {
                                  subjects.add(Subject(
                                    name: name,
                                    difficulty: localDifficulty,
                                    topics: generatedTopics,
                                  ));
                                  _isLoading = false;
                                });
                                await saveData();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006A63),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "Create Subject",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImportSyllabusModal(BuildContext context) {
    String localSubjectName = "";
    String syllabusText = "";
    final nameController = TextEditingController();
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              margin: EdgeInsets.only(bottom: keyboardHeight),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Import Syllabus",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8D7072)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "SUBJECT NAME",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8D7072),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: nameController,
                        onChanged: (val) {
                          setModalState(() {
                            localSubjectName = val;
                          });
                        },
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF1A1C1E)),
                        decoration: InputDecoration(
                          hintText: "e.g., Relational Database Management System",
                          hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "PASTE SYLLABUS TOPICS",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8D7072),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: textController,
                          maxLines: null,
                          expands: true,
                          onChanged: (val) {
                            setModalState(() {
                              syllabusText = val;
                            });
                          },
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF1A1C1E)),
                          decoration: InputDecoration(
                            hintText: "Paste chapters here, one per line:\n- Chapter 1: Introduction to DBMS\n- Chapter 2: Relational Model\n- Chapter 3: SQL Queries",
                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 13),
                            contentPadding: const EdgeInsets.all(16),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: localSubjectName.trim().isEmpty || syllabusText.trim().isEmpty
                            ? null
                            : () async {
                                final name = localSubjectName.trim();
                                if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Subject already exists!")),
                                  );
                                  return;
                                }

                                Navigator.pop(context);

                                setState(() {
                                  _isLoading = true;
                                });

                                await Future.delayed(const Duration(milliseconds: 800));

                                final List<Topic> importedTopics = [];
                                final lines = syllabusText.split('\n');
                                for (var line in lines) {
                                  var cleanLine = line.trim();
                                  if (cleanLine.startsWith('-') || cleanLine.startsWith('*') || cleanLine.startsWith('•')) {
                                    cleanLine = cleanLine.substring(1).trim();
                                  }
                                  if (cleanLine.isNotEmpty) {
                                    importedTopics.add(Topic(name: cleanLine, difficulty: "Medium", isCompleted: false));
                                  }
                                }

                                setState(() {
                                  subjects.add(Subject(
                                    name: name,
                                    difficulty: "Medium",
                                    topics: importedTopics,
                                  ));
                                  _isLoading = false;
                                });
                                await saveData();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006A63),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "Import & Parse Syllabus",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<String> getSubTopicsForChapter(String chapterName) {
    final nameLower = chapterName.toLowerCase();
    if (nameLower.contains("organic")) {
      return ["Basics & Nomenclature", "Reaction Mechanisms", "Functional Groups", "Spectroscopy & Analysis"];
    } else if (nameLower.contains("biomolecule")) {
      return ["Amino Acids & Proteins", "Nucleic Acids (DNA/RNA)", "Enzyme Kinetics", "Lipids & Membranes"];
    } else if (nameLower.contains("carbohydrate")) {
      return ["Monosaccharides", "Disaccharides & Polysaccharides", "Glycolysis Pathway", "Glycoproteins"];
    } else if (nameLower.contains("lipid")) {
      return ["Fatty Acids", "Triacylglycerols", "Phospholipids", "Cholesterol & Steroids"];
    } else if (nameLower.contains("mechanic")) {
      return ["Newton's Laws", "Work, Energy & Power", "Rotational Dynamics", "Gravitation"];
    } else if (nameLower.contains("algebra")) {
      return ["Linear Equations", "Matrices & Determinants", "Vector Spaces", "Eigenvalues & Eigenvectors"];
    } else if (nameLower.contains("thermo")) {
      return ["Laws of Thermodynamics", "Entropy & Free Energy", "Thermodynamic Cycles", "Heat Transfer"];
    } else {
      return [
        "Fundamentals & Definitions",
        "Core Theories & Models",
        "Key Applications & Examples",
        "Self-Assessment & Review"
      ];
    }
  }

  void _showStatsModal({
    required BuildContext context,
    required String title,
    required String icon,
    required Widget content,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubjectsDetailsModal(BuildContext context) {
    _showStatsModal(
      context: context,
      title: "My Subjects",
      icon: "📚",
      content: Column(
        children: subjects.map((s) {
          final double prog = s.topics.isEmpty ? 0.0 : (s.topics.where((t) => t.isCompleted).length / s.topics.length);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${s.topics.length} Chapters • ${s.difficulty}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${(prog * 100).round()}%",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: const Color(0xFF006A63),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showChaptersDetailsModal(BuildContext context) {
    _showStatsModal(
      context: context,
      title: "All Chapters",
      icon: "📖",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: subjects.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF006A63),
                  ),
                ),
                const SizedBox(height: 6),
                if (s.topics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      "No chapters added yet.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                else
                  ...s.topics.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            t.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: t.isCompleted ? const Color(0xFF059669) : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCompletedDetailsModal(BuildContext context) {
    final List<Map<String, dynamic>> completedList = [];
    for (final s in subjects) {
      for (final t in s.topics) {
        if (t.isCompleted) {
          completedList.add({
            "chapter": t.name,
            "subject": s.name,
          });
        }
      }
    }

    Widget contentWidget;
    if (completedList.isEmpty) {
      contentWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const Text("💤", style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(
                "No chapters completed yet.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      contentWidget = Column(
        children: completedList.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["chapter"]!,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item["subject"]!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    _showStatsModal(
      context: context,
      title: "Completed Chapters",
      icon: "✅",
      content: contentWidget,
    );
  }

  void _showProgressDetailsModal(BuildContext context) {
    _showStatsModal(
      context: context,
      title: "Subject Progress",
      icon: "🎯",
      content: Column(
        children: subjects.map((s) {
          final double prog = s.topics.isEmpty ? 0.0 : (s.topics.where((t) => t.isCompleted).length / s.topics.length);
          final int completedCount = s.topics.where((t) => t.isCompleted).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                    Text(
                      "${(prog * 100).round()}% ($completedCount/${s.topics.length})",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: const Color(0xFF006A63),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: prog,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context, int actualIndex) {
    String newTopicName = "";
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add Chapter", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: TextField(
            onChanged: (val) => newTopicName = val,
            decoration: const InputDecoration(hintText: "Enter chapter name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newTopicName.trim().isNotEmpty) {
                  setState(() {
                    subjects[actualIndex].topics.add(Topic(name: newTopicName.trim(), difficulty: subjects[actualIndex].difficulty, isCompleted: false));
                  });
                  await saveData();
                }
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _showEditSubjectDialog(BuildContext context, int actualIndex) {
    String newName = subjects[actualIndex].name;
    final controller = TextEditingController(text: newName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Edit Subject Name", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            onChanged: (val) => newName = val,
            decoration: const InputDecoration(hintText: "Enter new subject name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newName.trim().isNotEmpty) {
                  setState(() {
                    subjects[actualIndex].name = newName.trim();
                  });
                  await saveData();
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showAiSummaryDialog(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF006A63)),
              const SizedBox(width: 8),
              Text("AI Syllabus Summary", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Based on the chapters listed, this subject covers the core fundamentals of ${subject.name}. It is categorized as a ${subject.difficulty}-level challenge. We recommend dedicating study sessions focusing on topics with pending status first to maintain optimal recall.",
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Awesome"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String iconEmoji,
    required int value,
    required String label,
    required Color accentColor,
    required Color bgColor,
    bool isPercentage = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _buildGlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Text(iconEmoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Text(
                  "${val.round()}${isPercentage ? '%' : ''}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C1E),
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8D7072),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsTab() {
    final List<Color> bgColors = [
      const Color(0xFFFFEDD5), // Peach
      const Color(0xFFE0E7FF), // Indigo
      const Color(0xFFD1FAE5), // Mint
      const Color(0xFFF3E8FF), // Lavender
    ];
    final List<Color> textColors = [
      const Color(0xFFEA580C),
      const Color(0xFF4F46E5),
      const Color(0xFF059669),
      const Color(0xFF7C3AED),
    ];

    // 1. Filter by search query
    var filtered = subjects.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_subjectSearchQuery.toLowerCase()) ||
                            s.topics.any((t) => t.name.toLowerCase().contains(_subjectSearchQuery.toLowerCase()));
      return matchesSearch;
    }).toList();

    // 2. Filter by status / difficulty tab
    if (_subjectsFilter != "All") {
      if (_subjectsFilter == "In Progress") {
        filtered = filtered.where((s) {
          if (s.topics.isEmpty) return true;
          final done = s.topics.where((t) => t.isCompleted).length;
          return done > 0 && done < s.topics.length;
        }).toList();
      } else if (_subjectsFilter == "Completed") {
        filtered = filtered.where((s) {
          if (s.topics.isEmpty) return false;
          final done = s.topics.where((t) => t.isCompleted).length;
          return done == s.topics.length;
        }).toList();
      } else {
        // Difficulty filter ("Easy", "Medium", "Hard")
        filtered = filtered.where((s) => s.difficulty == _subjectsFilter).toList();
      }
    }

    // 3. Sort
    if (_subjectsSort == "Alphabetical") {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_subjectsSort == "Chapters") {
      filtered.sort((a, b) => b.topics.length.compareTo(a.topics.length));
    } else if (_subjectsSort == "Progress") {
      filtered.sort((a, b) {
        final double progressA = a.topics.isEmpty ? 0.0 : (a.topics.where((t) => t.isCompleted).length / a.topics.length);
        final double progressB = b.topics.isEmpty ? 0.0 : (b.topics.where((t) => t.isCompleted).length / b.topics.length);
        return progressB.compareTo(progressA);
      });
    } else {
      // "Recent" -> Maintain original list order (reversed to show newest first)
      filtered = filtered.reversed.toList();
    }

    // Stats calculations
    final int totalSubjectsCount = subjects.length;
    int totalChaptersCount = 0;
    int completedChaptersCount = 0;
    for (final s in subjects) {
      totalChaptersCount += s.topics.length;
      completedChaptersCount += s.topics.where((t) => t.isCompleted).length;
    }
    final int overallProgressPercent = totalChaptersCount == 0
        ? 0
        : ((completedChaptersCount / totalChaptersCount) * 100).round();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_getDashboardBackdrop()),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.94),
            BlendMode.lighten,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 140),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36), // Increased whitespace
              
              // 1. Header Row (Title & Notification capsule)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Subjects & Syllabus",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1C1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Manage your subjects and track progress",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF8D7072).withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Premium notification bell button capsule
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF006A63), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Translucent Liquid Glass Hero Card (28-32px rounded corners, layered shadows)
              SubjectHeroCard(
                userName: userName,
                totalSubjects: totalSubjectsCount,
                totalChapters: totalChaptersCount,
                completedChapters: completedChaptersCount,
                overallProgress: overallProgressPercent,
              ),
              const SizedBox(height: 20),

              // 3. Four Rounded Glass Statistic Cards in a Grid/Wrap layout with count animation
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _buildStatCard(
                    iconEmoji: "📚",
                    value: totalSubjectsCount,
                    label: "Subjects",
                    accentColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF).withOpacity(0.4),
                    onTap: () => _showSubjectsDetailsModal(context),
                  ),
                  _buildStatCard(
                    iconEmoji: "📖",
                    value: totalChaptersCount,
                    label: "Chapters",
                    accentColor: const Color(0xFF4F46E5),
                    bgColor: const Color(0xFFE0E7FF).withOpacity(0.4),
                    onTap: () => _showChaptersDetailsModal(context),
                  ),
                  _buildStatCard(
                    iconEmoji: "✅",
                    value: completedChaptersCount,
                    label: "Completed",
                    accentColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFD1FAE5).withOpacity(0.4),
                    onTap: () => _showCompletedDetailsModal(context),
                  ),
                  _buildStatCard(
                    iconEmoji: "🎯",
                    value: overallProgressPercent,
                    label: "Overall Progress",
                    accentColor: const Color(0xFF6366F1),
                    bgColor: const Color(0xFFE2E8F0).withOpacity(0.4),
                    isPercentage: true,
                    onTap: () => _showProgressDetailsModal(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. Taller Search Bar with Animated focus glow
              Focus(
                onFocusChange: (hasFocus) {
                  setState(() {
                    _isSearchFocused = hasFocus;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      if (_isSearchFocused)
                        BoxShadow(
                          color: const Color(0xFF006A63).withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: _buildGlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // taller
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _subjectSearchQuery = val;
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF1A1C1E)),
                      decoration: InputDecoration(
                        hintText: "Search subjects, chapters or topics...",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF006A63)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Increased spacing

              // 5. Horizontal Filter Chips (Rounded glass pills with color dots)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ["All", "In Progress", "Completed", "Easy", "Medium", "Hard"].map((filter) {
                    final bool isSelected = _subjectsFilter == filter;
                    
                    Widget dotIndicator = Container();
                    if (filter == "Easy") {
                      dotIndicator = Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      );
                    } else if (filter == "Medium") {
                      dotIndicator = Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                      );
                    } else if (filter == "Hard") {
                      dotIndicator = Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 12), // Increased spacing
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _subjectsFilter = filter;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF006A63) : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF006A63) : Colors.white.withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              dotIndicator,
                              Text(
                                filter,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF594042),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24), // Increased spacing

              // 6. Subject Library Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "My Subjects (${filtered.length})",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _subjectsSort = val;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _subjectsSort,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF006A63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF006A63), size: 16),
                      ],
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: "Recent", child: Text("Recent")),
                      const PopupMenuItem(value: "Alphabetical", child: Text("Alphabetical")),
                      const PopupMenuItem(value: "Chapters", child: Text("Chapters")),
                      const PopupMenuItem(value: "Progress", child: Text("Progress")),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 7. Subject Cards Library (With entry fade-in scale animation)
              filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _buildGlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Gentle floating 3D book animation (Solid white blends seamlessly)
                            const FloatingAsset(
                              assetPath: "assets/images/open_book_3d.png",
                              width: 120,
                              height: 120,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Your learning journey starts here.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add your first subject or import your syllabus to begin.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showAddSubjectModal(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006A63),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text("Add Subject"),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => _showImportSyllabusModal(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF006A63),
                                    side: const BorderSide(color: Color(0xFF006A63)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text("Import PDF"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final subject = filtered[index];
                        final int actualIndex = subjects.indexOf(subject);
                        final colorIndex = actualIndex % bgColors.length;
                        final textColor = textColors[colorIndex];
                        final bool isExpanded = _expandedSubjectIndices.contains(actualIndex);

                        final double progressPercent = subject.topics.isEmpty
                            ? 0.0
                            : (subject.topics.where((t) => t.isCompleted).length / subject.topics.length);

                        // Find the first pending chapter dynamically!
                        final firstPending = subject.topics.firstWhere(
                          (t) => !t.isCompleted,
                          orElse: () => Topic(name: "", difficulty: "Medium", isCompleted: true),
                        );
                        final String nextTopicText = firstPending.name.isNotEmpty 
                            ? "Next: ${firstPending.name}" 
                            : "All chapters completed! 🎉";

                        Color diffColor;
                        Color diffBg;
                        switch (subject.difficulty) {
                          case "Easy":
                            diffColor = const Color(0xFF10B981);
                            diffBg = const Color(0xFFD1FAE5);
                            break;
                          case "Medium":
                            diffColor = const Color(0xFFD97706);
                            diffBg = const Color(0xFFFFEDD5);
                            break;
                          default:
                            diffColor = const Color(0xFFEF4444);
                            diffBg = const Color(0xFFFEE2E2);
                        }

                        // Dynamic Apple-style icons inside glass capsule
                        Widget getSubjectIconWidget() {
                          final nameLower = subject.name.toLowerCase();
                          IconData ic = Icons.book_rounded;
                          if (nameLower.contains("physic")) {
                            ic = Icons.blur_on_rounded;
                          } else if (nameLower.contains("chem")) {
                            ic = Icons.science_rounded;
                          } else if (nameLower.contains("math") || nameLower.contains("discret")) {
                            ic = Icons.functions_rounded;
                          } else if (nameLower.contains("database") || nameLower.contains("dbms")) {
                            ic = Icons.storage_rounded;
                          } else if (nameLower.contains("algorithm") || nameLower.contains("structure") || nameLower.contains("dsa")) {
                            ic = Icons.code_rounded;
                          } else if (nameLower.contains("operating") || nameLower.contains("system")) {
                            ic = Icons.terminal_rounded;
                          }
                          return Icon(ic, color: textColor, size: 24);
                        }

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 80)),
                          curve: Curves.easeOutBack,
                          builder: (context, val, child) {
                            return Opacity(
                              opacity: val,
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * val),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _buildGlassCard(
                              borderRadius: 24,
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedSubjectIndices.remove(actualIndex);
                                        } else {
                                          _expandedSubjectIndices.add(actualIndex);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Row(
                                        children: [
                                          // Left: Subject icon glass container matching mockup
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: textColor.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: textColor.withOpacity(0.15)),
                                            ),
                                            child: getSubjectIconWidget(),
                                          ),
                                          const SizedBox(width: 14),
                                          // Middle: Subject details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subject.name,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF1A1C1E),
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "${subject.topics.length} Chapters",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade500,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "•",
                                                      style: TextStyle(color: Colors.grey.shade400),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      progressPercent == 1.0 ? "Completed" : "In Progress",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 11,
                                                        color: progressPercent == 1.0 ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Linear progress bar
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: progressPercent,
                                                    minHeight: 6,
                                                    backgroundColor: Colors.white.withOpacity(0.35),
                                                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Next topic text
                                                Text(
                                                  nextTopicText,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Right: Circular progress ring + menu
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 46,
                                                    height: 46,
                                                    child: CircularProgressIndicator(
                                                      value: progressPercent,
                                                      strokeWidth: 3.5,
                                                      backgroundColor: Colors.white.withOpacity(0.3),
                                                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                                                    ),
                                                  ),
                                                  Text(
                                                    "${(progressPercent * 100).round()}%",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF1A1C1E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF006A63)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              onSelected: (val) {
                                                if (val == 'delete') {
                                                  _deleteSubject(actualIndex);
                                                } else if (val == 'edit') {
                                                  _showEditSubjectDialog(context, actualIndex);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(value: 'edit', child: Text("Edit Name")),
                                                const PopupMenuItem(value: 'delete', child: Text("Delete Subject", style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                AnimatedCrossFade(
                                  firstChild: Container(),
                                  secondChild: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(height: 1, color: Colors.white24),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (subject.topics.isEmpty) ...[
                                              Text(
                                                "No chapters added yet.",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  color: const Color(0xFF8D7072),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ] else ...[
                                              Text(
                                                "Syllabus Topics",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF8D7072),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ...List.generate(subject.topics.length, (topicIdx) {
                                                final topic = subject.topics[topicIdx];
                                                final String chapterKey = "$actualIndex-$topicIdx";
                                                final bool isChapterExpanded = _expandedChapterKeys.contains(chapterKey);
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        children: [
                                                          Checkbox(
                                                            value: topic.isCompleted,
                                                            activeColor: const Color(0xFF006A63),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                            onChanged: (val) async {
                                                              await StudyStateManager.instance.toggleTopicCompletion(
                                                                subject.name,
                                                                topic.name,
                                                                val ?? false,
                                                              );
                                                            },
                                                          ),
                                                          Expanded(
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (isChapterExpanded) {
                                                                    _expandedChapterKeys.remove(chapterKey);
                                                                  } else {
                                                                    _expandedChapterKeys.add(chapterKey);
                                                                  }
                                                                });
                                                              },
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        topic.name,
                                                                        style: GoogleFonts.plusJakartaSans(
                                                                          fontSize: 13,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: const Color(0xFF1A1C1E),
                                                                          decoration: topic.isCompleted
                                                                              ? TextDecoration.lineThrough
                                                                              : null,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      isChapterExpanded
                                                                          ? Icons.keyboard_arrow_up_rounded
                                                                          : Icons.keyboard_arrow_down_rounded,
                                                                      size: 18,
                                                                      color: Colors.grey.shade400,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isChapterExpanded)
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 48, top: 4, bottom: 8),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: getSubTopicsForChapter(topic.name).map((subTopic) {
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    width: 5,
                                                                    height: 5,
                                                                    decoration: const BoxDecoration(
                                                                      color: Color(0xFF006A63),
                                                                      shape: BoxShape.circle,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      subTopic,
                                                                      style: GoogleFonts.plusJakartaSans(
                                                                        fontSize: 12,
                                                                        color: const Color(0xFF594042).withOpacity(0.8),
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              }),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      onPressed: () => _showEditSubjectDialog(context, actualIndex),
                                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF006A63), size: 20),
                                                    ),
                                                    IconButton(
                                                      onPressed: () => _showAddTopicDialog(context, actualIndex),
                                                      icon: const Icon(Icons.add_task_rounded, color: Color(0xFF006A63), size: 20),
                                                    ),
                                                    IconButton(
                                                      onPressed: () => _showAiSummaryDialog(context, subject),
                                                      icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 20),
                                                    ),
                                                  ],
                                                ),
                                                IconButton(
                                                  onPressed: () => _deleteSubject(actualIndex),
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  crossFadeState: isExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 250),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    ),
              const SizedBox(height: 24),

              // 8. Quick Actions Card Banner matching mockup exactly
              if (subjects.isNotEmpty)
                _buildGlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      // 3D open book illustration on left
                      const FloatingAsset(
                        assetPath: "assets/images/open_book_3d.png",
                        width: 56,
                        height: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Want to add a new subject?",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Add your subject manually or import your syllabus from a PDF",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Buttons stacked on the right
                      Column(
                        children: [
                          AnimatedGlassButton(
                            text: "Add Subject",
                            icon: Icons.add_rounded,
                            isPrimary: true,
                            onPressed: () => _showAddSubjectModal(context),
                          ),
                          const SizedBox(height: 8),
                          AnimatedGlassButton(
                            text: "Import PDF",
                            icon: Icons.file_upload_outlined,
                            isPrimary: false,
                            onPressed: () => _showImportSyllabusModal(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSettingsTab() {
    // -- computed summary values --------------------------------------------------
    final int daysLeft     = getDaysLeft() > 0 ? getDaysLeft() : 0;
    final int hoursPerDay  = _plannerHoursPerDay;
    final statistics = StudyStateManager.instance.statistics;
    final bool hasGeneratedPlan = studyPlan.isNotEmpty;
    final int totalHours = (statistics.weeklyGoalMinutes / 60).ceil();
    final int remainingHours = ((statistics.weeklyGoalMinutes - statistics.weeklyCompletedMinutes).clamp(0, statistics.weeklyGoalMinutes) / 60).ceil();
    final int subjectsCount = subjects.length;

    // -- option lists -------------------------------------------------------------
    const studyStyles      = ["Balanced", "Intensive", "Revision Focused"];
    const breakOptions     = [5, 10, 15, 20, 30];
    const difficultyOptions = ["Easy", "Moderate", "Hard"];
    const timeOptions      = ["Morning", "Afternoon", "Evening", "Night"];

    final bool canGenerate =
        _plannerHoursPerDay > 0 && selectedDate != null && subjects.isNotEmpty;

    // -- helpers ------------------------------------------------------------------
    Widget fieldRow({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String label,
      required Widget field,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8D7072),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  field,
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget chipSelector<T>({
      required List<T> options,
      required T selected,
      required ValueChanged<T> onSelect,
      required Color activeColor,
    }) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final bool active = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? activeColor.withOpacity(0.12)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active ? activeColor : const Color(0xFFE2E8F0),
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                opt.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? activeColor : const Color(0xFF594042),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    Widget summaryTile({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String value,
      required String label,
      required Color bg,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8D7072),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // -- hours stepper widget -----------------------------------------------------
    Widget hoursStepper() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Decrement
            GestureDetector(
              onTap: () {
                if (_plannerHoursPerDay > 1) {
                  _updateSettings(hours: _plannerHoursPerDay - 1);
                }
              },
              child: Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    bottomLeft: Radius.circular(13),
                  ),
                  color: _plannerHoursPerDay > 1
                      ? const Color(0xFFE8F5F1)
                      : Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.remove_rounded,
                  size: 20,
                  color: _plannerHoursPerDay > 1
                      ? const Color(0xFF006A63)
                      : Colors.grey.shade400,
                ),
              ),
            ),
            // Value display
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_plannerHoursPerDay',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF006A63),
                    ),
                  ),
                  Text(
                    'hrs / day',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8D7072),
                    ),
                  ),
                ],
              ),
            ),
            // Increment
            GestureDetector(
              onTap: () {
                if (_plannerHoursPerDay < 16) {
                  _updateSettings(hours: _plannerHoursPerDay + 1);
                }
              },
              child: Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(13),
                    bottomRight: Radius.circular(13),
                  ),
                  color: _plannerHoursPerDay < 16
                      ? const Color(0xFFE8F5F1)
                      : Colors.grey.shade100,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: _plannerHoursPerDay < 16
                      ? const Color(0xFF006A63)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Future<void> _showAddEditWindowDialog(BuildContext context, int? index, StudyAvailability? window) async {
      final bool isEdit = index != null && window != null;
      
      TimeOfDay startTime = const TimeOfDay(hour: 14, minute: 0);
      TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);
      
      if (isEdit) {
        final startParts = window.startTime.split(':');
        final endParts = window.endTime.split(':');
        if (startParts.length >= 2) {
          startTime = TimeOfDay(
            hour: int.tryParse(startParts[0]) ?? 14,
            minute: int.tryParse(startParts[1]) ?? 0,
          );
        }
        if (endParts.length >= 2) {
          endTime = TimeOfDay(
            hour: int.tryParse(endParts[0]) ?? 16,
            minute: int.tryParse(endParts[1]) ?? 0,
          );
        }
      }
      
      showDialog(
        context: context,
        builder: (context) {
          TimeOfDay selectedStart = startTime;
          TimeOfDay selectedEnd = endTime;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              String formatTimeOfDay(TimeOfDay tod) {
                final hr = tod.hour.toString().padLeft(2, '0');
                final min = tod.minute.toString().padLeft(2, '0');
                return "$hr:$min";
              }
              
              return AlertDialog(
                backgroundColor: const Color(0xFFF9F9FC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text(
                  isEdit ? "Edit Availability Window" : "Add Availability Window",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        "Start Time",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        formatTimeOfDay(selectedStart),
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF006A63), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.access_time_rounded, color: Color(0xFF006A63)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedStart,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedStart = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(
                        "End Time",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        formatTimeOfDay(selectedEnd),
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF006A63), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      trailing: const Icon(Icons.access_time_rounded, color: Color(0xFF006A63)),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedEnd,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedEnd = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF594042), fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final windowObj = StudyAvailability(
                        weekday: _selectedPlannerDay,
                        startTime: formatTimeOfDay(selectedStart),
                        endTime: formatTimeOfDay(selectedEnd),
                      );
                      
                      if (isEdit) {
                        StudyStateManager.instance.editAvailabilityWindow(index, windowObj);
                      } else {
                        StudyStateManager.instance.addAvailabilityWindow(windowObj);
                      }
                      
                      Navigator.pop(context);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006A63),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isEdit ? "Save" : "Add",
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Widget availabilityPlanner() {
      final state = StudyStateManager.instance;
      final availability = state.getAvailability();
      
      final dayWindows = availability.where((w) => w.weekday == _selectedPlannerDay).toList();
      final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: weekdays.map((day) {
                final bool isSelected = _selectedPlannerDay == day;
                final int windowCount = availability.where((w) => w.weekday == day).length;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPlannerDay = day;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF006A63)
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF006A63)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF006A63).withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Text(
                          day,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF1A1C1E),
                          ),
                        ),
                        if (windowCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFE8F5F1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "$windowCount",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF006A63),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          
          if (dayWindows.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, color: Colors.grey.shade400, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    "No study availability defined for $_selectedPlannerDay",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF594042),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayWindows.length,
              itemBuilder: (context, index) {
                final window = dayWindows[index];
                final actualIdx = availability.indexOf(window);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8F5F1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Color(0xFF006A63), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            "${window.startTime} - ${window.endTime}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF006A63), size: 18),
                            onPressed: () => _showAddEditWindowDialog(context, actualIdx, window),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                            onPressed: () {
                              StudyStateManager.instance.deleteAvailabilityWindow(actualIdx);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          
          GestureDetector(
            onTap: () => _showAddEditWindowDialog(context, null, null),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF006A63).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Color(0xFF006A63), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "Add Window",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF006A63),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // -- fade-in wrapper ----------------------------------------------------------
    Widget fadeIn({required Widget child, int delayMs = 0}) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + delayMs),
        curve: Curves.easeOut,
        builder: (context, val, ch) => Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - val)),
            child: ch,
          ),
        ),
        child: child,
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // -- Hero card ----------------------------------------------------------
          fadeIn(
            delayMs: 0,
            child: _buildGlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Study Planner",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Create your personalized study schedule powered by intelligent planning.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF594042),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Premium robot illustration built with Flutter primitives.
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF5C77).withOpacity(0.12),
                          const Color(0xFF006A63).withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFFF5C77).withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 12,
                          child: Container(
                            width: 42,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFFFF), Color(0xFFFFE4E8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5C77).withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF006A63),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF5C77),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 7,
                          child: Container(
                            width: 2,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFF006A63).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5C77),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          child: Container(
                            width: 34,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8AA0), Color(0xFFFF5C77)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5C77).withOpacity(0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 13,
                          bottom: 22,
                          child: Icon(Icons.circle, size: 8, color: const Color(0xFF006A63).withOpacity(0.35)),
                        ),
                        Positioned(
                          right: 13,
                          bottom: 22,
                          child: Icon(Icons.circle, size: 8, color: const Color(0xFFFF5C77).withOpacity(0.35)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // -- Form card ----------------------------------------------------------
          fadeIn(
            delayMs: 80,
            child: _buildGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plan Preferences",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Daily Study Availability Planner
                  fieldRow(
                    icon: Icons.calendar_view_week_rounded,
                    iconColor: const Color(0xFF006A63),
                    iconBg: const Color(0xFFE8F5F1),
                    label: "DAILY STUDY AVAILABILITY",
                    field: availabilityPlanner(),
                  ),

                  // Exam Date
                  fieldRow(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF3E8FF),
                    label: "EXAM / DEADLINE DATE",
                    field: GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedDate != null
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFE2E8F0),
                            width: selectedDate != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate == null
                                  ? "Select date"
                                  : _formatDate(selectedDate!),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selectedDate == null
                                    ? Colors.grey.shade400
                                    : const Color(0xFF1A1C1E),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: selectedDate != null
                                  ? const Color(0xFF7C3AED)
                                  : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Study Style
                  fieldRow(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFFFF5C77),
                    iconBg: const Color(0xFFFFE4E8),
                    label: "STUDY STYLE",
                    field: chipSelector<String>(
                      options: studyStyles,
                      selected: _plannerStudyStyle,
                      activeColor: const Color(0xFFFF5C77),
                      onSelect: (v) => _updateSettings(style: v),
                    ),
                  ),

                  // Break Duration
                  fieldRow(
                    icon: Icons.coffee_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFFFFEDD5),
                    label: "BREAK DURATION",
                    field: chipSelector<int>(
                      options: breakOptions,
                      selected: _plannerBreakDuration,
                      activeColor: const Color(0xFFEA580C),
                      onSelect: (v) => _updateSettings(breakDuration: v),
                    ),
                  ),

                  // Difficulty Preference
                  fieldRow(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFE0E7FF),
                    label: "DIFFICULTY PREFERENCE",
                    field: chipSelector<String>(
                      options: difficultyOptions,
                      selected: _plannerDifficultyPref,
                      activeColor: const Color(0xFF4F46E5),
                      onSelect: (v) => _updateSettings(difficulty: v),
                    ),
                  ),

                  // Preferred Study Time
                  fieldRow(
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFFFEF3C7),
                    label: "PREFERRED STUDY TIME",
                    field: chipSelector<String>(
                      options: timeOptions,
                      selected: _plannerPreferredTime,
                      activeColor: const Color(0xFFF59E0B),
                      onSelect: (v) => _updateSettings(preferredTime: v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // -- AI Plan Summary card -----------------------------------------------
          fadeIn(
            delayMs: 160,
            child: _buildGlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C77).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFFFF5C77), size: 17),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "AI Plan Summary",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1C1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!hasGeneratedPlan)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'Generate your AI plan to see its study summary.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF8D7072),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else ...[
                  Row(
                    children: [
                      summaryTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        iconBg: const Color(0xFFF3E8FF),
                        value: daysLeft > 0 ? "$daysLeft" : "--",
                        label: "Days Left",
                        bg: const Color(0xFFF3E8FF).withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      summaryTile(
                        icon: Icons.access_time_rounded,
                        iconColor: const Color(0xFF006A63),
                        iconBg: const Color(0xFFE8F5F1),
                        value: totalHours > 0 ? "$totalHours hrs" : "--",
                        label: "Study Hours",
                        bg: const Color(0xFFE8F5F1).withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      summaryTile(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: const Color(0xFFEA580C),
                        iconBg: const Color(0xFFFFEDD5),
                        value: remainingHours > 0 ? "$remainingHours hrs" : "0 hrs",
                        label: "Remaining",
                        bg: const Color(0xFFFFEDD5).withOpacity(0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      summaryTile(
                        icon: Icons.book_rounded,
                        iconColor: const Color(0xFF4F46E5),
                        iconBg: const Color(0xFFE0E7FF),
                        value: subjectsCount > 0 ? "$subjectsCount" : "--",
                        label: "Subjects",
                        bg: const Color(0xFFE0E7FF).withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      summaryTile(
                        icon: Icons.track_changes_rounded,
                        iconColor: const Color(0xFFFF5C77),
                        iconBg: const Color(0xFFFFE4E8),
                        value: _plannerDifficultyPref,
                        label: "Difficulty",
                        bg: const Color(0xFFFFE4E8).withOpacity(0.4),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // -- Generate button ----------------------------------------------------
          fadeIn(
            delayMs: 240,
            child: _PlannerGenerateButton(
              canGenerate: canGenerate,
              isLoading: _isLoading,
              onTap: () { if (canGenerate && !_isLoading) generateStudyPlan(); },
            ),
          ),

          // Hint
          if (!canGenerate) ...[
            const SizedBox(height: 12),
            Text(
              subjects.isEmpty
                  ? "Add subjects in the Subjects tab first."
                  : hoursPerDay == 0
                      ? "Set your daily study hours above."
                      : "Select an exam date to enable generation.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF8D7072),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Future<void> generateStudyPlan() async {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add some subjects first!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await StudyStateManager.instance.generatePlanFromAvailability();

      setState(() {
        _currentTab = 1; // Redirect to Schedule Tasks timeline
      });
      EggyController.instance.currentTab = 1;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Study Plan generated successfully from availability windows!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate plan: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    Widget currentTabWidget;
    String tabTitle = "Dashboard";

    switch (_currentTab) {
      case 0:
        currentTabWidget = _buildDashboardTab();
        tabTitle = "Dashboard";
        break;
      case 1:
        currentTabWidget = TasksTabScreen(
          studyPlan: studyPlan,
          completedTasks: completedTasks,
          onToggleTask: _toggleTask,
          onStartTimer: (hours, subject) {
            setState(() {
              _currentTab = 0;
            });
            EggyController.instance.currentTab = 0;
            _triggerTaskTimer(hours, subject);
          },
          onRegenerate: () {
            setState(() {
              _currentTab = 4; // Redirect to Study Plan Setup tab
            });
            EggyController.instance.currentTab = 4;
          },
          onDeleteTask: _deleteTask,
          onEditTask: _editTask,
          onAddTask: _addTask,
        );
        tabTitle = "Schedule Tasks";
        break;
      case 2:
        currentTabWidget = _buildSubjectsTab();
        tabTitle = "Subjects & Syllabus";
        break;
      case 3:
        currentTabWidget = _buildStudyRoomTab();
        tabTitle = "Study Room";
        break;
      case 4:
        currentTabWidget = _buildSettingsTab();
        tabTitle = "Study Plan";
        break;
      default:
        currentTabWidget = _buildDashboardTab();
        tabTitle = "AI Study Planner";
    }

    return Scaffold(
      floatingActionButton: _currentTab == 2
          ? Container(
              margin: const EdgeInsets.only(bottom: 74),
              width: 56,
              height: 56,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF006A63).withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF006A63).withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAddSubjectModal(context),
                        child: const Center(
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ) : null,

      appBar: (_currentTab == 0 || _currentTab == 1 || _currentTab == 2)
          ? null
          : AppBar(
              title: Text(tabTitle, style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFFFFFDF6),
              elevation: 0,
            ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: currentTabWidget,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2130).withOpacity(0.85), // Soft dark glass capsule
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Translucent Sliding Liquid Glass Indicator using Fractional Alignment Math
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(-1.0 + _currentTab * 0.5, 0.0),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      child: FractionallySizedBox(
                        widthFactor: 0.2, // 1/5 of the total width
                        child: Center(
                          child: SizedBox(
                            width: 92, // Premium width between 88-96px
                            height: 48, // Reduced to 48px for visual balance
                            child: LiquidGlassIndicator(currentTab: _currentTab),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Navigation destinations overlay
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(child: _buildFloatingNavItem(0, Icons.dashboard_rounded, "Dashboard")),
                        Expanded(child: _buildFloatingNavItem(1, Icons.assignment_rounded, "Tasks")),
                        Expanded(child: _buildFloatingNavItem(2, Icons.book_rounded, "Subjects")),
                        Expanded(child: _buildFloatingNavItem(3, Icons.hourglass_empty_rounded, "Study Room")),
                        Expanded(child: _buildFloatingNavItem(4, Icons.settings_suggest_rounded, "Setup")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B887C)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Crafting AI Study Plan...",
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Distributing work and planning your calendar...",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        if (_currentTab != index) {
          HapticFeedback.lightImpact();
          setState(() {
            _currentTab = index;
          });
          EggyController.instance.currentTab = index;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          scale: isSelected ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(height: 3),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 8.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassIndicator extends StatefulWidget {
  final int currentTab;
  const LiquidGlassIndicator({super.key, required this.currentTab});

  @override
  State<LiquidGlassIndicator> createState() => _LiquidGlassIndicatorState();
}

class _LiquidGlassIndicatorState extends State<LiquidGlassIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    // Scale bounce sequence during dynamic transit: 1.0 -> 0.96 -> 1.04 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.96).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.04).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_scaleController);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab) {
      _scaleController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: child,
        );
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.24),
                width: 1.5,
              ),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.20),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Soft Inner highlight
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Specular Moving Highlight Gradient Reflection
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      final double offset = -1.5 + (_scaleController.value * 3.0);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.24),
                              Colors.transparent,
                            ],
                            begin: Alignment(offset, -1.0),
                            end: Alignment(offset + 0.5, 1.0),
                            stops: const [0.3, 0.5, 0.7],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class DashboardQuickActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const DashboardQuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<DashboardQuickActionItem> createState() => _DashboardQuickActionItemState();
}

class _DashboardQuickActionItemState extends State<DashboardQuickActionItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.90),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF594042),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String value;
  final String label;

  const _DashboardMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1C1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8D7072),
          ),
        ),
      ],
    );
  }
}

class PremiumTaskCard extends StatefulWidget {
  final String subject;
  final String difficulty;
  final String dueTime;
  final VoidCallback onChecked;
  const PremiumTaskCard({
    super.key,
    required this.subject,
    required this.difficulty,
    required this.dueTime,
    required this.onChecked,
  });

  @override
  State<PremiumTaskCard> createState() => _PremiumTaskCardState();
}

class _PremiumTaskCardState extends State<PremiumTaskCard> {
  double _scale = 1.0;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color badgeText;
    IconData subjectIcon;
    Color iconColor;

    final subLower = widget.subject.toLowerCase();
    if (subLower.contains("physic")) {
      subjectIcon = Icons.blur_on_rounded;
      iconColor = const Color(0xFFEA580C);
    } else if (subLower.contains("chem")) {
      subjectIcon = Icons.science_rounded;
      iconColor = const Color(0xFF059669);
    } else if (subLower.contains("math") || subLower.contains("discret")) {
      subjectIcon = Icons.functions_rounded;
      iconColor = const Color(0xFF7C3AED);
    } else if (subLower.contains("database") || subLower.contains("dbms")) {
      subjectIcon = Icons.storage_rounded;
      iconColor = const Color(0xFF4F46E5);
    } else if (subLower.contains("algorithm") || subLower.contains("structure") || subLower.contains("dsa")) {
      subjectIcon = Icons.code_rounded;
      iconColor = const Color(0xFF2563EB);
    } else {
      subjectIcon = Icons.book_rounded;
      iconColor = const Color(0xFF006A63);
    }

    if (widget.difficulty.toLowerCase() == 'hard') {
      badgeColor = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFBA1A1A);
    } else if (widget.difficulty.toLowerCase() == 'medium') {
      badgeColor = const Color(0xFFFFEDD5);
      badgeText = const Color(0xFFEA580C);
    } else {
      badgeColor = const Color(0xFFE8F5F1);
      badgeText = const Color(0xFF006A63);
    }

    return GestureDetector(
      onTapDown: (_) => setState(() { _scale = 0.97; _isHovered = true; }),
      onTapUp: (_) => setState(() { _scale = 1.0; _isHovered = false; }),
      onTapCancel: () => setState(() { _scale = 1.0; _isHovered = false; }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_isHovered ? 0.8 : 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? iconColor.withOpacity(0.4) : Colors.white.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? iconColor.withOpacity(0.08) : Colors.black.withOpacity(0.02),
                blurRadius: _isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Checkbox(
                value: false,
                onChanged: (val) {
                  if (val == true) {
                    widget.onChecked();
                  }
                },
                activeColor: const Color(0xFF006A63),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(subjectIcon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.dueTime.isNotEmpty
                          ? "Scheduled \u{2022} ${widget.dueTime}"
                          : "Due today",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.difficulty,
                  style: GoogleFonts.plusJakartaSans(
                    color: badgeText,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubjectHeroCard extends StatefulWidget {
  final String userName;
  final int totalSubjects;
  final int totalChapters;
  final int completedChapters;
  final int overallProgress;
  const SubjectHeroCard({
    super.key,
    required this.userName,
    required this.totalSubjects,
    required this.totalChapters,
    required this.completedChapters,
    required this.overallProgress,
  });

  @override
  State<SubjectHeroCard> createState() => _SubjectHeroCardState();
}

class _SubjectHeroCardState extends State<SubjectHeroCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF006A63).withOpacity(0.02),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final double offset = -2.0 + (_controller.value * 4.0);
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.18),
                            Colors.transparent,
                          ],
                          begin: Alignment(offset, -1.0),
                          end: Alignment(offset + 0.5, 1.0),
                          stops: const [0.3, 0.5, 0.7],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Keep going, ${widget.userName.isNotEmpty ? widget.userName : 'Prajwal'}! 👋",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "You're doing great. Stay consistent and achieve more every day.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF594042).withOpacity(0.8),
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Image.asset(
                      "assets/images/books_3d.png",
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.book_rounded, size: 48, color: Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FloatingAsset extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  const FloatingAsset({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
  });

  @override
  State<FloatingAsset> createState() => _FloatingAssetState();
}

class _FloatingAssetState extends State<FloatingAsset> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double offset = 10 * Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -5 + offset),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.asset(
          widget.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.book_rounded, size: 48, color: Color(0xFF6366F1)),
        ),
      ),
    );
  }
}

class AnimatedGlassButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  const AnimatedGlassButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  State<AnimatedGlassButton> createState() => _AnimatedGlassButtonState();
}

class _AnimatedGlassButtonState extends State<AnimatedGlassButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.94;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: widget.isPrimary ? const Color(0xFF006A63) : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isPrimary ? const Color(0xFF006A63) : const Color(0xFF006A63).withOpacity(0.3),
              width: 1.2,
            ),
            boxShadow: [
              if (widget.isPrimary)
                BoxShadow(
                  color: const Color(0xFF006A63).withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: widget.isPrimary ? Colors.white : const Color(0xFF006A63)),
              const SizedBox(width: 6),
              Text(
                widget.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.isPrimary ? Colors.white : const Color(0xFF006A63),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerGenerateButton extends StatefulWidget {
  final bool canGenerate;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlannerGenerateButton({
    required this.canGenerate,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PlannerGenerateButton> createState() => _PlannerGenerateButtonState();
}

class _PlannerGenerateButtonState extends State<_PlannerGenerateButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (!widget.canGenerate || widget.isLoading) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.canGenerate && !widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 58,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFF5C77), Color(0xFF006A63)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.4),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF5C77).withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Generate My AI Plan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
