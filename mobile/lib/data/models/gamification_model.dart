class Mission {
  const Mission({
    required this.key,
    required this.title,
    required this.xp,
    required this.done,
    required this.claimed,
    required this.progress,
    required this.target,
    this.spent,
    this.limit,
  });

  final String key;
  final String title;
  final int xp;
  final bool done;
  final bool claimed;
  final int progress;
  final int target;

  /// Khusus misi "Kemarin di bawah jatah": pengeluaran kemarin vs jatah harian.
  final double? spent;
  final double? limit;

  bool get claimable => done && !claimed;

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
    key: json['key'] as String,
    title: json['title'] as String,
    xp: json['xp'] as int,
    done: json['done'] as bool,
    claimed: json['claimed'] as bool,
    progress: json['progress'] as int,
    target: json['target'] as int,
    spent: json['spent'] == null ? null : double.parse(json['spent'] as String),
    limit: json['limit'] == null ? null : double.parse(json['limit'] as String),
  );
}

class Achievement {
  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.xp,
    required this.target,
    required this.progress,
    required this.unlocked,
    this.unlockedAt,
  });

  final String key;
  final String title;
  final String description;
  final String icon;
  final int xp;
  final int target;
  final int progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  double get ratio => target == 0 ? 0 : progress / target;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    key: json['key'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    xp: json['xp'] as int,
    target: json['target'] as int,
    progress: json['progress'] as int,
    unlocked: json['unlocked'] as bool,
    unlockedAt: json['unlockedAt'] == null ? null : DateTime.parse(json['unlockedAt'] as String),
  );
}

class GamificationState {
  const GamificationState({
    required this.xp,
    required this.level,
    required this.title,
    required this.levelXp,
    required this.nextLevelXp,
    required this.streak,
    required this.longestStreak,
    required this.recordedToday,
    required this.missions,
    required this.achievements,
    required this.newlyUnlocked,
  });

  final int xp;
  final int level;
  final String title;
  final int levelXp;
  final int nextLevelXp;
  final int streak;
  final int longestStreak;
  final bool recordedToday;
  final List<Mission> missions;
  final List<Achievement> achievements;

  /// Lencana yang kebuka di permintaan ini — pemicu animasi perayaan.
  final List<String> newlyUnlocked;

  double get levelRatio => nextLevelXp == 0 ? 0 : levelXp / nextLevelXp;
  int get claimableCount => missions.where((m) => m.claimable).length;
  int get unlockedCount => achievements.where((a) => a.unlocked).length;

  List<Achievement> get freshAchievements =>
      achievements.where((a) => newlyUnlocked.contains(a.key)).toList();

  factory GamificationState.fromJson(Map<String, dynamic> json) {
    final streak = json['streak'] as Map<String, dynamic>;
    return GamificationState(
      xp: json['xp'] as int,
      level: json['level'] as int,
      title: json['title'] as String,
      levelXp: json['levelXp'] as int,
      nextLevelXp: json['nextLevelXp'] as int,
      streak: streak['current'] as int,
      longestStreak: streak['longest'] as int,
      recordedToday: streak['recordedToday'] as bool,
      missions: (json['missions'] as List<dynamic>)
          .map((e) => Mission.fromJson(e as Map<String, dynamic>))
          .toList(),
      achievements: (json['achievements'] as List<dynamic>)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList(),
      newlyUnlocked: (json['newlyUnlocked'] as List<dynamic>).cast<String>(),
    );
  }
}
