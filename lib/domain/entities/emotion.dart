// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 情绪实体（domain 层）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// 情绪标签
enum EmotionLabel {
  happy,
  sad,
  angry,
  anxious,
  surprised,
  neutral;

  static EmotionLabel fromString(String s) {
    return EmotionLabel.values.firstWhere(
      (e) => e.name == s.toLowerCase(),
      orElse: () => EmotionLabel.neutral,
    );
  }
}

/// 情绪状态
class Emotion {
  final EmotionLabel label;
  final double confidence; // 0.0 ~ 1.0

  const Emotion({
    required this.label,
    this.confidence = 1.0,
  });

  const Emotion.neutral()
      : label = EmotionLabel.neutral,
        confidence = 1.0;

  @override
  String toString() => 'Emotion($label, conf=$confidence)';
}
