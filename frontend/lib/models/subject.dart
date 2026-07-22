class Topic {
  String name;
  String difficulty;
  bool isCompleted;

  Topic({
    required this.name,
    required this.difficulty,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "difficulty": difficulty,
      "isCompleted": isCompleted,
    };
  }

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      name: json["name"],
      difficulty: json["difficulty"],
      isCompleted: json["isCompleted"] ?? false,
    );
  }
}

class Subject {
  String name;
  String difficulty;
  List<Topic> topics;
  String aiSuggestions;

  Subject({
    required this.name,
    required this.difficulty,
    this.topics = const [],
    this.aiSuggestions = "",
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "difficulty": difficulty,
      "topics": topics.map((t) => t.toJson()).toList(),
      "aiSuggestions": aiSuggestions,
    };
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    var topicsList = json["topics"] as List?;
    return Subject(
      name: json["name"],
      difficulty: json["difficulty"],
      topics: topicsList != null
          ? topicsList.map((t) => Topic.fromJson(t)).toList()
          : [],
      aiSuggestions: json["aiSuggestions"] ?? "",
    );
  }
}