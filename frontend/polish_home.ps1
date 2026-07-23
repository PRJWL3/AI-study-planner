
$f = 'lib\screens\home_screen.dart'
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
$nl = "`r`n"

# ── 1. Rename AppBar tabTitle ─────────────────────────────────────────────────
$c = $c.Replace('tabTitle = "Planner Setup";', 'tabTitle = "Study Plan";')
Write-Host "1. tabTitle renamed"

# ── 2. Add _plannerHoursPerDay stepper state var ─────────────────────────────
$old2 = '  String _plannerPreferredTime = "Morning";'
$new2 = '  String _plannerPreferredTime = "Morning";' + $nl + '  int _plannerHoursPerDay = 4; // stepper - synced with hoursController'
if ($c.Contains($old2)) { $c = $c.Replace($old2, $new2); Write-Host "2. _plannerHoursPerDay added" }
else { Write-Host "2. SKIP - already present or not found" }

# ── 3. Replace entire _buildSettingsTab body ──────────────────────────────────
# Find start and end markers
$startMarker = 'Widget _buildSettingsTab() {'
$endMarker = '  Future<void> generateStudyPlan() async {'

$startIdx = $c.IndexOf($startMarker)
$endIdx   = $c.IndexOf($endMarker)

if ($startIdx -lt 0 -or $endIdx -lt 0) {
    Write-Host "ERROR: Could not find _buildSettingsTab boundaries"
    exit 1
}

$before = $c.Substring(0, $startIdx)
$after  = $c.Substring($endIdx)

$newTab = @'
Widget _buildSettingsTab() {
    // -- computed summary values --------------------------------------------------
    final int daysLeft     = getDaysLeft() > 0 ? getDaysLeft() : 0;
    final int hoursPerDay  = _plannerHoursPerDay;
    final int totalHours   = daysLeft * hoursPerDay;
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
                  setState(() {
                    _plannerHoursPerDay--;
                    hoursController.text = _plannerHoursPerDay.toString();
                  });
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
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
                  setState(() {
                    _plannerHoursPerDay++;
                    hoursController.text = _plannerHoursPerDay.toString();
                  });
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
              padding: const EdgeInsets.all(24),
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
                  // Premium robot illustration container
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
                    child: const Center(
                      child: Icon(
                        Icons.smart_toy_rounded,
                        size: 40,
                        color: Color(0xFFFF5C77),
                      ),
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

                  // Study Hours stepper
                  fieldRow(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF006A63),
                    iconBg: const Color(0xFFE8F5F1),
                    label: "STUDY HOURS PER DAY",
                    field: hoursStepper(),
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
                      onSelect: (v) => setState(() => _plannerStudyStyle = v),
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
                      onSelect: (v) => setState(() => _plannerBreakDuration = v),
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
                      onSelect: (v) => setState(() => _plannerDifficultyPref = v),
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
                      onSelect: (v) => setState(() => _plannerPreferredTime = v),
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
                        value: hoursPerDay > 0 ? "$hoursPerDay hrs" : "--",
                        label: "Hours / Day",
                        bg: const Color(0xFFE8F5F1).withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      summaryTile(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: const Color(0xFFEA580C),
                        iconBg: const Color(0xFFFFEDD5),
                        value: totalHours > 0 ? "$totalHours" : "--",
                        label: "Total Hrs",
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

'@

$c = $before + $newTab + $after
[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
Write-Host "3. _buildSettingsTab replaced"
