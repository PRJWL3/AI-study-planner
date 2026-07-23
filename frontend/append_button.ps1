
$f = 'lib\screens\home_screen.dart'
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)

# Check if already added
if ($c.Contains('_PlannerGenerateButton')) {
    Write-Host "SKIP - _PlannerGenerateButton already present"
    exit 0
}

$appendage = @'

// ---------------------------------------------------------------------------
// Premium Generate button with press-scale animation
// ---------------------------------------------------------------------------
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

class _PlannerGenerateButtonState extends State<_PlannerGenerateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { if (widget.canGenerate) _ctrl.forward(); },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.canGenerate ? 1.0 : 0.45,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: widget.canGenerate
                  ? const LinearGradient(
                      colors: [Color(0xFFFF5C77), Color(0xFF006A63)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade300],
                    ),
              boxShadow: widget.canGenerate
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF5C77).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: widget.canGenerate && !widget.isLoading
                    ? widget.onTap
                    : null,
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              "Generate My AI Study Plan",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'@

$c = $c.TrimEnd() + $appendage
[System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
Write-Host "_PlannerGenerateButton appended"
