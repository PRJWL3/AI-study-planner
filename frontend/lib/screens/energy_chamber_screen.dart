import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/study_state_manager.dart';
import '../models/subject.dart';

class EnergyChamberScreen extends StatefulWidget {
  final List<String> subjects;
  final Function(double, String) onSessionComplete;

  const EnergyChamberScreen({
    super.key,
    required this.subjects,
    required this.onSessionComplete,
  });

  @override
  State<EnergyChamberScreen> createState() => _EnergyChamberScreenState();
}

class _EnergyChamberScreenState extends State<EnergyChamberScreen> with TickerProviderStateMixin {
  final List<_CelebrationParticle> _celebrationParticles = [];

  void _spawnCelebrationParticles() {
    final random = math.Random();
    _celebrationParticles.clear();
    for (int i = 0; i < 45; i++) {
      final double angle = random.nextDouble() * 2.0 * math.pi;
      final double speed = 4.0 + random.nextDouble() * 10.0;
      _celebrationParticles.add(_CelebrationParticle(
        x: 0.0,
        y: 0.0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: random.nextBool() ? const Color(0xFF00D1C4) : const Color(0xFFFF5C77),
        size: 2.0 + random.nextDouble() * 4.0,
      ));
    }
  }

  // Timer States
  bool _isActive = false;
  bool _isPaused = false;
  int _durationMinutes = 25;
  int _secondsRemaining = 1104; // 18:24 countdown matching mockup
  String _selectedSubject = "Data Structures";
  String _activeTopic = "Arrays & Linked List";
  Timer? _timer;

  // Expanded Orbs description state
  final Set<String> _expandedOrbs = {};

  // Milestone Celebration Overlay State
  bool _showCelebration = false;
  String _celebrationText = "";
  String _celebrationSubtitle = "";

  // Apple Music circular controls scale states
  double _pauseScale = 1.0;
  double _endScale = 1.0;
  double _skipScale = 1.0;

  // Persistent stats (2x2 Grid Analytics)
  int _todayEnergyValue = 1860;
  int _todayEnergyChange = 320;
  int _weeklyEnergyValue = 12450;
  int _weeklyEnergyGoal = 15000;
  int _streakDays = 14;
  int _sessionsCompleted = 3;
  int _sessionsGoal = 6;

  // Real-time Orb Charge percentages
  double _focusCharge = 59.0;   // matching screenshot: 59%
  double _wisdomCharge = 34.0;  // matching screenshot: 34%
  double _masteryCharge = 14.0;  // matching screenshot: 14%

  double _totalHours = 0.0;
  int _avgSessionMinutes = 25;
  int _completedTopics = 0;

  // Animation controllers for premium constant motion
  late AnimationController _ambientController;
  late AnimationController _streamController;
  late AnimationController _orbPulseController;
  late AnimationController _celebrationController;

  // Ambient particles
  final List<math.Point<double>> _ambientParticles = List.generate(45, (index) {
    final random = math.Random();
    return math.Point(random.nextDouble(), random.nextDouble());
  });

  @override
  void initState() {
    super.initState();
    StudyStateManager.instance.addListener(_onStateChanged);
    _loadStats();
 
    // Constant rotation and background shifting controller
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
 
    // High density particle stream flow speed controller
    _streamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
 
    // Orb breathing and float controller
    _orbPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
 
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
 
    _startTimerInterval();
  }
 
  @override
  void dispose() {
    StudyStateManager.instance.removeListener(_onStateChanged);
    _timer?.cancel();
    _ambientController.dispose();
    _streamController.dispose();
    _orbPulseController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (_isActive) return; // Don't interrupt during active study session ticks
    _loadStats();
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

  Map<String, dynamic> _resolveActiveSessionDetails() {
    final state = StudyStateManager.instance;
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final monday = now.subtract(Duration(days: currentWeekday - 1));
    
    DateTime currentStart = DateTime(now.year, now.month, now.day, 9, 0);
    Map<String, dynamic>? activeSession;
    Map<String, dynamic>? nextUpcomingSession;
    
    for (int i = 0; i < state.studyPlan.length; i++) {
      final parsed = state.parsePlanItem(state.studyPlan[i]);
      final hoursStr = parsed['hours'] ?? '';
      double durationMins = 60.0;
      final hoursMatch = RegExp(r'([\d.]+)').firstMatch(hoursStr);
      if (hoursMatch != null) {
        final val = double.tryParse(hoursMatch.group(1)!) ?? 1.0;
        if (hoursStr.contains('min')) {
          durationMins = val;
        } else {
          durationMins = val * 60.0;
        }
      }
      
      DateTime start;
      DateTime end;
      
      if (parsed['startTime'] != null && parsed['startTime']!.isNotEmpty) {
        final dayIndex = int.tryParse(parsed['dayIndex'] ?? '0') ?? 0;
        final sessionDay = monday.add(Duration(days: dayIndex));
        
        final startParts = parsed['startTime']!.split(':');
        final startHr = int.tryParse(startParts[0]) ?? 9;
        final startMin = int.tryParse(startParts[1]) ?? 0;
        
        final endParts = parsed['endTime']!.split(':');
        final endHr = int.tryParse(endParts[0]) ?? 10;
        final endMin = int.tryParse(endParts[1]) ?? 0;
        
        start = DateTime(sessionDay.year, sessionDay.month, sessionDay.day, startHr, startMin);
        end = DateTime(sessionDay.year, sessionDay.month, sessionDay.day, endHr, endMin);
      } else {
        start = currentStart;
        end = start.add(Duration(minutes: durationMins.round()));
        currentStart = end.add(const Duration(minutes: 15));
      }
      
      final sessionInfo = {
        "index": i,
        "dayIndex": parsed['dayIndex'] ?? '0',
        "subject": parsed['subject'] ?? 'General Study',
        "difficulty": parsed['difficulty'] ?? 'Medium',
        "durationMinutes": durationMins.round(),
        "start": start,
        "end": end,
        "isCompleted": state.completedTasks[i],
      };
      
      if (now.isAfter(start) && now.isBefore(end)) {
        activeSession = sessionInfo;
      }
      
      if (now.isBefore(start) && nextUpcomingSession == null && !state.completedTasks[i]) {
        nextUpcomingSession = sessionInfo;
      }
    }
    
    final Map<String, dynamic> selected = activeSession ?? nextUpcomingSession ?? (state.studyPlan.isNotEmpty ? {
      "index": 0,
      "dayIndex": state.parsePlanItem(state.studyPlan[0])['dayIndex'] ?? '0',
      "subject": state.parsePlanItem(state.studyPlan[0])['subject'] ?? 'General Study',
      "difficulty": state.parsePlanItem(state.studyPlan[0])['difficulty'] ?? 'Medium',
      "durationMinutes": 45,
      "start": DateTime(now.year, now.month, now.day, 9, 0),
      "end": DateTime(now.year, now.month, now.day, 9, 45),
      "isCompleted": false,
    } : {
      "index": -1,
      "dayIndex": (now.weekday - 1).toString(),
      "subject": state.studyRoomSelectedSubject,
      "durationMinutes": state.studyRoomDurationMinutes,
      "difficulty": "Medium",
      "start": DateTime(now.year, now.month, now.day, 9, 0),
      "end": DateTime(now.year, now.month, now.day, 9, 0).add(Duration(minutes: state.studyRoomDurationMinutes)),
      "isCompleted": false,
    });
    
    String chapter = "Focus Session";
    String topic = "Deep Concentration";
    
    final matchingSubject = state.subjects.firstWhere(
      (s) => s.name.toLowerCase() == selected['subject'].toString().toLowerCase(),
      orElse: () => Subject(name: selected['subject'].toString(), difficulty: selected['difficulty'].toString()),
    );
    
    if (matchingSubject.topics.isNotEmpty) {
      final uncompletedTopic = matchingSubject.topics.firstWhere(
        (t) => !t.isCompleted,
        orElse: () => matchingSubject.topics.first,
      );
      chapter = uncompletedTopic.name;
      
      final subTopics = getSubTopicsForChapter(chapter);
      if (subTopics.isNotEmpty) {
        topic = subTopics.first;
      }
    }
    
    return {
      "exam": state.userCourse.isNotEmpty ? state.userCourse : "Semester Finals",
      "subject": selected['subject'],
      "chapter": chapter,
      "topic": topic,
      "difficulty": selected['difficulty'],
      "durationMinutes": selected['durationMinutes'],
      "startTime": selected['start'],
      "endTime": selected['end'],
      "index": selected['index'],
      "dayIndex": selected['dayIndex'] ?? '0',
    };
  }

  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final String minuteStr = minute < 10 ? "0$minute" : "$minute";
    return "$hour:$minuteStr $period";
  }

