import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import '../services/study_state_manager.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedCourse = "B.Tech";
  String _selectedMascot = "assets/images/mascot_boy.png"; // Default to Classic Alex
  bool _isLoading = false;

  final List<String> _courseOptions = [
    "B.Tech",
    "MBBS",
    "B.Sc",
    "B.A",
    "M.Tech",
    "MBA",
    "M.Sc",
    "Ph.D",
  ];

  final List<Map<String, String>> _mascots = [
    {
      "name": "Classic Alex",
      "path": "assets/images/mascot_boy.png",
    },
    {
      "name": "Coder Lumina",
      "path": "assets/images/mascot_coder.png",
    },
    {
      "name": "Artist Kai",
      "path": "assets/images/mascot_skater.png",
    },
    {
      "name": "GUDDU",
      "path": "assets/images/mascot_traditional.png",
    },
  ];

  Future<void> _saveProfileAndStart() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await StudyStateManager.instance.saveProfile(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        course: _selectedCourse,
        mascot: _selectedMascot,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  void _showCourseSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Course / Degree",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _courseOptions.length,
                  itemBuilder: (context, index) {
                    final course = _courseOptions[index];
                    final bool isSelected = _selectedCourse == course;
                    return ListTile(
                      title: Text(
                        course,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF006A63) : const Color(0xFF1A1C1E),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF006A63))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCourse = course;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Soft mesh gradient background (Mint Green left, Lavender Purple right)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFD2F5EB),
                  Color(0xFFEAE6FA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // 2. Scrollable Body
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // App branding header
                  Text(
                    "Lumina Study",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF004D40),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Welcome headlining text
                  Text(
                    "Set Up Your Profile",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Let's personalize your Lumina study companion!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF594042),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3. Form fields card container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name Input
                          Text(
                            "Full Name",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1C1E),
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter your full name",
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF8D7072),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF4F4F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your name";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Age Input (Numeric)
                          Text(
                            "Age",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1C1E),
                            ),
                            decoration: InputDecoration(
                              hintText: "Enter your age",
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.cake_outlined,
                                color: Color(0xFF8D7072),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF4F4F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your age";
                              }
                              final int? parsedAge = int.tryParse(value.trim());
                              if (parsedAge == null || parsedAge <= 0) {
                                return "Please enter a valid age";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Course Dropdown Selector (InkWell displaying BottomSheet)
                          Text(
                            "Course / Degree",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showCourseSelector,
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F4F8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.school_outlined,
                                        color: Color(0xFF8D7072),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedCourse,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1A1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF1A1C1E),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Companion Mascot Selector Grid
                          Text(
                            "Choose Your Companion Mascot",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1C1E),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _mascots.length,
                            itemBuilder: (context, index) {
                              final mascot = _mascots[index];
                              return _buildMascotSelectCard(
                                assetPath: mascot["path"]!,
                                label: mascot["name"]!,
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Get Started CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfileAndStart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006C4D),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      "Get Started",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotSelectCard({
    required String assetPath,
    required String label,
  }) {
    final bool isSelected = _selectedMascot == assetPath;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMascot = assetPath;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF006A63) : const Color(0xFFE2E2E5),
            width: isSelected ? 3.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF006A63).withOpacity(0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFFF4F4F8),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006A63) : const Color(0xFF594042),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
