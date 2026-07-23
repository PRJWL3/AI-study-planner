class StudyStatistics {
  final int streakDays;
  final int todayEnergy;
  final int weeklyEnergy;
  final int sessionsCompleted;
  final int sessionsGoal;
  final Map<String, double> weeklyProgress;
  final int todayGoalCompleted;
  final int todayGoalTotal;
  final int weeklyGoalMinutes;
  final int weeklyCompletedMinutes;
  final int todayStudyMinutes;
  final int totalStudyMinutes;
  final int sessionsToday;
  final int averageFocusMinutes;
  final double currentSessionProgress;

  StudyStatistics({
    required this.streakDays,
    required this.todayEnergy,
    required this.weeklyEnergy,
    required this.sessionsCompleted,
    required this.sessionsGoal,
    required this.weeklyProgress,
    this.todayGoalCompleted = 0,
    this.todayGoalTotal = 0,
    this.weeklyGoalMinutes = 0,
    this.weeklyCompletedMinutes = 0,
    this.todayStudyMinutes = 0,
    this.totalStudyMinutes = 0,
    this.sessionsToday = 0,
    this.averageFocusMinutes = 0,
    this.currentSessionProgress = 0,
  });

  Map<String, dynamic> toJson() => {
    'streakDays': streakDays,
    'todayEnergy': todayEnergy,
    'weeklyEnergy': weeklyEnergy,
    'sessionsCompleted': sessionsCompleted,
    'sessionsGoal': sessionsGoal,
    'weeklyProgress': weeklyProgress,
    'todayGoalCompleted': todayGoalCompleted,
    'todayGoalTotal': todayGoalTotal,
    'weeklyGoalMinutes': weeklyGoalMinutes,
    'weeklyCompletedMinutes': weeklyCompletedMinutes,
    'todayStudyMinutes': todayStudyMinutes,
    'totalStudyMinutes': totalStudyMinutes,
    'sessionsToday': sessionsToday,
    'averageFocusMinutes': averageFocusMinutes,
    'currentSessionProgress': currentSessionProgress,
  };

  factory StudyStatistics.fromJson(Map<String, dynamic> json) => StudyStatistics(
    streakDays: json['streakDays'] as int,
    todayEnergy: json['todayEnergy'] as int,
    weeklyEnergy: json['weeklyEnergy'] as int,
    sessionsCompleted: json['sessionsCompleted'] as int,
    sessionsGoal: json['sessionsGoal'] as int,
    weeklyProgress: Map<String, double>.from(json['weeklyProgress'] as Map),
    todayGoalCompleted: json['todayGoalCompleted'] as int? ?? 0,
    todayGoalTotal: json['todayGoalTotal'] as int? ?? 0,
    weeklyGoalMinutes: json['weeklyGoalMinutes'] as int? ?? 0,
    weeklyCompletedMinutes: json['weeklyCompletedMinutes'] as int? ?? 0,
    todayStudyMinutes: json['todayStudyMinutes'] as int? ?? 0,
    totalStudyMinutes: json['totalStudyMinutes'] as int? ?? 0,
    sessionsToday: json['sessionsToday'] as int? ?? 0,
    averageFocusMinutes: json['averageFocusMinutes'] as int? ?? 0,
    currentSessionProgress: (json['currentSessionProgress'] as num?)?.toDouble() ?? 0,
  );
}
