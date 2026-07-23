class StudyAvailability {
  final String weekday;
  final String startTime;
  final String endTime;

  StudyAvailability({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory StudyAvailability.fromJson(Map<String, dynamic> json) => StudyAvailability(
    weekday: json['weekday'] as String,
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
  );
}
