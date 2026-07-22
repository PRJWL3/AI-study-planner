import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentCourse;
  final String currentYear;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentCourse,
    required this.currentYear,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _courseController;
  late final TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _courseController = TextEditingController(text: widget.currentCourse);
    _yearController = TextEditingController(text: widget.currentYear);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _showSelectionSheet({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9F9FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag Indicator handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E2E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE2E2E5)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final String option = options[index];
                    final bool isSelected = option == currentValue;
                    return ListTile(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      title: Text(
                        option,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFFFF5C77) : const Color(0xFF1A1C1E),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5C77))
                          : null,
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

  Widget _buildMascot(String course) {
    final String cleanCourse = course.trim().toUpperCase();
    String assetPath = "assets/images/eggy_default.jpg";
    String speechBubbleText = "Hi! I am Eggy. Let's make study planning fun!";
    String badgeTitle = "Eggy Mascot";
    Color accentColor = const Color(0xFF006A63); // Secondary Teal

    if (cleanCourse == "B.TECH") {
      assetPath = "assets/images/eggy_coder.jpg";
      speechBubbleText = "Ready to code our study schedule? Let's compile some blocks!";
      badgeTitle = "Tech-Savvy Coder";
      accentColor = const Color(0xFF006A63);
    } else if (cleanCourse == "MBBS") {
      assetPath = "assets/images/eggy_doctor.jpg";
      speechBubbleText = "Time to dissect the medical syllabus! Keep that focus high, Doc!";
      badgeTitle = "Medical Doctor";
      accentColor = const Color(0xFFFF5C77); // Rose Primary accent
    }

    return Column(
      children: [
        // Eggy Speech Bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            speechBubbleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1C1E),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mascot Container with organic border radius and glowing accents
        Container(
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: cleanCourse == "B.TECH" 
                  ? Colors.blue.shade400 
                  : cleanCourse == "MBBS" 
                      ? const Color(0xFFFF5C77) 
                      : const Color(0xFF006A63).withOpacity(0.5), 
              width: 3,
            ),
            boxShadow: [
              if (cleanCourse == "B.TECH")
                BoxShadow(
                  color: Colors.blue.shade400.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              else if (cleanCourse == "MBBS")
                BoxShadow(
                  color: const Color(0xFFFF5C77).withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(70),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.egg_rounded,
                  size: 64,
                  color: cleanCourse == "B.TECH" 
                      ? Colors.blue.shade300 
                      : cleanCourse == "MBBS" 
                          ? const Color(0xFFFF5C77) 
                          : const Color(0xFF006A63),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Character Badge Text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initialChar = _nameController.text.isNotEmpty 
        ? _nameController.text[0].toUpperCase() 
        : (widget.currentCourse.isNotEmpty ? widget.currentCourse[0].toUpperCase() : "S");

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC), // Cool soft off-white
      appBar: AppBar(
        title: Text(
          "Edit Profile",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1A1C1E)),
        ),
        backgroundColor: const Color(0xFFF9F9FC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1C1E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background soft subtle educational decoration vectors
          Positioned(
            top: 40,
            left: 20,
            child: Icon(
              Icons.star_rounded,
              size: 24,
              color: const Color(0xFFFF5C77).withOpacity(0.06),
            ),
          ),
          Positioned(
            top: 150,
            right: 30,
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 32,
              color: const Color(0xFFFF5C77).withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: 250,
            left: 40,
            child: Icon(
              Icons.edit_rounded,
              size: 24,
              color: const Color(0xFF006A63).withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 40,
            child: Icon(
              Icons.school_rounded,
              size: 28,
              color: const Color(0xFFFF5C77).withOpacity(0.06),
            ),
          ),
          Positioned(
            top: 320,
            left: 15,
            child: Icon(
              Icons.menu_book_rounded,
              size: 22,
              color: const Color(0xFF006A63).withOpacity(0.06),
            ),
          ),

          // Scrollable Primary Form
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Profile Picture Picker Placeholder Option
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xFF006A63), // Teal
                          child: Text(
                            initialChar,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFFF5C77), // Rose primary edit badge
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // AI Mascot Container
                _buildMascot(_courseController.text),
                const SizedBox(height: 36),

                // Structured Form Inputs
                Text(
                  "Full Name",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  onChanged: (val) {
                    setState(() {});
                  },
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1C1E)),
                  decoration: InputDecoration(
                    hintText: "Enter your full name",
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), // 16px corner radius
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFF5C77), width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  "Course / Degree",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    _showSelectionSheet(
                      title: "Select Course / Degree",
                      options: const ["MBBS", "B.Tech", "B.Sc", "B.Com", "B.A.", "Other"],
                      currentValue: _courseController.text,
                      onSelected: (val) {
                        setState(() {
                          _courseController.text = val;
                        });
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _courseController,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1C1E)),
                      decoration: InputDecoration(
                        hintText: "Select course",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF594042)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFF5C77), width: 2.0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  "Year / Semester",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    _showSelectionSheet(
                      title: "Select Year / Semester",
                      options: const ["1st Year", "2nd Year", "3rd Year", "4th Year", "5th Year"],
                      currentValue: _yearController.text,
                      onSelected: (val) {
                        setState(() {
                          _yearController.text = val;
                        });
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _yearController,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1A1C1E)),
                      decoration: InputDecoration(
                        hintText: "Select year",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF594042)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFFF5C77), width: 2.0),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Large Solid action button in high-contrast Primary Rose or Secondary Teal
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final course = _courseController.text.trim();
                    final year = _yearController.text.trim();

                    Navigator.pop(context, {
                      'name': name,
                      'course': course,
                      'year': year,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C77), // Rose primary action
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32), // full pill shape (rounded-full)
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Save Changes",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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