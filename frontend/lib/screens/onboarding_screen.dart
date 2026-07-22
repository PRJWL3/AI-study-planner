import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import '../widgets/global_eggy.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0; // 0 = Course, 1 = Year, 2 = Syllabus Select
  String _selectedCourse = "B.Tech";
  final TextEditingController _customCourseController = TextEditingController();
  bool _isCustomCourse = false;
  String _selectedYear = "1st Year";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    EggyController.instance.isVisible = false;
  }

  final List<String> _coursePresets = ["B.Tech", "MBBS", "B.Sc", "MBA", "Law", "Other"];

  // Syllabus selection states
  List<dynamic> _fetchedSyllabus = [];
  String _fetchedStrategy = "";
  final Map<String, bool> _selectedSubjects = {};
  final Map<String, Map<String, bool>> _selectedTopics = {};

  List<String> _getYearsList() {
    final course = _isCustomCourse ? _customCourseController.text.trim() : _selectedCourse;
    if (course.toLowerCase() == "b.tech" || course.toLowerCase() == "btech") {
      return ["1st Year", "2nd Year", "3rd Year", "4th Year"];
    } else if (course.toLowerCase() == "mbbs") {
      return ["1st Year", "2nd Year", "3rd Year", "4th Year", "5th Year"];
    } else {
      return ["1st Year", "2nd Year", "3rd Year", "4th Year", "5th Year", "6th Year"];
    }
  }

  Future<void> _fetchSyllabusAndMove() async {
    final courseName = _isCustomCourse ? _customCourseController.text.trim() : _selectedCourse;

    if (courseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please specify your course!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getOnboardingStrategy(courseName, _selectedYear);
      
      setState(() {
        _fetchedStrategy = response["strategy"] ?? "";
        _fetchedSyllabus = response["default_syllabus"] ?? [];
        
        // Initialize checkboxes to true by default
        for (var subject in _fetchedSyllabus) {
          final String sName = subject["name"] ?? "";
          _selectedSubjects[sName] = true;
          _selectedTopics[sName] = {};

          final topicsList = subject["topics"] as List?;
          if (topicsList != null) {
            for (var topic in topicsList) {
              final String tName = topic["name"] ?? "";
              _selectedTopics[sName]![tName] = true;
            }
          }
        }
        _currentStep = 2; // Move to syllabus selector
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch syllabus options: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final courseName = _isCustomCourse ? _customCourseController.text.trim() : _selectedCourse;
      final prefs = await SharedPreferences.getInstance();

      // Build and serialize Subject objects
      final List<Subject> selectedSubjectsList = [];

      for (var sub in _fetchedSyllabus) {
        final String sName = sub["name"] ?? "";
        if (_selectedSubjects[sName] == true) {
          final List<Topic> topicsList = [];
          final tList = sub["topics"] as List?;
          
          if (tList != null) {
            for (var top in tList) {
              final String tName = top["name"] ?? "";
              if (_selectedTopics[sName]?[tName] == true) {
                topicsList.add(
                  Topic(
                    name: tName,
                    difficulty: top["difficulty"] ?? "Medium",
                  ),
                );
              }
            }
          }

          selectedSubjectsList.add(
            Subject(
              name: sName,
              difficulty: sub["difficulty"] ?? "Medium",
              topics: topicsList,
            ),
          );
        }
      }

      // Save everything to SharedPreferences
      await prefs.setBool("onboarded", true);
      await prefs.setString("user_course", courseName);
      await prefs.setString("user_year", _selectedYear);
      await prefs.setString("onboarding_strategy", _fetchedStrategy);
      
      await prefs.setString(
        "subjects",
        jsonEncode(selectedSubjectsList.map((e) => e.toJson()).toList()),
      );

      // Clean default study plan since syllabus has changed
      await prefs.remove("studyPlan");
      await prefs.remove("completedTasks");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save syllabus: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = _getYearsList();
    if (!years.contains(_selectedYear)) {
      _selectedYear = years.first;
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF5C77).withOpacity(0.04), // soft Rose primary
                  const Color(0xFF006A63).withOpacity(0.03), // soft Teal secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Logo Header
                    if (_currentStep < 2) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5C77).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFF5C77),
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Welcome to Lumina Study",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1C1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Let's customize your workspace to craft the best learning plan.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF594042),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],

                    // Wizard Steps Switcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _currentStep == 0
                          ? _buildCourseSelectionStep()
                          : _currentStep == 1
                              ? _buildYearSelectionStep(years)
                              : _buildSyllabusSelectionStep(),
                    ),
                    const SizedBox(height: 40),

                    // Navigation Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentStep--;
                              });
                            },
                            icon: const Icon(Icons.arrow_back, color: Color(0xFFFF5C77)),
                            label: Text(
                              "Back",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF5C77),
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),

                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32), // stadium/pill button
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5C77), Color(0xFF006A63)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5C77).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            onPressed: () {
                              if (_currentStep == 0) {
                                final course = _isCustomCourse ? _customCourseController.text.trim() : _selectedCourse;
                                if (course.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please select or enter a course!")),
                                  );
                                  return;
                                }
                                setState(() {
                                  _currentStep = 1;
                                });
                              } else if (_currentStep == 1) {
                                _fetchSyllabusAndMove();
                              } else {
                                _submitOnboarding();
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentStep < 2 ? "Next" : "Import & Finish",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentStep < 2 ? Icons.arrow_forward : Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
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
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
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
                          "Customizing Experience...",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1C1E),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentStep == 1 
                              ? "AI is assembling syllabus recommendations..."
                              : "Saving your selection and setting up planner...",
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

  Widget _buildCourseSelectionStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "What course/exam are you studying for?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _coursePresets.map((course) {
            final bool isSelected = !_isCustomCourse && _selectedCourse == course;
            final bool isOtherSelected = _isCustomCourse && course == "Other";
            final bool active = isSelected || isOtherSelected;

            return ChoiceChip(
              label: Text(course),
              selected: active,
              selectedColor: const Color(0xFFFF5C77).withOpacity(0.15),
              labelStyle: TextStyle(
                color: active ? const Color(0xFFFF5C77) : const Color(0xFF594042),
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
              shape: const StadiumBorder(),
              side: BorderSide(
                color: active ? const Color(0xFFFF5C77) : const Color(0xFFE2E2E5),
              ),
              backgroundColor: Colors.white,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    if (course == "Other") {
                      _isCustomCourse = true;
                    } else {
                      _isCustomCourse = false;
                      _selectedCourse = course;
                    }
                  });
                }
              },
            );
          }).toList(),
        ),
        if (_isCustomCourse) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _customCourseController,
            style: GoogleFonts.plusJakartaSans(),
            decoration: InputDecoration(
              labelText: "Enter Course Name",
              hintText: "e.g. Law, Board Exam",
              prefixIcon: const Icon(Icons.school_rounded, color: Color(0xFFFF5C77)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFF5C77), width: 2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildYearSelectionStep(List<String> years) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Which year of study are you in?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1C1E),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: years.map((year) {
            final bool isSelected = _selectedYear == year;

            return ChoiceChip(
              label: Text(year),
              selected: isSelected,
              selectedColor: const Color(0xFFFF5C77).withOpacity(0.15),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFFF5C77) : const Color(0xFF594042),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: const StadiumBorder(),
              side: BorderSide(
                color: isSelected ? const Color(0xFFFF5C77) : const Color(0xFFE2E2E5),
              ),
              backgroundColor: Colors.white,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedYear = year;
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSyllabusSelectionStep() {
    final courseName = _isCustomCourse ? _customCourseController.text.trim() : _selectedCourse;

    return Column(
      key: const ValueKey(2),
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
              child: const Icon(Icons.library_books_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recommended Syllabus",
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
                  ),
                  Text(
                    "Select default subjects and topics for $courseName ($_selectedYear).",
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF8D7072)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_fetchedSyllabus.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24), // 24px (rounded-xl)
              border: Border.all(color: const Color(0xFFE2E2E5)),
            ),
            child: Center(
              child: Text(
                "No recommended syllabus found. You can add subjects manually later!",
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF594042)),
              ),
            ),
          )
        else
          ..._fetchedSyllabus.map((sub) {
            final String sName = sub["name"] ?? "";
            final String sDiff = sub["difficulty"] ?? "Medium";
            final bool isSubjectChecked = _selectedSubjects[sName] ?? false;
            final topicsList = sub["topics"] as List?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSubjectChecked ? const Color(0xFFFF5C77).withOpacity(0.3) : const Color(0xFFE2E2E5),
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                title: Row(
                  children: [
                    Checkbox(
                      value: isSubjectChecked,
                      activeColor: const Color(0xFFFF5C77),
                      onChanged: (val) {
                        setState(() {
                          _selectedSubjects[sName] = val ?? false;
                          // Check/uncheck all nested topics
                          if (topicsList != null) {
                            for (var topic in topicsList) {
                              final String tName = topic["name"] ?? "";
                              _selectedTopics[sName]![tName] = val ?? false;
                            }
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        sName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSubjectChecked ? const Color(0xFF1A1C1E) : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDifficultyBadge(sDiff),
                  ],
                ),
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E2E5)),
                  if (topicsList == null || topicsList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text("No recommended topics for this subject.", style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                    )
                  else
                    ...topicsList.map((topic) {
                      final String tName = topic["name"] ?? "";
                      final String tDiff = topic["difficulty"] ?? "Medium";
                      final bool isTopicChecked = _selectedTopics[sName]?[tName] ?? false;

                      return Container(
                        padding: const EdgeInsets.only(left: 24.0, right: 16.0),
                        child: Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            value: isTopicChecked,
                            enabled: isSubjectChecked,
                            activeColor: const Color(0xFFFF5C77),
                            onChanged: (val) {
                              setState(() {
                                _selectedTopics[sName]![tName] = val ?? false;
                                // If at least one topic is checked, keep subject checked
                                if (val == true) {
                                  _selectedSubjects[sName] = true;
                                }
                              });
                            },
                            title: Text(
                              tName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: isTopicChecked ? const Color(0xFF1A1C1E) : Colors.grey.shade400,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                _buildDifficultyBadge(tDiff),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
      ],
    );
  }
}