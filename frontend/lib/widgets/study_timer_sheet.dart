import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudyTimerSheet extends StatefulWidget {
  final String subjectName;
  final String? topicName;

  const StudyTimerSheet({
    super.key,
    required this.subjectName,
    this.topicName,
  });

  @override
  State<StudyTimerSheet> createState() => _StudyTimerSheetState();
}

class _StudyTimerSheetState extends State<StudyTimerSheet> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  bool _isPomodoro = false; // true = countdown from 25 min, false = stopwatch
  final int _pomodoroTotalSeconds = 25 * 60;

  @override
  void initState() {
    super.initState();
    _seconds = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_isPomodoro) {
            if (_seconds < _pomodoroTotalSeconds) {
              _seconds++;
            } else {
              _timer?.cancel();
              _isRunning = false;
              _showCompletionDialog();
            }
          } else {
            _seconds++;
          }
        });
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _seconds = 0;
    });
  }

  void _toggleMode(bool isPomodoro) {
    _timer?.cancel();
    setState(() {
      _isPomodoro = isPomodoro;
      _isRunning = false;
      _seconds = 0;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "⏰ Pomodoro Completed!",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Great job focusing! Take a 5-minute break and recharge.",
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFFFF5C77)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int displaySeconds = _isPomodoro ? (_pomodoroTotalSeconds - totalSeconds) : totalSeconds;
    if (displaySeconds < 0) displaySeconds = 0;

    int minutes = displaySeconds ~/ 60;
    int seconds = displaySeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  double _getProgress() {
    if (!_isPomodoro) return 0.0;
    return _seconds / _pomodoroTotalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.topicName != null
        ? "${widget.subjectName} • ${widget.topicName}"
        : widget.subjectName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8E5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Text(
            "STUDY SESSION TIMER",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF8D7072),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 28),

          // Mode Selection Chips (Pill shape)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text("Stopwatch", style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                selected: !_isPomodoro,
                onSelected: (selected) => _toggleMode(false),
                selectedColor: const Color(0xFFFF5C77).withOpacity(0.15),
                labelStyle: TextStyle(
                  color: !_isPomodoro ? const Color(0xFFFF5C77) : const Color(0xFF594042),
                  fontWeight: FontWeight.bold,
                ),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: !_isPomodoro ? const Color(0xFFFF5C77) : const Color(0xFFE2E2E5),
                ),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text("Pomodoro (25m)", style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                selected: _isPomodoro,
                onSelected: (selected) => _toggleMode(true),
                selectedColor: const Color(0xFFFF5C77).withOpacity(0.15),
                labelStyle: TextStyle(
                  color: _isPomodoro ? const Color(0xFFFF5C77) : const Color(0xFF594042),
                  fontWeight: FontWeight.bold,
                ),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: _isPomodoro ? const Color(0xFFFF5C77) : const Color(0xFFE2E2E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Visual Timer Circle (Thick 12px Progress Bar style)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: _isPomodoro ? _getProgress() : null, // Spinner if stopwatch, progress if pomodoro
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFFEEEEF0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5C77)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_seconds),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1C1E),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRunning ? "ACTIVE" : "PAUSED",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isRunning ? const Color(0xFF006A63) : const Color(0xFF8D7072),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Controls (Tacile Pill Style)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset Button
              IconButton(
                onPressed: _resetTimer,
                iconSize: 28,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.replay_rounded, color: Color(0xFF594042)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEEEEF0),
                  shape: const CircleBorder(),
                ),
              ),
              const SizedBox(width: 24),

              // Play / Pause Button
              IconButton(
                onPressed: _toggleTimer,
                iconSize: 36,
                padding: const EdgeInsets.all(16),
                icon: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C77),
                  shape: const CircleBorder(),
                  shadowColor: const Color(0xFFFF5C77).withOpacity(0.3),
                  elevation: 6,
                ),
              ),
              const SizedBox(width: 24),

              // Finish Button
              IconButton(
                onPressed: () {
                  _timer?.cancel();
                  Navigator.pop(context, _seconds);
                },
                iconSize: 28,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.check_rounded, color: Color(0xFF006A63)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF8BF1E6).withOpacity(0.2),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}