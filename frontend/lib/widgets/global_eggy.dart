import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EggyCorner { topLeft, topRight, bottomLeft, bottomRight }

class EggyController extends ChangeNotifier {
  static final EggyController instance = EggyController._();
  EggyController._() {
    _loadInitialCourse();
  }

  Future<void> _loadInitialCourse() async {
    final prefs = await SharedPreferences.getInstance();
    _userCourse = prefs.getString("user_course") ?? "";
    _userMascot = prefs.getString("user_mascot") ?? "assets/images/mascot_boy.png";
    notifyListeners();
  }

  bool _isVisible = false;
  bool get isVisible => _isVisible;
  set isVisible(bool val) {
    _isVisible = val;
    notifyListeners();
  }

  bool _isTimerRunning = false;
  bool get isTimerRunning => _isTimerRunning;
  set isTimerRunning(bool val) {
    _isTimerRunning = val;
    notifyListeners();
  }

  int _currentTab = 0;
  int get currentTab => _currentTab;
  set currentTab(int val) {
    _currentTab = val;
    notifyListeners();
  }

  String _userCourse = "";
  String get userCourse => _userCourse;
  set userCourse(String val) {
    _userCourse = val;
    notifyListeners();
  }

  String _userMascot = "assets/images/mascot_boy.png";
  String get userMascot => _userMascot;
  set userMascot(String val) {
    _userMascot = val;
    notifyListeners();
  }

  // Animation triggers stream
  final StreamController<String> _triggerController = StreamController<String>.broadcast();
  Stream<String> get animationTriggerStream => _triggerController.stream;

  void triggerJoyBounce() {
    _triggerController.add("joy_bounce");
  }

  void triggerStreakWarning() {
    _triggerController.add("streak_warning");
  }
}

class GlobalEggyMascot extends StatefulWidget {
  const GlobalEggyMascot({super.key});

  @override
  State<GlobalEggyMascot> createState() => _GlobalEggyMascotState();
}

class _GlobalEggyMascotState extends State<GlobalEggyMascot> with TickerProviderStateMixin {
  bool _showBubble = false;
  bool _isOnScreen = false;
  Timer? _bubbleTimer;
  int _lastTab = 0;

  // Snapping Corner State
  EggyCorner _currentCorner = EggyCorner.bottomRight;
  Offset? _dragOffset;

  // Idle vertical translation float animation
  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  // Joy bounce scale animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Streak warning rapid horizontal translation shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  StreamSubscription? _triggerSubscription;

