import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import '../widgets/study_timer_sheet.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;
  final ValueChanged<Subject> onSubjectChanged;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.onSubjectChanged,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final TextEditingController topicController = TextEditingController();
  String selectedDifficulty = "Medium";
  bool _isLoadingAnalysis = false;
  List<dynamic> _recommendedTopics = [];

  Widget _buildDifficultyBadge(String difficulty) {
    Color bgColor;
    Color textColor;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        bgColor = const Color(0xFFE8F5F1); // mint/teal
        textColor = const Color(0xFF006A63);
        break;
      case 'medium':
        bgColor = const Color(0xFFFEF3C7); // amber
        textColor = const Color(0xFF835500);
        break;
      case 'hard':
        bgColor = const Color(0xFFFEE2E2); // red
        textColor = const Color(0xFFBA1A1A);
        break;
      default:
        bgColor = const Color(0xFFEEEEF0);
        textColor = const Color(0xFF594042);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _addTopic(String name, String difficulty) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    // Check duplicate
    final exists = widget.subject.topics.any(
      (t) => t.name.toLowerCase() == cleanName.toLowerCase(),
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Topic already added!")),
      );
      return;
    }

    setState(() {
      widget.subject.topics = [
        ...widget.subject.topics,
        Topic(name: cleanName, difficulty: difficulty),
      ];
    });

    widget.onSubjectChanged(widget.subject);
    topicController.clear();
  }

  void _deleteTopic(int index) {
    setState(() {
      widget.subject.topics.removeAt(index);
    });
    widget.onSubjectChanged(widget.subject);
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
        final minutes = (durationInSeconds as int) ~/ 60;
        final seconds = durationInSeconds % 60;
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

  Future<void> _analyzeTopics() async {
    setState(() {
      _isLoadingAnalysis = true;
    });

    try {
      final result = await ApiService.analyzeTopics(widget.subject.name);
      
      setState(() {
        _recommendedTopics = result["topics"] ?? [];
        widget.subject.aiSuggestions = result["advice"] ?? "";
      });

      widget.onSubjectChanged(widget.subject);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Analysis completed successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to analyze topics: $e")),
      );
    } finally {
      setState(() {
        _isLoadingAnalysis = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC), // Cool soft off-white
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9FC),
        elevation: 0,
        title: Text(
          widget.subject.name,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Color(0xFFFF5C77)),
            onPressed: () => _startTimer(widget.subject.name, null),
            tooltip: "Start Subject Timer",
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildDifficultyBadge(widget.subject.difficulty),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Manage Manual Topics Card (24px corner radius)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Color(0xFFE2E2E5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Add Sub-Topic",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: topicController,
                          style: GoogleFonts.plusJakartaSans(),
                          decoration: InputDecoration(
                            labelText: "Topic Name",
                            labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF8D7072)),
                            prefixIcon: const Icon(Icons.bookmark_border_rounded, color: Color(0xFFFF5C77)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16), // 16px radius
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFFF5C77), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Topic Difficulty",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF594042),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ["Easy", "Medium", "Hard"].map((diff) {
                            final bool isSelected = selectedDifficulty == diff;
                            Color color;
                            switch (diff) {
                              case "Easy":
                                color = const Color(0xFF006A63);
                                break;
                              case "Medium":
                                color = const Color(0xFF835500);
                                break;
                              default:
                                color = const Color(0xFFBA1A1A);
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(diff, style: GoogleFonts.plusJakartaSans()),
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
                                      selectedDifficulty = diff;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _addTopic(topicController.text, selectedDifficulty),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C77), // Rose primary action
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32), // full pill shape
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(
                            "Add Topic",
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // AI Tools Section (with custom container and card layouts)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C77).withOpacity(0.04), // soft tinted rose background
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFF5C77).withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5C77),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI Topic Analyzer",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF5C77),
                                  ),
                                ),
                                Text(
                                  "Get tailored preparation advice and recommended sub-topics.",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF594042),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _analyzeTopics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C77),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32), // full pill shape
                          ),
                        ),
                        icon: const Icon(Icons.psychology_rounded),
                        label: Text(
                          "Analyze Topics using AI",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Suggested Sub-Topics section
                      if (_recommendedTopics.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          "Recommended Topics to Add:",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF5C77),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recommendedTopics.map((item) {
                            final String tName = item["name"] ?? "";
                            final String tDiff = item["difficulty"] ?? "Medium";
                            final bool alreadyAdded = widget.subject.topics.any(
                              (t) => t.name.toLowerCase() == tName.toLowerCase(),
                            );

                            return ActionChip(
                              avatar: Icon(
                                alreadyAdded ? Icons.check_circle : Icons.add_circle_outline,
                                size: 14,
                                color: alreadyAdded ? const Color(0xFF006A63) : const Color(0xFFFF5C77),
                              ),
                              label: Text("$tName ($tDiff)", style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                              onPressed: alreadyAdded ? null : () => _addTopic(tName, tDiff),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: alreadyAdded ? const Color(0xFFE8F5F1) : const Color(0xFFFF5C77).withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Preparation suggestions based on difficulty
                      if (widget.subject.aiSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          "AI Suggestions for Prep Strategy:",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF5C77),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFF5C77).withOpacity(0.15)),
                          ),
                          child: Text(
                            widget.subject.aiSuggestions,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF1A1C1E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Topics List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Subject Syllabus",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1C1E),
                      ),
                    ),
                    Text(
                      "${widget.subject.topics.length} Topics",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF8D7072),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Topics List Cards (24px corner radius)
                if (widget.subject.topics.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E2E5)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.bookmark_outline_rounded, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          "No topics added yet",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...widget.subject.topics.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final Topic topic = entry.value;

                    final isHard = topic.difficulty.toLowerCase() == 'hard';
                    final isEasy = topic.difficulty.toLowerCase() == 'easy';
                    final tileBgColor = isHard
                        ? const Color(0xFFFEE2E2)
                        : isEasy
                            ? const Color(0xFFE8F5F1) // mint/teal
                            : const Color(0xFFFEF3C7);
                    final tileTextColor = isHard
                        ? const Color(0xFFBA1A1A)
                        : isEasy
                            ? const Color(0xFF006A63)
                            : const Color(0xFF835500);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: tileBgColor,
                        borderRadius: BorderRadius.circular(24), // 24px (rounded-xl)
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.bookmark_rounded, color: tileTextColor, size: 16),
                          ),
                          title: Text(
                            topic.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: tileTextColor,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.play_circle_outline_rounded, color: tileTextColor, size: 22),
                                onPressed: () => _startTimer(widget.subject.name, topic.name),
                                tooltip: "Start Topic Timer",
                              ),
                              _buildDifficultyBadge(topic.difficulty),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A), size: 18),
                                onPressed: () => _deleteTopic(index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (_isLoadingAnalysis)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5C77)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "AI is analyzing syllabus...",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Generating study strategies and sub-topics based on difficulty...",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF8D7072),
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
}