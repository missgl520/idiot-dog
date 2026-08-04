// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 好感度实体（domain 层）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 好感度状态
class Affinity {
  /// 信任值 0~100
  final double trust;
  /// 亲密度 0~100
  final double intimacy;
  /// 熟悉度 0~100
  final double familiarity;
  /// 总对话轮次
  final int totalInteractions;
  /// 连续对话天数
  final int streakDays;

  const Affinity({
    required this.trust,
    required this.intimacy,
    required this.familiarity,
    required this.totalInteractions,
    required this.streakDays,
  });

  /// 默认初始状态
  const Affinity.initial()
      : trust = 30,
        intimacy = 20,
        familiarity = 5,
        totalInteractions = 0,
        streakDays = 0;

  /// 好感度等级（根据亲密度计算）
  String get level {
    if (intimacy < 20) return '陌生人';
    if (intimacy < 40) return '点头之交';
    if (intimacy < 60) return '普通朋友';
    if (intimacy < 80) return '好朋友';
    if (intimacy < 95) return '挚友';
    return '灵魂伴侣';
  }

  /// 好感度百分比（综合值）
  double get total =>
      (trust + intimacy + familiarity) / 3;

  @override
  String toString() =>
      'Affinity($level, trust=$trust, intimacy=$intimacy, familiar=$familiarity)';
}
