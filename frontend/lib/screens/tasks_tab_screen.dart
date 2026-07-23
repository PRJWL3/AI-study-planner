import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TasksTabScreen extends StatefulWidget {
  final List<String> studyPlan;
  final List<bool> completedTasks;
  final Function(int, bool?) onToggleTask;
  final Function(String, String) onStartTimer;
  final VoidCallback onRegenerate;
  final Function(int) onDeleteTask;
  final Function(int, String, String, String) onEditTask;
  final Function(String, String, int) onAddTask;

  const TasksTabScreen({
    super.key,
    required this.studyPlan,
    required this.completedTasks,
    required this.onToggleTask,
    required this.onStartTimer,
    required this.onRegenerate,
    required this.onDeleteTask,
    required this.onEditTask,
    required this.onAddTask,
  });

  @override
  State<TasksTabScreen> createState() => _TasksTabScreenState();
}

class _TasksTabScreenState extends State<TasksTabScreen> with SingleTickerProviderStateMixin {
  int _selectedDateIndex = 2; // Wednesday 14 selected by default
  bool _isFabMenuOpen = false;
  bool _isFabPressed = false;
  bool _reorderMode = false;
  final Set<int> _expandedTimelineCardIndices = {};

  // Search & Filter state
  String _searchQuery = "";
  String _selectedFilter = "All";

  // Search focus nodes
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  // Pulse animation for current task
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String _selectedDifficulty = "Medium";

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
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

  String _formatHoursToReadable(String hoursStr) {
    final cleaned = hoursStr.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return hoursStr;
    return "$cleaned hr";
  }

