import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'subject_detail_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/study_timer_sheet.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
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
    loadData();
    EggyController.instance.isVisible = true;
    EggyController.instance.currentTab = _currentTab;
  }

  @override
  void dispose() {
    pomodoroTimer?.cancel();
    _studyRoomTimer?.cancel();
    subjectController.dispose();
    hoursController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("subjects", jsonEncode(subjects.map((e) => e.toJson()).toList()));
    await prefs.setStringList("studyPlan", studyPlan);
    await prefs.setString("completedTasks", jsonEncode(completedTasks));
    await prefs.setString("hours", hoursController.text);
    await prefs.setString("difficulty", selectedDifficulty);
    await prefs.setString("weeklyProgressHours", jsonEncode(weeklyProgressHours));

    if (selectedDate != null) {
      await prefs.setString("examDate", selectedDate!.toIso8601String());
    }
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final subjectsData = prefs.getString("subjects");
    final planData = prefs.getStringList("studyPlan");
    final tasksData = prefs.getString("completedTasks");
    final hours = prefs.getString("hours");
    final difficulty = prefs.getString("difficulty");
    final examDate = prefs.getString("examDate");
    final progressData = prefs.getString("weeklyProgressHours");

    final course = prefs.getString("user_course") ?? "";
    final year = prefs.getString("user_year") ?? "";
    final strategy = prefs.getString("onboarding_strategy") ?? "";
    final name = prefs.getString("user_name") ?? "";
    final mascot = prefs.getString("user_mascot") ?? "assets/images/mascot_boy.png";

    setState(() {
      userCourse = course;
      userYear = year;
      onboardingStrategy = strategy;
      userName = name;
      userMascot = mascot;

      if (subjectsData != null) {
        subjects = (jsonDecode(subjectsData) as List)
            .map((e) => Subject.fromJson(e))
            .toList();
      }
      EggyController.instance.userCourse = course;

      if (planData != null) {
        studyPlan = planData;
      }

      if (tasksData != null) {
        completedTasks = List<bool>.from(jsonDecode(tasksData));
      }

      if (hours != null) {
        hoursController.text = hours;
      }

      if (difficulty != null) {
        selectedDifficulty = difficulty;
      }

      if (examDate != null) {
        selectedDate = DateTime.parse(examDate);
      }

      if (progressData != null) {
        final Map<String, dynamic> decoded = jsonDecode(progressData);
        weeklyProgressHours = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      }

      // Check list sizes match to prevent errors
      if (studyPlan.length != completedTasks.length) {
        completedTasks = List.generate(studyPlan.length, (_) => false);
      }
    });
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
      setState(() {
        selectedDate = picked;
      });
      await saveData();
    }
  }

  Future<void> _deleteSubject(int index) async {
    setState(() {
      subjects.removeAt(index);
    });
    await saveData();
  }

  void _addTask(String subject, String difficulty, int duration) {
    setState(() {
      studyPlan.add("$subject ($difficulty) - $duration mins");
      completedTasks.add(false);
    });
    saveData();
  }

  void _deleteTask(int index) {
    setState(() {
      if (index >= 0 && index < studyPlan.length) {
        studyPlan.removeAt(index);
        completedTasks.removeAt(index);
      }
    });
    saveData();
  }

  void _editTask(int index, String subject, String difficulty, String hours) {
    setState(() {
      if (index >= 0 && index < studyPlan.length) {
        studyPlan[index] = "$subject ($difficulty) - $hours";
      }
    });
    saveData();
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

    // Dynamic metrics presentation based on toggled selectedPeriod
    final int displayLessons = isWeekly ? completedCount : (completedCount * 4);
    final double displayHours = isWeekly ? loggedHoursTotal : (loggedHoursTotal * 4.2);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPillBar("Week 1", (loggedHoursTotal / 5) * 1.1 + 6.2, maxTarget: 12.0),
                _buildPillBar("Week 2", (loggedHoursTotal / 5) * 0.9 + 8.1, maxTarget: 12.0),
                _buildPillBar("Week 3", (loggedHoursTotal / 5) * 1.2 + 7.4, maxTarget: 12.0),
                _buildPillBar("Week 4", (loggedHoursTotal / 5) * 0.8 + 9.5, maxTarget: 12.0),
              ],
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
    final double progress = getProgress();
    final int totalTasks = studyPlan.length;
    final int completedCount = completedTasks.where((task) => task).length;

    // Filter up to 3 uncompleted tasks for the dashboard checklist widget
    final List<Map<String, dynamic>> upcomingTasks = [];
    for (int i = 0; i < studyPlan.length; i++) {
      if (!completedTasks[i]) {
        final planItem = studyPlan[i];
        final regex = RegExp(r'^(.+)\s+\((Easy|Medium|Hard)\)\s+-\s+(.+)$', caseSensitive: false);
        final match = regex.firstMatch(planItem);
        if (match != null) {
          upcomingTasks.add({
            'index': i,
            'subject': match.group(1)!,
            'difficulty': match.group(2)!,
            'hours': match.group(3)!,
          });
        } else {
          upcomingTasks.add({
            'index': i,
            'subject': planItem,
            'difficulty': 'Medium',
            'hours': '1 hr',
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
                                      "Keep going! ðŸ’ª",
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
                            _buildQuickActionItem(
                              icon: Icons.playlist_add_check_rounded,
                              label: "New Task",
                              bgColor: const Color(0xFFE8F5F1),
                              iconColor: const Color(0xFF006A63),
                              onTap: () => _showAddTaskDialogOnDashboard(context),
                            ),
                            _buildQuickActionItem(
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
                            _buildQuickActionItem(
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
                            _buildQuickActionItem(
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
                // Tasks Checklist Section (Glass card)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Upcoming Tasks",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _currentTab = 1;
                              });
                              EggyController.instance.currentTab = 1;
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
                      const SizedBox(height: 8),
                      _buildGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: upcomingTasks.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "No upcoming tasks! ðŸŽ‰",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: const Color(0xFF8D7072),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: upcomingTasks.length,
                                itemBuilder: (context, index) {
                                  final task = upcomingTasks[index];
                                  final int taskIndex = task['index'];
                                  final String subject = task['subject'];
                                  final String difficulty = task['difficulty'];

                                  Color badgeColor;
                                  Color badgeText;
                                  if (difficulty.toLowerCase() == 'hard') {
                                    badgeColor = const Color(0xFFFEE2E2);
                                    badgeText = const Color(0xFFBA1A1A);
                                  } else if (difficulty.toLowerCase() == 'medium') {
                                    badgeColor = const Color(0xFFFFEDD5);
                                    badgeText = const Color(0xFFEA580C);
                                  } else {
                                    badgeColor = const Color(0xFFE8F5F1);
                                    badgeText = const Color(0xFF006A63);
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: false,
                                          onChanged: (val) {
                                            if (val == true) {
                                              _toggleTask(taskIndex, true);
                                            }
                                          },
                                          activeColor: const Color(0xFF006A63),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject,
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
                                                "Due today Ã¢â‚¬Â¢ 2:00 PM",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: badgeColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            difficulty,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: badgeText,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "28Â°C",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A1C1E),
                                    ),
                                  ),
                                  const Icon(Icons.wb_cloudy_outlined, color: Color(0xFFEAA300), size: 20),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Partly Cloudy",
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
                                        "San Francisco",
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
                content: Text("Ã°Å¸Å½â€° Focus session completed: $_studyRoomDurationMinutes mins of $_studyRoomSelectedSubject!"),
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

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Good morning,",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            "${userName.toLowerCase().contains('prajwal') ? 'Prajwal' : (userName.isNotEmpty ? userName : 'Alex')}! ðŸ‘‹",
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

    // Filter subjects based on query
    final filteredSubjects = subjects.where((s) {
      return s.name.toLowerCase().contains(_subjectSearchQuery.toLowerCase());
    }).toList();

    // Stats calculations
    int totalTopics = 0;
    int completedTopics = 0;
    for (final s in subjects) {
      totalTopics += s.topics.length;
      completedTopics += s.topics.where((t) => t.isCompleted).length;
    }
    final double completionRate = totalTopics == 0 ? 0.0 : (completedTopics / totalTopics);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_getDashboardBackdrop()),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.9),
            BlendMode.lighten,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // 1. Header Title & Subtitle (Clean greeting styled like dashboard)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Good Morning,",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "${userName.toLowerCase().contains('prajwal') ? 'Prajwal' : (userName.isNotEmpty ? userName : 'Alex')}! Ã°Å¸â€œÅ¡",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF006A63),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Continue building your learning journey.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF8D7072),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Search Bar directly below the title
              _buildGlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _subjectSearchQuery = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF1A1C1E)),
                  decoration: InputDecoration(
                    hintText: "Search your syllabus...",
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF006A63)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Add Subject Card (Always visible Hero Component)
              _buildGlassCard(
                borderRadius: 28,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Add New Subject",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      onChanged: (val) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: "Enter subject name...",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.book_rounded, color: Color(0xFF006A63)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF006A63), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    _buildSuggestionsList(),
                    const SizedBox(height: 16),
                    Text(
                      "Difficulty Level",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8D7072),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Apple-style difficulty selector capsules
                    Row(
                      children: ["Easy", "Medium", "Hard"].map((difficulty) {
                        final bool isSelected = selectedDifficulty == difficulty;
                        Color color;
                        Color bgColor;
                        switch (difficulty) {
                          case "Easy":
                            color = const Color(0xFF2563EB); // Soft blue glass
                            bgColor = const Color(0xFFE0E7FF);
                            break;
                          case "Medium":
                            color = const Color(0xFFD97706); // Warm amber glass
                            bgColor = const Color(0xFFFFEDD5);
                            break;
                          default:
                            color = const Color(0xFFDC2626); // Subtle red glass
                            bgColor = const Color(0xFFFEE2E2);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: AnimatedScale(
                            scale: isSelected ? 1.06 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedDifficulty = difficulty;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? bgColor : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? color : Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ] : [],
                                ),
                                child: Text(
                                  difficulty,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isSelected ? color : const Color(0xFF594042),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Morphing CTA Load button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isAddingSubject ? null : addSubject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006A63),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_isAddingSubject ? 25 : 20),
                          ),
                        ),
                        child: _isAddingSubject
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add Subject",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Subject List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Your Syllabus Tracker",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                  Text(
                    "${filteredSubjects.length} subjects",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF8D7072),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              filteredSubjects.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: _buildGlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.book_outlined, size: 48, color: Color(0xFF006A63)),
                            const SizedBox(height: 12),
                            Text(
                              "Your learning journey starts here.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final subject = filteredSubjects[index];
                        final int actualIndex = subjects.indexOf(subject);
                        final colorIndex = actualIndex % bgColors.length;
                        final textColor = textColors[colorIndex];
                        final bool isExpanded = _expandedSubjectIndices.contains(actualIndex);

                        final double progressPercent = subject.topics.isEmpty
                            ? 0.0
                            : (subject.topics.where((t) => t.isCompleted).length / subject.topics.length);

                        Color diffColor;
                        Color diffBg;
                        switch (subject.difficulty) {
                          case "Easy":
                            diffColor = const Color(0xFF2563EB);
                            diffBg = const Color(0xFFE0E7FF);
                            break;
                          case "Medium":
                            diffColor = const Color(0xFFD97706);
                            diffBg = const Color(0xFFFFEDD5);
                            break;
                          default:
                            diffColor = const Color(0xFFDC2626);
                            diffBg = const Color(0xFFFEE2E2);
                        }

                        return Dismissible(
                          key: Key(subject.name + actualIndex.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBA1A1A).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) => _deleteSubject(actualIndex),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AnimatedScale(
                              scale: isExpanded ? 1.02 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
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
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: diffBg,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.bookmark_rounded, color: diffColor, size: 20),
                                                ),
                                                const SizedBox(width: 14),
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
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: diffBg,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              subject.difficulty,
                                                              style: GoogleFonts.plusJakartaSans(
                                                                color: diffColor,
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            "${subject.topics.length} Chapters",
                                                            style: GoogleFonts.plusJakartaSans(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF8D7072),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF006A63)),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  onSelected: (val) {
                                                    if (val == 'delete') {
                                                      _deleteSubject(actualIndex);
                                                    } else if (val == 'manage') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) => SubjectDetailScreen(
                                                            subject: subject,
                                                            onSubjectChanged: (updatedSubject) async {
                                                              setState(() {
                                                                subjects[actualIndex] = updatedSubject;
                                                              });
                                                              await saveData();
                                                            },
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'manage',
                                                      child: Text("Manage Syllabus"),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text("Delete Subject", style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: progressPercent,
                                                      minHeight: 6,
                                                      backgroundColor: Colors.white.withOpacity(0.4),
                                                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  "${(progressPercent * 100).round()}%",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF1A1C1E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Next session: Tomorrow Ã¢â‚¬Â¢ 9:00 AM",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                color: Colors.grey.shade400,
                                                fontWeight: FontWeight.bold,
                                              ),
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
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    child: Text(
                                                      "No topics added. Tap below to manage syllabus!",
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        color: const Color(0xFF8D7072),
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Text(
                                                    "Syllabus Topics",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF8D7072),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ...List.generate(subject.topics.length, (topicIdx) {
                                                    final topic = subject.topics[topicIdx];
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        children: [
                                                          Checkbox(
                                                            value: topic.isCompleted,
                                                            activeColor: const Color(0xFF006A63),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                            onChanged: (val) async {
                                                              setState(() {
                                                                topic.isCompleted = val ?? false;
                                                              });
                                                              await saveData();
                                                            },
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              topic.name,
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 13,
                                                                color: const Color(0xFF1A1C1E),
                                                                decoration: topic.isCompleted
                                                                    ? TextDecoration.lineThrough
                                                                    : null,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                                const SizedBox(height: 16),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => SubjectDetailScreen(
                                                              subject: subject,
                                                              onSubjectChanged: (updatedSubject) async {
                                                                setState(() {
                                                                  subjects[actualIndex] = updatedSubject;
                                                                });
                                                                await saveData();
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(Icons.edit_road_rounded, size: 16),
                                                      label: Text("Manage Syllabus", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: const Color(0xFF006A63),
                                                        side: const BorderSide(color: Color(0xFF006A63)),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                      ),
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
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 20),

              // 5. Two Compact Statistics Cards at the bottom
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 100,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F1).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE8F5F1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${subjects.length}",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1C1E),
                                ),
                              ),
                              const Icon(Icons.collections_bookmark_outlined, color: Color(0xFF006A63), size: 18),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Subjects",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF594042),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Registered this term",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 100,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF022C22)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFF34D399), size: 18),
                          const SizedBox(height: 4),
                          Text(
                            "${(completionRate * 100).round()}% Completion",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Total course syllabus covered",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
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
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_suggest_rounded, color: Color(0xFF3B887C), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        "Plan Preferences",
                        style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    "Study Target per Day",
                    style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "e.g. 4",
                      suffixText: "hours/day",
                      prefixIcon: const Icon(Icons.timer),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Select Exam/Deadline Date",
                    style: GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Color(0xFF3B887C)),
                              const SizedBox(width: 12),
                              Text(
                                selectedDate == null ? "Select Date" : _formatDate(selectedDate!),
                                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: const Color(0xFF2D3142)),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [Color(0xFF3B887C), Color(0xFFE65C73)]),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B887C).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: generateStudyPlan,
                      child: Text(
                        "Generate AI Study Plan",
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    if (hoursController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please specify daily study hours!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "subjects": subjects.map((e) => e.toJson()).toList(),
        "hours_per_day": (double.tryParse(hoursController.text) ?? 4.0).round(),
        "days_left": getDaysLeft() > 0 ? getDaysLeft() : 30,
      };

      final response = await ApiService.generatePlan(requestBody);
      final List<dynamic> planData = response["study_plan"] ?? [];

      final List<String> formattedPlan = planData.map((e) {
        final map = e as Map<String, dynamic>;
        final String subj = map["subject"] ?? "";
        final String diff = map["difficulty"] ?? "";
        final double hrs = (map["hours"] as num?)?.toDouble() ?? 0.0;
        final String hrsStr = hrs % 1 == 0 ? hrs.toInt().toString() : hrs.toStringAsFixed(1);
        return "$subj ($diff) - $hrsStr hrs/day";
      }).toList();

      setState(() {
        studyPlan = formattedPlan;
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
        _currentTab = 0; // Redirect to Dashboard
      });
      EggyController.instance.currentTab = 0;
      await saveData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Study Plan generated successfully!")),
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
              _currentTab = 3;
            });
            EggyController.instance.currentTab = 3;
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
        tabTitle = "Planner Setup";
        break;            default:
        currentTabWidget = _buildDashboardTab();
        tabTitle = "AI Study Planner";
    }

    return Scaffold(
      appBar: (_currentTab == 0 || _currentTab == 1)
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