  Future<void> _loadStats() async {
    final state = StudyStateManager.instance;
    final now = DateTime.now();

    int todayEnergyGained = 0;
    for (final ev in state.studyEvents) {
      final ts = DateTime.tryParse(ev['timestamp'] ?? '');
      if (ts != null && ts.year == now.year && ts.month == now.month && ts.day == now.day) {
        if (ev['type'] == 'session') {
          todayEnergyGained += 300;
        } else if (ev['type'] == 'task') {
          todayEnergyGained += 100;
        }
      }
    }

    double totalMinutes = 0.0;
    int sessionCount = 0;
    for (final ev in state.studyEvents) {
      if (ev['type'] == 'session') {
        final double val = (ev['value'] as num?)?.toDouble() ?? 0.0;
        totalMinutes += val;
        sessionCount++;
      }
    }
    final double computedTotalHours = totalMinutes / 60.0;
    final int computedAvgSessionMinutes = sessionCount > 0 ? (totalMinutes / sessionCount).round() : 25;

    int compTopics = 0;
    for (final s in state.subjects) {
      compTopics += s.topics.where((t) => t.isCompleted).length;
    }

    setState(() {
      _streakDays = state.streakDays;
      _todayEnergyValue = state.todayEnergyValue;
      _todayEnergyChange = todayEnergyGained;
      _weeklyEnergyValue = state.weeklyEnergyValue;
      _sessionsCompleted = state.sessionsCompleted;
      _sessionsGoal = state.sessionsGoal;
      _focusCharge = state.focusCharge;
      _wisdomCharge = state.wisdomCharge;
      _masteryCharge = state.masteryCharge;

      _totalHours = computedTotalHours;
      _avgSessionMinutes = computedAvgSessionMinutes;
      _completedTopics = compTopics;

      if (state.isTimerActive) {
        _isActive = true;
        _isPaused = state.isTimerPaused;
        _durationMinutes = state.timerDurationMinutes;
        _selectedSubject = state.timerSelectedSubject;
        _activeTopic = "${state.timerActiveChapter} - ${state.timerActiveTopic}";

        // Recompute remaining seconds from wall-clock so that time elapsed
        // while the app was closed is accounted for correctly.
        if (!_isPaused && state.timerEndTimestamp != null) {
          final int remaining =
              state.timerEndTimestamp!.difference(DateTime.now()).inSeconds;
          _secondsRemaining = remaining.clamp(0, _durationMinutes * 60);
          if (_secondsRemaining <= 0) {
            // Session finished while app was closed — auto-complete.
            Future.microtask(_completeSession);
          }
        } else {
          _secondsRemaining = state.timerSecondsRemaining;
        }

        if (!_isPaused) {
          _streamController.repeat();
        } else {
          _streamController.stop();
        }
      } else {
        _isActive = false;
        _isPaused = false;
        final details = _resolveActiveSessionDetails();
        _durationMinutes = details['durationMinutes'];
        _secondsRemaining = _durationMinutes * 60;
        _selectedSubject = details['subject'];
        _activeTopic = "${details['chapter']} - ${details['topic']}";
      }
    });
  }
 
  Future<void> _saveStats() async {
    final state = StudyStateManager.instance;
    state.streakDays = _streakDays;
    state.todayEnergyValue = _todayEnergyValue;
    state.weeklyEnergyValue = _weeklyEnergyValue;
    state.sessionsCompleted = _sessionsCompleted;
    await state.saveData();
  }

  void _startTimerInterval() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final state = StudyStateManager.instance;
      if (_isActive && !_isPaused) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            
            state.timerSecondsRemaining = _secondsRemaining;
            
            _focusCharge = (_focusCharge + 0.01).clamp(0.0, 100.0);
            _wisdomCharge = (_wisdomCharge + 0.007).clamp(0.0, 100.0);
            _masteryCharge = (_masteryCharge + 0.005).clamp(0.0, 100.0);