  @override
  void initState() {
    super.initState();
    EggyController.instance.addListener(_onControllerChange);
    
    // Auto popup on start if visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (EggyController.instance.isVisible) {
        _triggerAutoPopup();
      }
    });

    // 1. Idle Float loop (repeat back and forth)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _idleAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
    _idleController.repeat(reverse: true);

    // 2. High-energy "Joy Bounce" scale animation (curves.elasticOut)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // 3. Streak warning shake animation (micro-sequence Tween)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _shakeAnimation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    // Stream listeners for program triggers
    _triggerSubscription = EggyController.instance.animationTriggerStream.listen((event) {
      if (!mounted) return;
      if (event == "joy_bounce") {
        _bounceController.forward(from: 0.0);
      } else if (event == "streak_warning") {
        _triggerStreakWarningAnimation();
      }
    });
  }

  @override
  void dispose() {
    EggyController.instance.removeListener(_onControllerChange);
    _bubbleTimer?.cancel();
    _triggerSubscription?.cancel();
    _idleController.dispose();
    _bounceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerStreakWarningAnimation() {
    _shakeController.repeat(reverse: true);
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _shakeController.stop();
        _shakeController.reset();
      }
    });
  }

  void _onControllerChange() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final controller = EggyController.instance;
      if (controller.isVisible) {
        if (controller.currentTab != _lastTab) {
          _lastTab = controller.currentTab;
          _triggerTabSlideTransition();
        } else {
          _triggerAutoPopup();
        }
      } else {
        setState(() {
          _showBubble = false;
          _isOnScreen = false;
        });
      }
    });
  }

  void _triggerTabSlideTransition() {
    _bubbleTimer?.cancel();
    setState(() {
      _showBubble = false;
      _isOnScreen = false; // Animate Eggy off-screen momentarily
    });

    Timer(const Duration(milliseconds: 400), () {
      if (mounted && EggyController.instance.isVisible) {
        setState(() {
          _isOnScreen = true;
          _showBubble = true;
        });

        _bubbleTimer = Timer(const Duration(seconds: 6), () {
          if (mounted && !EggyController.instance.isTimerRunning) {
            setState(() {
              _showBubble = false;
              _isOnScreen = false;
            });
          }
        });
      }
    });
  }

  void _triggerAutoPopup() {
    _bubbleTimer?.cancel();
    setState(() {
      _isOnScreen = true;
      _showBubble = true;
    });

    _bubbleTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !EggyController.instance.isTimerRunning) {
        setState(() {
          _showBubble = false;
          _isOnScreen = false;
        });
      }
    });
  }

  void _handleTap() {
    EggyController.instance.triggerJoyBounce();

    _bubbleTimer?.cancel();
    setState(() {
      if (!_isOnScreen) {
        _isOnScreen = true;
        _showBubble = true;
      } else {
        _showBubble = !_showBubble;
        if (!_showBubble) {
          _isOnScreen = false;
        }
      }
    });

    if (_showBubble && !EggyController.instance.isTimerRunning) {
      _bubbleTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            _showBubble = false;
            _isOnScreen = false;
          });
        }
      });
    }
  }

  Offset _getCornerPosition(EggyCorner corner, BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    
    const double leftMargin = 20.0;
    final double rightMargin = width - 84.0;
    const double topMargin = 100.0;
    final double bottomMargin = height - 190.0;

    switch (corner) {
      case EggyCorner.topLeft:
        return const Offset(leftMargin, topMargin);
      case EggyCorner.topRight:
        return Offset(rightMargin, topMargin);
      case EggyCorner.bottomLeft:
        return Offset(leftMargin, bottomMargin);
      case EggyCorner.bottomRight:
        return Offset(rightMargin, bottomMargin);
    }
  }

  void _snapToClosestCorner(Offset pos, BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final double midX = width / 2;
    final double midY = height / 2;

    final bool isLeft = pos.dx < midX;
    final bool isTop = pos.dy < midY;

    EggyCorner targetCorner;
    if (isLeft && isTop) {
      targetCorner = EggyCorner.topLeft;
    } else if (!isLeft && isTop) {
      targetCorner = EggyCorner.topRight;
    } else if (isLeft && !isTop) {
      targetCorner = EggyCorner.bottomLeft;
    } else {
      targetCorner = EggyCorner.bottomRight;
    }

    setState(() {
      _currentCorner = targetCorner;
      _dragOffset = null; // snaps back smoothly
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ListenableBuilder(
      listenable: EggyController.instance,
      builder: (context, _) {
        final controller = EggyController.instance;

        // Position coordinates Snapping or Snapped
        final Offset cornerPos = _getCornerPosition(_currentCorner, context);
        final double leftVal = _dragOffset != null ? _dragOffset!.dx : cornerPos.dx;
        final double topVal = _dragOffset != null ? _dragOffset!.dy : (controller.isVisible && _isOnScreen ? cornerPos.dy : cornerPos.dy + 40);

        final bool isLeft = _currentCorner == EggyCorner.topLeft || _currentCorner == EggyCorner.bottomLeft;
        final bool isTop = _currentCorner == EggyCorner.topLeft || _currentCorner == EggyCorner.topRight;

        // Dynamic Speech Bubble alignment placement coordinates
        final double? bubbleLeft = isLeft ? 72.0 : null;
        final double? bubbleRight = isLeft ? null : 72.0;
        final double? bubbleTop = isTop ? 64.0 : null;
        final double? bubbleBottom = isTop ? null : 64.0;

        return AnimatedPositioned(
          duration: _dragOffset != null ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          left: leftVal,
          top: topVal,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (controller.isVisible && !isKeyboardOpen) ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: isKeyboardOpen || !controller.isVisible,
              child: Container(
                width: 260,
                height: 180,
                alignment: isLeft
                    ? (isTop ? Alignment.topLeft : Alignment.bottomLeft)
                    : (isTop ? Alignment.topRight : Alignment.bottomRight),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: isLeft
                      ? (isTop ? Alignment.topLeft : Alignment.bottomLeft)
                      : (isTop ? Alignment.topRight : Alignment.bottomRight),
                  children: [
                    // Speech Bubble Overlay Snaps dynamically
                    if (_showBubble && _dragOffset == null)
                      Positioned(
                        left: bubbleLeft,
                        right: bubbleRight,
                        top: bubbleTop,
                        bottom: bubbleBottom,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 170,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF006A63).withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _getTipText(controller),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1C1E),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Draggable Eggy Mascot Avatar
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _dragOffset = _getCornerPosition(_currentCorner, context);
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          if (_dragOffset != null) {
                            _dragOffset = _dragOffset! + details.delta;
                          }
                        });
                      },
                      onPanEnd: (details) {
                        if (_dragOffset != null) {
                          _snapToClosestCorner(_dragOffset!, context);
                        }
                      },
                      onTap: _handleTap,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_idleAnimation, _bounceAnimation, _shakeAnimation]),
                        builder: (context, child) {
                          double dx = _shakeAnimation.value;
                          double dy = _idleAnimation.value;
                          double scale = _bounceAnimation.value;

                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          height: 64,
                          width: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: controller.isTimerRunning
                                  ? const Color(0xFFFF5C77)
                                  : _getCourseBorderColor(controller.userCourse),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              _getAssetPath(controller),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.egg_rounded,
                                  size: 32,
                                  color: _getCourseIconColor(controller.userCourse),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTipText(EggyController controller) {
    if (controller.isTimerRunning) {
      return "Shh... deep work in progress!";
    }
    switch (controller.currentTab) {
      case 0:
        return "Ready to log some focus hours?";
      case 1:
        return "Let's check off these modules!";
      case 2:
        return "Look at all these subjects to master!";
      case 3:
        return "Let's configure your study plan!";
      default:
        return "Keep up the great work!";
    }
  }

  String _getAssetPath(EggyController controller) {
    return controller.userMascot.isNotEmpty ? controller.userMascot : "assets/images/mascot_boy.png";
  }

  Color _getCourseBorderColor(String course) {
    final String clean = course.trim().toUpperCase();
    if (clean == "B.TECH") {
      return Colors.blue.shade400;
    } else if (clean == "MBBS") {
      return const Color(0xFFFF5C77);
    }
    return const Color(0xFF006A63).withOpacity(0.5);
  }

  Color _getCourseIconColor(String course) {
    final String clean = course.trim().toUpperCase();
    if (clean == "B.TECH") {
      return Colors.blue.shade300;
    } else if (clean == "MBBS") {
      return const Color(0xFFFF5C77);
    }
    return const Color(0xFF006A63);
  }
}