class CrystalProgress {
  final double focusProgress;
  final double wisdomProgress;
  final double masteryProgress;

  CrystalProgress({
    required this.focusProgress,
    required this.wisdomProgress,
    required this.masteryProgress,
  });

  Map<String, dynamic> toJson() => {
    'focusProgress': focusProgress,
    'wisdomProgress': wisdomProgress,
    'masteryProgress': masteryProgress,
  };

  factory CrystalProgress.fromJson(Map<String, dynamic> json) => CrystalProgress(
    focusProgress: (json['focusProgress'] as num).toDouble(),
    wisdomProgress: (json['wisdomProgress'] as num).toDouble(),
    masteryProgress: (json['masteryProgress'] as num).toDouble(),
  );
}