            if (_secondsRemaining == 1098) {
              _triggerMilestoneCelebration("Focus Crystal Evolved", "+1 Knowledge Energy");
            }
          } else {
            _completeSession();
          }
        });
      }
    });
  }

  void _triggerMilestoneCelebration(String title, String subtitle) {
    setState(() {
      _showCelebration = true;
      _celebrationText = title;
      _celebrationSubtitle = subtitle;
    });
    _celebrationController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _showCelebration) {
          setState(() {
            _showCelebration = false;
          });
        }
      });
    });
  }

  void _togglePause() {
    final state = StudyStateManager.instance;
    final details = _resolveActiveSessionDetails();
    
    setState(() {
      if (!_isActive) {
        _isActive = true;
        _isPaused = false;
        
        _secondsRemaining = _durationMinutes * 60;
        _selectedSubject = details['subject'];
        _activeTopic = "${details['chapter']} - ${details['topic']}";
        
        state.isTimerActive = true;
        state.isTimerPaused = false;
        state.timerSecondsRemaining = _secondsRemaining;
        state.timerDurationMinutes = _durationMinutes;
        state.timerSelectedSubject = _selectedSubject;
        state.timerActiveChapter = details['chapter'];
        state.timerActiveTopic = details['topic'];
        state.timerTaskIndex = details['index'];
        state.timerEndTimestamp = DateTime.now().add(Duration(seconds: _secondsRemaining));
        state.saveData();
        
        _streamController.repeat();
      } else {
        _isPaused = !_isPaused;
        state.isTimerPaused = _isPaused;
        
        if (_isPaused) {
          _streamController.stop();
          state.timerSecondsRemaining = _secondsRemaining;
          state.timerEndTimestamp = null;
        } else {
          _streamController.repeat();
          state.timerEndTimestamp = DateTime.now().add(Duration(seconds: _secondsRemaining));
        }
        state.saveData();
      }
    });
  }

  void _endSession() {
    _timer?.cancel();
    _streamController.stop();
    
    final state = StudyStateManager.instance;
    final double completedHours = (_durationMinutes * 60 - _secondsRemaining) / 3600.0;
    
    if (completedHours > 0.01) {
      state.completeFocusSession(completedHours, _selectedSubject, ((_durationMinutes * 60 - _secondsRemaining) / 60.0).round());
    }
    
    state.isTimerActive = false;
    state.isTimerPaused = false;
    state.timerSecondsRemaining = 0;
    state.timerEndTimestamp = null;
    state.timerTaskIndex = -1;
    state.saveData();

    setState(() {
      _isActive = false;
      _isPaused = false;
      
      final details = _resolveActiveSessionDetails();
      _durationMinutes = details['durationMinutes'];
      _secondsRemaining = _durationMinutes * 60;
      _selectedSubject = details['subject'];
      _activeTopic = "${details['chapter']} - ${details['topic']}";
      
      _loadStats();
    });

    _triggerMilestoneCelebration("Session Finished", "Energy registered to Chamber");
  }

  void _completeSession() async {
    _timer?.cancel();
    _streamController.stop();
    
    final state = StudyStateManager.instance;
    final double completedHours = _durationMinutes / 60.0;
    
    await state.completeFocusSession(completedHours, _selectedSubject, _durationMinutes);
    if (state.timerTaskIndex >= 0 && state.timerTaskIndex < state.studyPlan.length) {
      state.completedTasks[state.timerTaskIndex] = true;
      await state.saveData();
    }
    
    state.isTimerActive = false;
    state.isTimerPaused = false;
    state.timerSecondsRemaining = 0;
    state.timerEndTimestamp = null;
    state.timerTaskIndex = -1;
    await state.saveData();

    setState(() {
      _isActive = false;
      _isPaused = false;
      
      final details = _resolveActiveSessionDetails();
      _durationMinutes = details['durationMinutes'];
      _secondsRemaining = _durationMinutes * 60;
      _selectedSubject = details['subject'];
      _activeTopic = "${details['chapter']} - ${details['topic']}";
      
      _loadStats();
    });

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.mediumImpact());
    Future.delayed(const Duration(milliseconds: 250), () => HapticFeedback.lightImpact());

    _spawnCelebrationParticles();
    _triggerMilestoneCelebration("Wisdom Crystal Evolved", "+300 Knowledge Energy Generated!");
  }

  // ── Duration override ──────────────────────────────────────────────────────

  /// Shows a +/− dialog to let the user set a custom session duration
  /// (15–240 min, step 5).  Only callable when the timer is not yet active.
  void _showDurationOverrideDialog() {
    if (_isActive) return;

    final int scheduledDuration =
        _resolveActiveSessionDetails()['durationMinutes'] as int;
    int tempDuration = _durationMinutes;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF8FFFE),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              "Session Duration",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1C1E),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Adjust how long this session will run.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: tempDuration > 15
                          ? () => setDialogState(() =>
                              tempDuration =
                                  (tempDuration - 5).clamp(15, 240))
                          : null,
                      icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Color(0xFF006A63)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$tempDuration min",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: tempDuration < 240
                          ? () => setDialogState(() =>
                              tempDuration =
                                  (tempDuration + 5).clamp(15, 240))
                          : null,
                      icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Color(0xFF006A63)),
                    ),
                  ],
                ),
                if (tempDuration != scheduledDuration)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tempDuration > scheduledDuration
                          ? "+${tempDuration - scheduledDuration} min from planned"
                          : "${tempDuration - scheduledDuration} min from planned",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: tempDuration > scheduledDuration
                            ? Colors.orange.shade700
                            : const Color(0xFF006A63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006A63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (tempDuration != scheduledDuration) {
                    // Duration differs from AI plan — ask about schedule
                    _askAdjustRemainingSchedule(
                        tempDuration, scheduledDuration);
                  } else {
                    setState(() {
                      _durationMinutes = tempDuration;
                      _secondsRemaining = tempDuration * 60;
                    });
                  }
                },
                child: Text(
                  "Set Duration",
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Asks whether the remaining sessions for the day should be shifted by
  /// the same delta as the duration change, or whether only the current
  /// session should use the custom duration.
  void _askAdjustRemainingSchedule(
      int newDuration, int scheduledDuration) {
    final int shift = newDuration - scheduledDuration;
    final details = _resolveActiveSessionDetails();
    final int sessionIndex = details['index'] as int;
    final String dayIndex =
        (details['dayIndex'] as String?) ?? '0';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF8FFFE),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Apply to Today's Schedule?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1C1E),
          ),
        ),
        content: Text(
          shift > 0
              ? "This session is $shift min longer than planned. Push remaining sessions today by $shift min, or keep only this session longer?"
              : "This session is ${-shift} min shorter than planned. Pull remaining sessions today forward by ${-shift} min, or keep only this session shorter?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _durationMinutes = newDuration;
                _secondsRemaining = newDuration * 60;
              });
            },
            child: Text(
              "This session only",
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _durationMinutes = newDuration;
                _secondsRemaining = newDuration * 60;
              });
              await _adjustRemainingSchedule(
                  sessionIndex, dayIndex, shift);
            },
            child: Text(
              "Adjust today's schedule",
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Shifts the start/end times of every session after [fromIndex] on the
  /// same [dayIndex] by [shiftMinutes].  Updates the plan in-place so that
  /// completedTasks are preserved.
  Future<void> _adjustRemainingSchedule(
      int fromIndex, String dayIndex, int shiftMinutes) async {
    if (fromIndex < 0) return;

    final state = StudyStateManager.instance;
    final List<String> plan = List<String>.from(state.studyPlan);

    for (int i = fromIndex + 1; i < plan.length; i++) {
      final parsed = state.parsePlanItem(plan[i]);
      if (parsed['dayIndex'] != dayIndex) continue;
      final String startStr = parsed['startTime'] ?? '';
      final String endStr = parsed['endTime'] ?? '';
      if (startStr.isEmpty || endStr.isEmpty) continue;

      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      if (startParts.length < 2 || endParts.length < 2) continue;

      int startMins = (int.tryParse(startParts[0]) ?? 0) * 60 +
          (int.tryParse(startParts[1]) ?? 0);
      int endMins = (int.tryParse(endParts[0]) ?? 0) * 60 +
          (int.tryParse(endParts[1]) ?? 0);

      startMins = (startMins + shiftMinutes).clamp(0, 1439);
      endMins = (endMins + shiftMinutes).clamp(0, 1439);

      final newStart =
          "${(startMins ~/ 60).toString().padLeft(2, '0')}:${(startMins % 60).toString().padLeft(2, '0')}";
      final newEnd =
          "${(endMins ~/ 60).toString().padLeft(2, '0')}:${(endMins % 60).toString().padLeft(2, '0')}";

      plan[i] =
          "${parsed['subject']} (${parsed['difficulty']}) - ${parsed['hours']} | $newStart - $newEnd | ${parsed['dayIndex']}";
    }

    await state.updateStudyPlanInPlace(plan);
  }

  int get _activeTargetIndex {
    if (_focusCharge < 100.0) return 0;
    if (_wisdomCharge < 100.0) return 1;
    return 2;
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 24.0,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildAppleMusicControl({
    required IconData icon,
    required double scale,
    required VoidCallback onTap,
    required double size,
    required bool primary,
    required String label,
    required Function(double) onScaleChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => onScaleChanged(0.85),
          onTapUp: (_) {
            onScaleChanged(1.0);
            onTap();
          },
          onTapCancel: () => onScaleChanged(1.0),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutBack,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: primary
                    ? const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: primary ? null : Colors.white.withOpacity(0.85),
                border: Border.all(
                  color: primary ? const Color(0xFF0F766E) : Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary
                        ? const Color(0xFF0D9488).withOpacity(0.25)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: primary ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: primary ? Colors.white : const Color(0xFF1A1C1E),
                size: size * 0.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: primary ? FontWeight.w800 : FontWeight.bold,
            color: const Color(0xFF594042),
          ),
        ),
      ],
    );
  }

  Color _getAmbientGlowColor(double progress) {
    if (progress >= 1.0) {
      return Colors.amber.withOpacity(0.07);
    } else if (progress >= 0.5) {
      return const Color(0xFF006A63).withOpacity(0.06);
    } else {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int minutes = _secondsRemaining ~/ 60;
    final int seconds = _secondsRemaining % 60;
    final String timeStr = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    final double timerProgress = 1.0 - (_secondsRemaining / (_durationMinutes * 60));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic ambient lights
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              color: _getAmbientGlowColor(timerProgress),
            ),
          ),

          // Scrollable chamber body (Compressed spacing)
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Study Room",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Stay focused. Absorb energy. Achieve more.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF8D7072),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.35)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.music_note_rounded, color: Color(0xFF1A1C1E), size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Compressed spacing

                // 2. [Polished] Compact Subject Card (AI Breathing Glow dot & hover shimmer decoration)
                Builder(
                  builder: (context) {
                    final details = _resolveActiveSessionDetails();
                    final DateTime nowTime = DateTime.now();
                    final DateTime estEndTime = nowTime.add(Duration(seconds: _secondsRemaining));
                    final String estEndTimeStr = _formatTime(estEndTime);
                    
                    return _buildGlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF006A63).withOpacity(0.15), blurRadius: 8, spreadRadius: 1)
                              ],
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF006A63), size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "🎯 ${details['exam']}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                color: const Color(0xFF006A63),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          AnimatedBuilder(
                                            animation: _orbPulseController,
                                            builder: (context, _) {
                                              return Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFF10B981).withOpacity(0.35 + (0.65 * _orbPulseController.value)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF10B981).withOpacity(0.5),
                                                      blurRadius: 4 * _orbPulseController.value,
                                                      spreadRadius: 1,
                                                    )
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        details['subject'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1C1E20),
                                        ),
                                      ),
                                      Text(
                                        "${details['chapter']} • ${details['topic']}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${details['difficulty']} Diff",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9.5,
                                        color: const Color(0xFFEA580C),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: !_isActive
                                          ? _showDurationOverrideDialog
                                          : null,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "$_durationMinutes min goal",
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  const Color(0xFF1A1C1E),
                                            ),
                                          ),
                                          if (!_isActive) ...([
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.edit_rounded,
                                              size: 9,
                                              color: Color(0xFF006A63),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      "Est. End: $estEndTimeStr",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8.5,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: 12), // Compressed spacing

                // 3. Central Glass Timer Orb Stack
                Container(
                  height: 420,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none, // Allow children to render outside bounds without clipping
                    children: [
                      // Premium Core Glow Backdrop
                      Positioned(
                        top: 5,
                        child: AnimatedBuilder(
                          animation: _ambientController,
                          builder: (context, _) {
                            final double wave = math.sin(_ambientController.value * 2.0 * math.pi);
                            return Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF006A63).withOpacity(0.25 + (0.08 * wave)),
                                    const Color(0xFFFF5C77).withOpacity(0.12 + (0.04 * wave)),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.2, 0.6, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // [NEW SPECIFICATION] Large Floating Liquid Glass Energy Core (Hero centerpiece - 220px)
                      Positioned(
                        top: 15, // Shifted higher as requested
                        child: AnimatedBuilder(
                          animation: _orbPulseController,
                          builder: (context, child) {
                            // Core breathes slowly
                            final double coreBreathScale = 1.0 + (0.025 * _orbPulseController.value);
                            return Transform.scale(
                              scale: coreBreathScale,
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                                  child: Container(
                                    width: 220,
                                    height: 220,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.38),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // 1. Shifting internal nebula energy clouds
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _ambientController,
                                            builder: (context, _) {
                                              return CustomPaint(
                                                painter: ChamberCoreNebulaPainter(time: _ambientController.value),
                                              );
                                            },
                                          ),
                                        ),
                                        // 2. Circular ambient radial glow backing
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _ambientController,
                                            builder: (context, _) {
                                              return Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [
                                                      const Color(0xFF00D1C4).withOpacity(0.18 + (0.05 * math.sin(_ambientController.value * 2.0 * math.pi))),
                                                      Colors.transparent
                                                    ],
                                                    radius: 0.7,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // 3. Curved specular 3D glass highlight reflection arc
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: SpecularHighlightPainter(),
                                          ),
                                        ),
                                        // 4. Moving linear specular light sweeps
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _ambientController,
                                            builder: (context, _) {
                                              final double reflectionShift = 10.0 * math.sin(_ambientController.value * 2.0 * math.pi);
                                              return Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white.withOpacity(0.15),
                                                      Colors.transparent,
                                                      Colors.white.withOpacity(0.05),
                                                    ],
                                                    begin: Alignment(-1.0 + (reflectionShift / 30.0), -1.0),
                                                    end: Alignment(1.0 + (reflectionShift / 30.0), 1.0),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // 5. Custom progress ring with leading glowing dot (204px diameter)
                                        SizedBox(
                                          width: 204,
                                          height: 204,
                                          child: AnimatedBuilder(
                                            animation: _ambientController,
                                            builder: (context, _) {
                                              // Rotates slowly
                                              return Transform.rotate(
                                                angle: _ambientController.value * 2.0 * math.pi * 0.05,
                                                child: CustomPaint(
                                                  painter: TimerProgressRingPainter(progress: timerProgress),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        // 6. Countdown metrics & Dynamic Badge
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Remaining",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              timeStr,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 42,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF1A1C1E),
                                                letterSpacing: -1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              "of ${_durationMinutes.toString().padLeft(2, '0')}:00",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Dynamic Energy status pill badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE6F4F1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFF006A63).withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.bolt_rounded,
                                                    color: Color(0xFF006A63),
                                                    size: 10,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    !_isActive
                                                        ? "Ready"
                                                        : (_isPaused ? "Energy Paused" : "Energy Flowing..."),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF006A63),
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Floating Orbs inside SINGLE Glass Container Card (Compressed positioning)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_orbPulseController, _streamController, _ambientController]),
                          builder: (context, _) {
                            return _buildGlassCard(
                              borderRadius: 28.0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildEnergyOrbColumn(
                                      id: "focus",
                                      name: "Focus",
                                      charge: _focusCharge,
                                      color: Colors.blue,
                                      subtitle: "Focus Session Consistency\nTotal Focus: ${_totalHours.toStringAsFixed(1)} hrs\nAvg Session: $_avgSessionMinutes min",
                                      duration: "${_totalHours.toStringAsFixed(1)} hrs",
                                      phase: 0.0,
                                      isTarget: _activeTargetIndex == 0,
                                      streamProgress: _streamController.value,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildEnergyOrbColumn(
                                      id: "wisdom",
                                      name: "Wisdom",
                                      charge: _wisdomCharge,
                                      color: Colors.purple,
                                      subtitle: "Deep Learning & Understanding\nCompleted Chapters: $_completedTopics",
                                      duration: "$_completedTopics chapters",
                                      phase: 2.0,
                                      isTarget: _activeTargetIndex == 1,
                                      streamProgress: _streamController.value,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildEnergyOrbColumn(
                                      id: "mastery",
                                      name: "Mastery",
                                      charge: _masteryCharge,
                                      color: Colors.amber,
                                      subtitle: "Streaks & Overall Progress\nStudy Streak: $_streakDays days",
                                      duration: "$_streakDays day streak",
                                      phase: 4.0,
                                      isTarget: _activeTargetIndex == 2,
                                      streamProgress: _streamController.value,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // [NEW SPECIFICATION] Vector streams & continuous flow particles painter (drawn last, on top of widgets)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_ambientController, _streamController, _orbPulseController]),
                            builder: (context, child) {
                              return CustomPaint(
                                painter: StudyRoomStreamsPainter(
                                  ambientProgress: _ambientController.value,
                                  streamProgress: _streamController.value,
                                  pulseProgress: _orbPulseController.value,
                                  particles: _ambientParticles,
                                  isTimerActive: _isActive && !_isPaused,
                                  activeTargetIndex: _activeTargetIndex,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12), // Compressed spacing

                // 4. [Polished] Premium Glass Session Progress Card
                _buildGlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Builder(
                    builder: (context) {
                      final double currentProgress = 1.0 - (_secondsRemaining / (_durationMinutes * 60));
                      final int minsStudied = ((_durationMinutes * 60 - _secondsRemaining) / 60).floor();
                      
                      String focusScore = "Excellent ✨";
                      if (currentProgress < 0.3) {
                        focusScore = "Initiating 💫";
                      } else if (currentProgress < 0.7) {
                        focusScore = "Good ⚡";
                      }
                      
                      final int energyGenerated = (minsStudied * 12).round();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Current Session",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1C1E),
                                ),
                              ),
                              Text(
                                "$minsStudied / $_durationMinutes min",
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
                            children: List.generate(12, (index) {
                              final double pct = (index + 1) / 12;
                               final bool filled = pct <= currentProgress;
                              return Expanded(
                                child: Container(
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: filled ? const Color(0xFF006A63) : Colors.white24,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Focus Score: $focusScore",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: const Color(0xFF006A63),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Energy Generated: ⚡ $energyGenerated",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  color: const Color(0xFF1A1C1E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  ),
                ),
                const SizedBox(height: 16), // Compressed spacing

                // 5. Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAppleMusicControl(
                      icon: Icons.stop_rounded,
                      scale: _endScale,
                      onScaleChanged: (s) => setState(() => _endScale = s),
                      onTap: _endSession,
                      size: 54,
                      primary: false,
                      label: "End Session",
                    ),
                    _buildAppleMusicControl(
                      icon: !_isActive
                          ? Icons.play_arrow_rounded
                          : (_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                      scale: _pauseScale,
                      onScaleChanged: (s) => setState(() => _pauseScale = s),
                      onTap: _togglePause,
                      size: 68,
                      primary: true,
                      label: !_isActive ? "Start Session" : (_isPaused ? "Resume" : "Pause"),
                    ),
                    _buildAppleMusicControl(
                      icon: Icons.skip_next_rounded,
                      scale: _skipScale,
                      onScaleChanged: (s) => setState(() => _skipScale = s),
                      onTap: () {},
                      size: 54,
                      primary: false,
                      label: "Skip Break",
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. 2x2 Analytics Layout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Today's Energy",
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0D9488)),
TweenAnimationBuilder<double>(
                                      key: ValueKey(_todayEnergyValue),
                                      tween: Tween<double>(begin: (_todayEnergyValue - 300).toDouble(), end: _todayEnergyValue.toDouble()),
                                      duration: const Duration(seconds: 2),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, _) {
                                        final formattedVal = val.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
                                        return Text(
                                          " $formattedVal",
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1C1E)),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  "+$_todayEnergyChange",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "vs yesterday",
                                  style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 20,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: SparklinePainter(color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.trending_up_rounded, size: 10, color: Colors.blue),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Weekly Energy",
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _weeklyEnergyValue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1C1E)),
                                ),
                                Text(
                                  "of ${_weeklyEnergyGoal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 34,
                                        height: 34,
                                        child: CircularProgressIndicator(
                                          value: _weeklyEnergyValue / _weeklyEnergyGoal,
                                          strokeWidth: 3.0,
                                          backgroundColor: Colors.white30,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A63)),
                                        ),
                                      ),
                                      Text(
                                        "${((_weeklyEnergyValue / _weeklyEnergyGoal) * 100).toStringAsFixed(0)}%",
                                        style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, size: 10, color: Colors.orange),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Study Streak",
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "🔥 $_streakDays",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1C1E)),
                                ),
                                Text(
                                  "Days",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 24,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(6, (idx) {
                                      final heights = [10.0, 16.0, 12.0, 20.0, 14.0, 24.0];
                                      final active = idx == 5;
                                      return Container(
                                        width: 3,
                                        height: heights[idx],
                                        decoration: BoxDecoration(
                                          color: active ? const Color(0xFF10B981) : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Best: ${_streakDays > 28 ? _streakDays : 28} days",
                                  style: GoogleFonts.plusJakartaSans(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildGlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.done_all_rounded, size: 10, color: Colors.purple),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Sessions Today",
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 8.5, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "$_sessionsCompleted / $_sessionsGoal",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1C1E)),
                                ),
                                Text(
                                  "Sessions",
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    _sessionsGoal > 0 ? _sessionsGoal : 1,
                                    (idx) {
                                      final filled = idx < _sessionsCompleted;
                                      return Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: filled ? const Color(0xFF006A63) : Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                      );
                                    },
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
              ],
            ),
          ),

          // Premium Milestone Celebration Dialog Overlay
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrationController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: CelebrationParticlesPainter(
                        progress: _celebrationController.value,
                        particles: _celebrationParticles,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_showCelebration)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.05).animate(
                      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
                    ),
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE6F4F1),
                            ),
                            child: const Icon(Icons.stars_rounded, color: Color(0xFF006A63), size: 36),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _celebrationText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _celebrationSubtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF006A63),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _showCelebration = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006A63),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                "OK",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnergyOrbColumn({
    required String id,
    required String name,
    required double charge,
    required Color color,
    required String subtitle,
    required String duration,
    required double phase,
    required bool isTarget,
    required double streamProgress,
  }) {
    final bool isExpanded = _expandedOrbs.contains(id);

    // Dynamic rotation angle (moves back and forth slowly)
    final double rotationAngle = 0.15 * math.sin((_ambientController.value * 2.0 * math.pi) + phase);

    // Bouncy Float movement: custom wobbly spring equation
    final double angle = (_orbPulseController.value * 2.0 * math.pi) + phase;
    double floatOffset = 5.0 * (math.sin(angle) + 0.30 * math.sin(3.0 * angle));

    // Bouncy energy absorption pulse: reacts on particle arrival (+5% scaling reaction)
    double arrivalScale = 1.0;
    if (isTarget && streamProgress > 0.82) {
      final double norm = (streamProgress - 0.82) / 0.18; // 0.0 to 1.0
      arrivalScale = 1.0 + 0.05 * math.sin(norm * math.pi); // 5% spring scale burst
      floatOffset -= 3.0 * math.sin(norm * math.pi); // bounce secondary reaction
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedOrbs.remove(id);
          } else {
            _expandedOrbs.add(id);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isExpanded ? color.withOpacity(0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Floating, rotating energy sphere with bouncy scaling reaction
            Transform.scale(
              scale: arrivalScale,
              child: Transform.translate(
                offset: Offset(0, floatOffset),
                child: Transform.rotate(
                  angle: rotationAngle,
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: CustomPaint(
                      painter: CrystallineOrbPainter(
                        color: color,
                        charge: charge,
                        pulse: _orbPulseController.value,
                        ambientTime: _ambientController.value,
                        id: id,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),

            Text(
              "${charge.toStringAsFixed(0)}%",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getEvolutionStageName(charge),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              duration,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (isExpanded) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 7.5,
                  color: Colors.grey.shade600,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Visual Evolution Name string
  String _getEvolutionStageName(double charge) {
    if (charge <= 10.0) return "Dormant";
    if (charge <= 30.0) return "Awakening";
    if (charge <= 50.0) return "Crystal";
    if (charge <= 75.0) return "Radiant Crystal";
    if (charge <= 90.0) return "Ascended Crystal";
    return "Legendary Crystal";
  }
}

class CrystallineOrbPainter extends CustomPainter {
  final Color color;
  final double charge;
  final double pulse;
  final double ambientTime;
  final String id;

  CrystallineOrbPainter({
    required this.color,
    required this.charge,
    required this.pulse,
    required this.ambientTime,
    required this.id,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double midY = size.height / 2;
    final Offset center = Offset(midX, midY);

    // Evolving progress factors: increases glows/brightness/reflections as charge grows
    final double progressFactor = charge / 100.0;
    final double glowIntensity = 0.28 + (0.42 * progressFactor);
    final double glowBlurRadius = (14.0 + (22.0 * progressFactor)) * (1.0 + (0.06 * pulse));

    final paintBloom = Paint()
      ..color = color.withOpacity(glowIntensity * 0.45)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurRadius * 2.2);
    canvas.drawCircle(center, 38, paintBloom);

    // Personality specific glow configurations
    if (id == "focus") {
      // Focus: cool blue breathing glow, calm pulses, tiny inner sparks
      final paintGlow = Paint()
        ..color = color.withOpacity(glowIntensity * (1.0 + 0.15 * math.sin(pulse * 2.0 * math.pi)))
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurRadius);
      canvas.drawCircle(center, 32, paintGlow);
    } else if (id == "wisdom") {
      // Wisdom: slow rotation shimmers
      final paintGlow = Paint()
        ..color = color.withOpacity(glowIntensity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurRadius);
      canvas.drawCircle(center, 28, paintGlow);
    } else {
      // Mastery: golden glow, halo ring, floating fragments
      final paintGlow = Paint()
        ..color = color.withOpacity(glowIntensity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlurRadius);
      canvas.drawCircle(center, 30, paintGlow);

      // Faint outer halo
      final paintHalo = Paint()
        ..color = color.withOpacity(0.18 + (0.12 * progressFactor))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, 36, paintHalo);

      // Floating light fragments surrounding
      final paintSparkle = Paint()..color = Colors.white.withOpacity(0.8 * progressFactor)..style = PaintingStyle.fill;
      for (int i = 0; i < 4; i++) {
        final double angle = (pulse * 2.0 * math.pi) + (i * math.pi / 2);
        final Offset sparkPos = Offset(center.dx + 40 * math.cos(angle), center.dy + 40 * math.sin(angle));
        canvas.drawRect(Rect.fromCenter(center: sparkPos, width: 2, height: 2), paintSparkle);
      }
    }

    // Glass sphere background
    final paintGlass = Paint()
      ..color = Colors.white.withOpacity(0.35 + (0.15 * progressFactor))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 26, paintGlass);

    final paintStroke = Paint()
      ..color = color.withOpacity(0.20 + (0.30 * progressFactor))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 26, paintStroke);

    // [NEW SPECIFICATION] Liquid Light filling from the bottom up!
    // We clip the canvas to draw the glowing liquid inside the faceted paths up to the progress height
    final double gemHeight = 32.0;
    final double liquidHeight = gemHeight * progressFactor;
    final double clipY = (center.dy + 16.0) - liquidHeight;

    // Save canvas state before clipping
    canvas.save();

    // Paint dry glass background facets
    _drawCrystalGeometry(canvas, center, color.withOpacity(0.25), Colors.white.withOpacity(0.25));

    // Clip to paint liquid light filled part on top
    canvas.clipRect(Rect.fromLTRB(center.dx - 20, clipY, center.dx + 20, center.dy + 20));

    // Paint intensely glowing liquid facets
    final Color liquidColor = color;
    final Color specularColor = Colors.white.withOpacity(0.9);
    _drawCrystalGeometry(canvas, center, liquidColor, specularColor);

    // Restore canvas state
    canvas.restore();
  }

  // Draw the diamond faceted paths
  void _drawCrystalGeometry(Canvas canvas, Offset center, Color baseColor, Color specularColor) {
    final paintDark = Paint()..color = baseColor.withOpacity(0.85)..style = PaintingStyle.fill;
    final paintMid = Paint()..color = baseColor.withOpacity(0.65)..style = PaintingStyle.fill;
    final paintLight = Paint()..color = specularColor..style = PaintingStyle.fill;

    // Top face
    final pathTop = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx + 8, center.dy - 5)
      ..lineTo(center.dx, center.dy + 2)
      ..lineTo(center.dx - 8, center.dy - 5)
      ..close();
    canvas.drawPath(pathTop, paintMid);

    // Left face
    final pathLeft = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx - 8, center.dy - 5)
      ..lineTo(center.dx - 10, center.dy + 3)
      ..lineTo(center.dx, center.dy + 16)
      ..lineTo(center.dx, center.dy + 2)
      ..close();
    canvas.drawPath(pathLeft, paintDark);

    // Right face
    final pathRight = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx + 8, center.dy - 5)
      ..lineTo(center.dx + 10, center.dy + 3)
      ..lineTo(center.dx, center.dy + 16)
      ..lineTo(center.dx, center.dy + 2)
      ..close();
    canvas.drawPath(pathRight, paintMid);

    // Specular Diamond Glint with moving reflections matching ambientTime
    final double shimmer = 5.0 * math.sin((ambientTime * 2.0 * math.pi) + (id == "wisdom" ? 1.0 : 0.0));
    final pathSpecular = Path()
      ..moveTo(center.dx - 3 + shimmer, center.dy - 12)
      ..lineTo(center.dx + 2 + shimmer, center.dy - 9)
      ..lineTo(center.dx - 2 + shimmer, center.dy - 4)
      ..close();
    canvas.drawPath(pathSpecular, paintLight);
  }

  @override
  bool shouldRepaint(covariant CrystallineOrbPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.charge != charge || oldDelegate.ambientTime != ambientTime;
  }
}

class StudyRoomStreamsPainter extends CustomPainter {
  final double ambientProgress;
  final double streamProgress;
  final double pulseProgress;
  final List<math.Point<double>> particles;
  final bool isTimerActive;
  final int activeTargetIndex;

  StudyRoomStreamsPainter({
    required this.ambientProgress,
    required this.streamProgress,
    required this.pulseProgress,
    required this.particles,
    required this.isTimerActive,
    required this.activeTargetIndex,
  });

  double _getFloatOffset(double pulseProgress, double phase) {
    final double angle = (pulseProgress * 2.0 * math.pi) + phase;
    return 5.0 * (math.sin(angle) + 0.30 * math.sin(3.0 * angle));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double startY = 125; // Center coordinate of the 220px core positioned at top: 15
    final double endY = 303; // Center Y of the 76px floating orbs inside the 420px stack

    final Offset start = Offset(midX, startY);
    
    // Dynamically track the floating center of the crystals
    final Offset focusTarget = Offset(size.width * 0.18, endY + _getFloatOffset(pulseProgress, 0.0));
    final Offset wisdomTarget = Offset(midX, endY + _getFloatOffset(pulseProgress, 2.0));
    final Offset masteryTarget = Offset(size.width * 0.82, endY + _getFloatOffset(pulseProgress, 4.0));

    // Floating background particles
    final paintAmbient = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final double angle = ambientProgress * 2.0 * math.pi + (i * 8);
      final double dx = midX + (p.x * 240 - 120) + math.cos(angle) * 10;
      final double dy = startY + 80 + (p.y * 180 - 90) + math.sin(angle) * 10;

      paintAmbient.color = Colors.white.withOpacity(0.22 + (0.18 * math.sin(angle)));
      canvas.drawCircle(Offset(dx, dy), 1.4 + (1.4 * p.x), paintAmbient);
    }

    // Draw flowing streams (curved paths linking core to orbs)
    _drawFlowingStream(canvas, start, focusTarget, Colors.blue, streamProgress, activeTargetIndex == 0);
    _drawFlowingStream(canvas, start, wisdomTarget, Colors.purple, streamProgress, activeTargetIndex == 1);
    _drawFlowingStream(canvas, start, masteryTarget, Colors.amber, streamProgress, activeTargetIndex == 2);
  }

  void _drawFlowingStream(Canvas canvas, Offset start, Offset end, Color color, double progress, bool isActiveTarget) {
    final path = Path();
    path.moveTo(start.dx, start.dy + 110); // start at core bottom edge (radius 110)

    final Offset controlPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 + 10);
    path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);

    // Stream line
    final paintTrack = Paint()
      ..color = color.withOpacity(isActiveTarget ? 0.35 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActiveTarget ? 2.5 : 1.2;
    canvas.drawPath(path, paintTrack);

    // Continuous flow particles travel down the track for all crystals when timer is active
    if (isTimerActive) {
      final pathMetrics = path.computeMetrics().toList();
      if (pathMetrics.isNotEmpty) {
        final metric = pathMetrics.first;
        final double length = metric.length;

        // Render multiple flowing particle nodes to form a continuous stream
        for (int i = 0; i < 4; i++) {
          final double particleProgress = (progress + (i * 0.25)) % 1.0;
          final Offset dotPos = metric.getTangentForOffset(length * particleProgress)?.position ?? start;

          final paintDot = Paint()
            ..color = color.withOpacity(0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(dotPos, isActiveTarget ? 3.0 : 2.0, paintDot);

          final paintGlow = Paint()
            ..color = color.withOpacity(0.35)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(dotPos, isActiveTarget ? 6.0 : 4.0, paintGlow);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant StudyRoomStreamsPainter oldDelegate) {
    return true;
  }
}

class SparklinePainter extends CustomPainter {
  final Color color;
  SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.9, size.width * 0.4, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.1, size.width * 0.75, size.height * 0.5)
      ..lineTo(size.width, size.height * 0.1);

    canvas.drawPath(path, paint);

    // Gradient fill under path
    final pathFill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paintFill = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.15), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathFill, paintFill);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => false;
}

class TimerProgressRingPainter extends CustomPainter {
  final double progress;
  TimerProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.0;
    final double startAngle = -math.pi / 2;
    final double sweepAngle = 2.0 * math.pi * progress;

    // Draw background track
    final paintBackground = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, paintBackground);

    if (progress <= 0) return;

    // Draw active track with a smooth gradient
    final paintActive = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF00D1C4), Color(0xFF006A63), Color(0xFF00D1C4)],
        stops: [0.0, 0.5, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paintActive,
    );

    // Draw glowing leading thumb/dot
    final double endAngle = startAngle + sweepAngle;
    final Offset dotCenter = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    final paintDotGlow = Paint()
      ..color = const Color(0xFF00D1C4).withOpacity(0.45)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(dotCenter, 6.5, paintDotGlow);

    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, 3.0, paintDot);
  }

  @override
  bool shouldRepaint(covariant TimerProgressRingPainter oldDelegate) => oldDelegate.progress != progress;
}

