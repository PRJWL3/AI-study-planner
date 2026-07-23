class StudySession {
  final String id;
  final String subject;
  final String chapter;
  final String topic;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String difficulty;
  final bool isBreak;
  final bool isCompleted;

  StudySession({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.topic,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.difficulty,
    this.isBreak = false,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'chapter': chapter,
    'topic': topic,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMinutes': durationMinutes,
    'difficulty': difficulty,
    'isBreak': isBreak,
    'isCompleted': isCompleted,
  };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id'] as String,
    subject: json['subject'] as String,
    chapter: json['chapter'] as String,
    topic: json['topic'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    durationMinutes: json['durationMinutes'] as int,
    difficulty: json['difficulty'] as String,
    isBreak: json['isBreak'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}