  Color _getSemanticColor(String subject, String difficulty, bool isCompleted) {
    if (isCompleted) return const Color(0xFF10B981); // Completed -> Emerald Green
    if (subject.toLowerCase() == "break") return const Color(0xFFF97316); // Break -> Warm Orange
    if (subject.toLowerCase().contains("ai plan") || subject.toLowerCase().contains("generated")) {
      return const Color(0xFF8B5CF6); // AI Generated -> Purple
    }
    switch (difficulty.toLowerCase()) {
      case "easy":
        return const Color(0xFF2563EB); // Easy -> Soft Blue
      case "hard":
        return const Color(0xFFEF4444); // Hard -> Coral Red
      default:
        return const Color(0xFFD97706); // Medium -> Amber
    }
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double borderRadius = 24.0,
    Color? borderOutlineColor,
    double elevation = 0.0,
    Color? glassColor,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(elevation > 0.0 ? 0.06 : 0.02),
            blurRadius: elevation > 0.0 ? 25 : 20,
            spreadRadius: elevation > 0.0 ? 4 : 2,
            offset: Offset(0, elevation > 0.0 ? 12 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: glassColor ?? Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderOutlineColor ?? Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: primary ? const Color(0xFF006A63) : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: primary ? const Color(0xFF006A63) : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: primary ? Colors.white : const Color(0xFF006A63), size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: primary ? Colors.white : const Color(0xFF006A63),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1C1E),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Mini FAB Icon
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Icon(icon, color: const Color(0xFF006A63), size: 20),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    _titleController.clear();
    _durationController.clear();
    setState(() {
      _selectedDifficulty = "Medium";
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF9F9FC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
                      controller: _titleController,
                      style: GoogleFonts.plusJakartaSans(),
                      decoration: InputDecoration(
                        hintText: "e.g. Algebra & Functions",
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
                        final bool isSelected = _selectedDifficulty == difficulty;
                        Color color;
                        switch (difficulty) {
                          case "Easy":
                            color = const Color(0xFF2563EB);
                            break;
                          case "Medium":
                            color = const Color(0xFFD97706);
                            break;
                          default:
                            color = const Color(0xFFDC2626);
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
                              setDlgState(() {
                                _selectedDifficulty = difficulty;
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
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(),
                      decoration: InputDecoration(
                        hintText: "e.g. 90 or 60",
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
                    final String title = _titleController.text.trim();
                    final int? duration = int.tryParse(_durationController.text.trim());
                    if (title.isNotEmpty && duration != null && duration > 0) {
                      widget.onAddTask(title, _selectedDifficulty, duration);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Task '$title' added successfully"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A63),
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

  void _showEditDialog(BuildContext context, int index, String currentSubject, String currentDifficulty, String currentHours) {
    final titleController = TextEditingController(text: currentSubject);
    final hoursController = TextEditingController(text: currentHours);
    String selectedDifficulty = currentDifficulty.isNotEmpty ? currentDifficulty : "Medium";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF9F9FC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                "Edit Task Details",
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
                      "Module Title",
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
                        hintText: "Enter module title",
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
                        final bool isSelected = selectedDifficulty.toLowerCase() == difficulty.toLowerCase();
                        Color color;
                        switch (difficulty) {
                          case "Easy":
                            color = const Color(0xFF2563EB);
                            break;
                          case "Medium":
                            color = const Color(0xFFD97706);
                            break;
                          default:
                            color = const Color(0xFFDC2626);
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
                              setDlgState(() {
                                selectedDifficulty = difficulty;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Estimated Duration",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF594042),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hoursController,
                      style: GoogleFonts.plusJakartaSans(),
                      decoration: InputDecoration(
                        hintText: "e.g. 1.5 hrs/day or 45 min",
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
                    final String newTitle = titleController.text.trim();
                    final String newHrs = hoursController.text.trim();
                    if (newTitle.isNotEmpty && newHrs.isNotEmpty) {
                      widget.onEditTask(index, newTitle, selectedDifficulty, newHrs);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    "Save Changes",
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final monday = now.subtract(Duration(days: currentWeekday - 1));
    final List<Map<String, String>> dates = List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      final daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return {
        "day": daysOfWeek[index],
        "num": "${day.day}",
      };
    });

    // Filter tasks list based on query, selected day index, and category filter
    final List<int> filteredIndices = [];
    for (int i = 0; i < widget.studyPlan.length; i++) {
      final parsed = _parsePlanItem(widget.studyPlan[i]);
      final subject = parsed['subject']!;
      final bool matchesSearch = subject.toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesFilter = true;
      if (_selectedFilter == "Today") {
        matchesFilter = (i % 7 == _selectedDateIndex);
      } else if (_selectedFilter == "Completed") {
        matchesFilter = widget.completedTasks[i] && (i % 7 == _selectedDateIndex);
      } else {
        // "All" filter for selected day
        matchesFilter = (i % 7 == _selectedDateIndex);
      }

      if (matchesSearch && matchesFilter) {
        filteredIndices.add(i);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Scrollable UI Tree
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Unified Page Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Schedule",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Plan your day. Stay focused.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF8D7072),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A1C1E)),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24), // 24px spacing between sections

                // 2. Horizontal Date Selector (Lighter, interactive soft-glass snap)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(dates.length, (idx) {
                      final isSelected = _selectedDateIndex == idx;
                      final d = dates[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDateIndex = idx;
                            });
                          },
                          child: AnimatedScale(
                            scale: isSelected ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // slightly reduced height
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF005953) : Colors.white.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF005953) : Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFF005953).withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    d["day"]!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d["num"]!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : const Color(0xFF1A1C1E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24), // 24px spacing between sections

                // 3. AI Planner Summary Card (Perfect column balance)
                Builder(
                  builder: (context) {
                    double totalHoursToday = 0.0;
                    for (final item in widget.studyPlan) {
                      final parsed = _parsePlanItem(item);
                      final hoursStr = parsed['hours'] ?? '';
                      final hoursMatch = RegExp(r'([\d.]+)').firstMatch(hoursStr);
                      if (hoursMatch != null) {
                        final val = double.tryParse(hoursMatch.group(1)!) ?? 0.0;
                        if (hoursStr.contains('min')) {
                          totalHoursToday += val / 60.0;
                        } else {
                          totalHoursToday += val;
                        }
                      }
                    }
                    int summaryHours = totalHoursToday.floor();
                    int summaryMinutes = ((totalHoursToday - summaryHours) * 60).round();

                    int completedCount = widget.completedTasks.where((task) => task).length;
                    int totalTasks = widget.studyPlan.length;
                    double progress = totalTasks > 0 ? completedCount / totalTasks : 0.0;
                    int progressPct = (progress * 100).round();

                    int nextSessionIdx = -1;
                    for (int k = 0; k < widget.completedTasks.length; k++) {
                      if (!widget.completedTasks[k]) {
                        nextSessionIdx = k;
                        break;
                      }
                    }
                    
                    String nextSubject = "No sessions";
                    String nextTime = "All tasks complete!";
                    String nextTimeAgo = "Done";
                    
                    if (nextSessionIdx != -1) {
                      final parsed = _parsePlanItem(widget.studyPlan[nextSessionIdx]);
                      nextSubject = parsed['subject']!;
                      final List<String> times = [
                        "09:00 AM", "10:45 AM", "12:30 PM", "02:00 PM",
                        "03:45 PM", "05:30 PM", "07:15 PM"
                      ];
                      nextTime = nextSessionIdx < times.length ? times[nextSessionIdx] : "05:00 PM";
                      nextTimeAgo = "next up";
                    }

                    return _buildGlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(20),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // Left Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF006A63), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "AI Planner",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF006A63),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        "${summaryHours}h",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1A1C1E),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${summaryMinutes}m",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1A1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Study Hours Today",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 5,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$progressPct% of daily goal",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      color: const Color(0xFF006A63),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Balanced Center Divider
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: VerticalDivider(width: 2, color: Colors.white30, thickness: 1),
                            ),
                            // Right Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Next Session",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8D7072),
                                        ),
                                      ),
                                      // Starts in 18 min clock indicator badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 8, color: Colors.grey.shade700),
                                            const SizedBox(width: 2),
                                            Text(
                                              nextTimeAgo,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF3E8FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.bookmark_added_rounded, color: Color(0xFF7C3AED), size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nextSubject,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1A1C1E),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              nextTime,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () {
                                      widget.onRegenerate();
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Text(
                                          "View Full Plan",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF006A63),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF006A63), size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24), // 24px spacing between sections

                // 4. Compact Search & Filters Toolbar (Focus glow, taller input)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 44, // Taller input
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSearchFocused ? const Color(0xFF006A63) : Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: _isSearchFocused ? [
                      BoxShadow(
                        color: const Color(0xFF006A63).withOpacity(0.15),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ] : [],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF006A63)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          focusNode: _searchFocusNode,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF1A1C1E)),
                          decoration: InputDecoration(
                            hintText: "Search tasks...",
                            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...["All", "Today", "Completed"].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF006A63) : Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF006A63) : Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                filter,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected ? Colors.white : const Color(0xFF1A1C1E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32), // 32px before major sections

                // 5. Today's Schedule Timeline Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Schedule",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _reorderMode = !_reorderMode;
                        });
                      },
                      icon: const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF006A63)),
                      label: Text(
                        "Reorder",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006A63),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // 16px between section header and list

                // Timeline List
                filteredIndices.isEmpty
                    ? _buildGlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5F1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF006A63), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Your learning journey starts here.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Plan your modules and track your study hours.",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredIndices.length,
                        itemBuilder: (context, idx) {
                          final index = filteredIndices[idx];
                          final planItem = widget.studyPlan[index];
                          final parsed = _parsePlanItem(planItem);
                          final subject = parsed['subject']!;
                          final difficulty = parsed['difficulty']!;
                          final hours = parsed['hours']!;
                          final bool isCompleted = widget.completedTasks[index];
                          int firstUncompletedIdx = -1;
                          for (int k = 0; k < widget.completedTasks.length; k++) {
                            if (!widget.completedTasks[k]) {
                              firstUncompletedIdx = k;
                              break;
                            }
                          }
                          final bool isCurrent = (index == firstUncompletedIdx);
                          final bool isLast = (idx == filteredIndices.length - 1);

                          final List<String> times = [
                            "09:00 AM",
                            "10:45 AM",
                            "12:30 PM",
                            "02:00 PM",
                            "03:45 PM",
                            "05:30 PM",
                            "07:15 PM"
                          ];
                          final String timeVal = index < times.length ? times[index] : "05:00 PM";

                          // Semantic Color Mapping
                          final Color semanticColor = _getSemanticColor(subject, difficulty, isCompleted);
                          final Color semanticBg = semanticColor.withOpacity(0.12);

                          final bool isExpanded = _expandedTimelineCardIndices.contains(index);

                          final double progressPercent = isCompleted ? 1.0 : (isCurrent ? 0.6 : 0.0);

                          Widget cardContent = _buildGlassCard(
                            borderRadius: 24,
                            padding: EdgeInsets.zero,
                            elevation: isCurrent ? 8.0 : 0.0, // Higher elevation shadow for current task
                            glassColor: isCurrent
                                ? Colors.white.withOpacity(0.85) // Brighter glass
                                : Colors.white.withOpacity(0.65),
                            borderOutlineColor: isCurrent
                                ? const Color(0xFF22D3EE).withOpacity(0.8) // Teal glowing outline
                                : Colors.white.withOpacity(0.35),
                            child: Column(
                              children: [
                                // Consistent Fixed Height (90px) Collapsed Row
                                SizedBox(
                                  height: 90,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        // Colored semantic icon box
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: semanticBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            subject.toLowerCase() == "break"
                                                ? Icons.coffee_rounded
                                                : (isCompleted
                                                    ? Icons.check_circle_rounded
                                                    : Icons.science_rounded),
                                            color: semanticColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                subject,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: const Color(0xFF1A1C1E),
                                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subject.toLowerCase() == "break"
                                                    ? "Relax & Recharge ✨"
                                                    : (difficulty.isNotEmpty ? "$difficulty difficulty" : "Study Session"),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              // Progress indicator (Animates on active/pulse)
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(3),
                                                      child: TweenAnimationBuilder<double>(
                                                        tween: Tween<double>(begin: 0.0, end: progressPercent),
                                                        duration: const Duration(milliseconds: 600),
                                                        curve: Curves.easeOutCubic,
                                                        builder: (context, val, _) {
                                                          return LinearProgressIndicator(
                                                            value: val,
                                                            minHeight: 4,
                                                            backgroundColor: Colors.white.withOpacity(0.4),
                                                            valueColor: AlwaysStoppedAnimation<Color>(semanticColor),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  TweenAnimationBuilder<double>(
                                                    tween: Tween<double>(begin: 0.0, end: progressPercent),
                                                    duration: const Duration(milliseconds: 600),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, val, _) {
                                                      return Text(
                                                        "${(val * 100).round()}%",
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF1A1C1E),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Duration (Reduced size/weight metadata) & Menu
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: semanticBg,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _formatHoursToReadable(hours),
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: semanticColor.withOpacity(0.85),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500, // Reduced metadata weight
                                                ),
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF006A63), size: 20),
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                                              ),
                                              color: Colors.white.withOpacity(0.85),
                                              elevation: 8,
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _showEditDialog(context, index, subject, difficulty, hours);
                                                } else if (val == 'delete') {
                                                  widget.onDeleteTask(index);
                                                } else if (val == 'toggle') {
                                                  widget.onToggleTask(index, !isCompleted);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'toggle',
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                                                      const SizedBox(width: 8),
                                                      Text("Complete", style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFD97706)),
                                                      const SizedBox(width: 8),
                                                      Text("Edit", style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                                      const SizedBox(width: 8),
                                                      Text("Delete", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.red)),
                                                    ],
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
                                // Expandable Details Section
                                AnimatedCrossFade(
                                  firstChild: Container(),
                                  secondChild: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Divider(height: 1, color: Colors.white24),
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Planner Details & Syllabus notes",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF8D7072),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              "Prepare core notes, review chapter solutions, and track concepts before marking the module as finished.",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                color: const Color(0xFF1A1C1E),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () => widget.onStartTimer(hours, subject),
                                                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                                  label: Text("Start Timer", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF006A63),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  ),
                                                ),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    _showEditDialog(context, index, subject, difficulty, hours);
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Color(0xFF006A63)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    foregroundColor: const Color(0xFF006A63),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  ),
                                                  child: Text("Edit Task", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
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
                          );

                          // Pulse animation wrapping current task glowing border
                          if (isCurrent) {
                            cardContent = AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF22D3EE).withOpacity(_pulseAnimation.value * 0.25),
                                        blurRadius: 20,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                );
                              },
                              child: cardContent,
                            );
                          }

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Perfectly aligned vertical Timeline node
                                SizedBox(
                                  width: 85, // Increased spacing between timeline and cards
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      // Connecting line running continuously
                                      if (!isLast)
                                        Positioned(
                                          top: 45,
                                          bottom: 0,
                                          child: Container(width: 2.0, color: Colors.grey.shade400),
                                        ),
                                      if (idx > 0)
                                        Positioned(
                                          top: 0,
                                          bottom: 45,
                                          child: Container(width: 2.0, color: Colors.grey.shade400),
                                        ),
                                      // Time stamp text
                                      Positioned(
                                        top: 14,
                                        child: Text(
                                          timeVal,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: isCurrent ? const Color(0xFF006A63) : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Positioned(
                                          top: 66,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF006A63),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "Now",
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Snapped dot centered on the 90px card header
                                      Positioned(
                                        top: 35, // Centered vertically relative to 90px header height (45 center - 10 radius)
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFF10B981)
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isCurrent
                                                  ? const Color(0xFF006A63)
                                                  : (isCompleted ? const Color(0xFF10B981) : Colors.grey.shade300),
                                              width: 2,
                                            ),
                                          ),
                                          child: isCompleted
                                              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                              : (isCurrent ? Container(
                                                  margin: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF006A63),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ) : null),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: cardContent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 32), // 32px before major sections

                // 6. Redesigned Weekly Progress Section Heading
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Weekly Goal progress",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // 16px between section header and list

                // Grouped Weekly Cards of Equal Height (130px)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 130,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F1).withOpacity(0.55),
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
                                  "Weekly Goal",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1C1E),
                                  ),
                                ),
                                Text(
                                  "18 / 24 hrs",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF006A63),
                                  ),
                                ),
                              ],
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                value: 0.75,
                                minHeight: 6,
                                backgroundColor: Colors.white60,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                              ),
                            ),
                            Text(
                              "75% Target completed",
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF594042),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // High-quality day-by-day vertical hours chart visualizer
                    Expanded(
                      child: Container(
                        height: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Daily Hours",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(7, (idx) {
                                  final days = ["M", "T", "W", "T", "F", "S", "S"];
                                  final heights = [28.0, 42.0, 58.0, 36.0, 50.0, 22.0, 14.0];
                                  final active = idx == 2;
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: heights[idx],
                                        decoration: BoxDecoration(
                                          color: active ? const Color(0xFF006A63) : const Color(0xFF006A63).withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        days[idx],
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: active ? const Color(0xFF006A63) : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
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

          // Dimmed backdrop overlay when FAB is active
          if (_isFabMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isFabMenuOpen = false;
                  });
                },
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ),
                ),
              ),
            ),

          // 7. Right-Aligned floating Liquid Glass action button (snaps cleanly above bottom nav capsule)
          Positioned(
            right: 24,
            bottom: 100, // Elevated above bottom navigation bar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isFabMenuOpen) ...[
                  _buildFabMenuItem(
                    label: "Generate AI Plan",
                    icon: Icons.auto_awesome_rounded,
                    onTap: () {
                      setState(() {
                        _isFabMenuOpen = false;
                      });
                      widget.onRegenerate();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabMenuItem(
                    label: "Add Task",
                    icon: Icons.add_rounded,
                    onTap: () {
                      setState(() {
                        _isFabMenuOpen = false;
                      });
                      _showAddTaskDialog(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabMenuItem(
                    label: "Add Break",
                    icon: Icons.coffee_rounded,
                    onTap: () {
                      setState(() {
                        _isFabMenuOpen = false;
                      });
                      widget.onAddTask("Break", "Easy", 30);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabMenuItem(
                    label: "Add Revision Session",
                    icon: Icons.history_edu_rounded,
                    onTap: () {
                      setState(() {
                        _isFabMenuOpen = false;
                      });
                      widget.onAddTask("Revision Session", "Medium", 45);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFabMenuItem(
                    label: "Import Schedule",
                    icon: Icons.calendar_month_rounded,
                    onTap: () {
                      setState(() {
                        _isFabMenuOpen = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Schedule imported successfully!")),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // FAB Trigger Button (Liquid Glass styled)
                GestureDetector(
                  onTapDown: (_) => setState(() => _isFabPressed = true),
                  onTapCancel: () => setState(() => _isFabPressed = false),
                  onTapUp: (_) {
                    setState(() {
                      _isFabPressed = false;
                      _isFabMenuOpen = !_isFabMenuOpen;
                    });
                  },
                  child: AnimatedScale(
                    scale: _isFabPressed ? 0.90 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: AnimatedRotation(
                      turns: _isFabMenuOpen ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF006A63).withOpacity(0.20), // Translucent teal tint glass
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF006A63).withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Icon(
                              _isFabMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                              color: const Color(0xFF006A63),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}