class ChamberCoreNebulaPainter extends CustomPainter {
  final double time;
  ChamberCoreNebulaPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Layer three overlapping moving radial nebula energy blobs
    for (int i = 0; i < 3; i++) {
      final double angle = (time * 2.0 * math.pi) + (i * math.pi * 0.67);
      final double offsetDist = 14.0 * math.sin((time * 2.0 * math.pi) + (i * 1.5));
      final Offset blobCenter = Offset(
        center.dx + offsetDist * math.cos(angle),
        center.dy + offsetDist * math.sin(angle),
      );
      final double radius = (size.width * 0.44) + (10.0 * math.sin((time * 4.0 * math.pi) + i));

      final Color blobColor = i == 0
          ? const Color(0xFF00D1C4).withOpacity(0.24)
          : (i == 1
              ? const Color(0xFF008B8B).withOpacity(0.18)
              : const Color(0xFFE0FFFF).withOpacity(0.14));

      paint.shader = RadialGradient(
        colors: [blobColor, Colors.transparent],
        radius: 0.85,
      ).createShader(Rect.fromCircle(center: blobCenter, radius: radius));

      canvas.drawCircle(blobCenter, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChamberCoreNebulaPainter oldDelegate) => oldDelegate.time != time;
}

class SpecularHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintHighlight = Paint()
      ..color = Colors.white.withOpacity(0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw upper-left glossy curved reflection highlight
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      -math.pi * 0.88,
      math.pi * 0.38,
      false,
      paintHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant SpecularHighlightPainter oldDelegate) => false;
}

class CelebrationParticlesPainter extends CustomPainter {
  final double progress;
  final List<_CelebrationParticle> particles;
  CelebrationParticlesPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final double distanceFactor = progress;
      final double dx = center.dx + p.vx * distanceFactor * 25;
      final double dy = center.dy + p.vy * distanceFactor * 25;
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(opacity);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);

      // bloom highlight
      final glowPaint = Paint()
        ..color = p.color.withOpacity(opacity * 0.45)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(dx, dy), p.size * 2.2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CelebrationParticle {
  double x, y;
  final double vx, vy;
  final Color color;
  final double size;
  _CelebrationParticle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.size});
}
