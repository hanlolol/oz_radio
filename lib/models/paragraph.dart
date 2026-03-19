class Paragraph {
  final int id;
  final String original;
  final String translation;
  final double originalSpeed;
  final double midGap; // 원문과 번역 사이 무음
  final double postGap; // 문단 간 무음

  Paragraph({
    required this.id,
    required this.original,
    required this.translation,
    this.originalSpeed = 0.92,
    this.midGap = 0.8,
    this.postGap = 1.1,
  });

  // JSON에서 객체로 변환하는 팩토리 메서드
  factory Paragraph.fromJson(Map<String, dynamic> json) {
    return Paragraph(
      id: json['paragraph_id'],
      original: json['original'],
      translation: json['translation'],
      originalSpeed: json['settings']['original_speed'],
      midGap: json['settings']['mid_gap'],
      postGap: json['settings']['post_gap'],
    );
  }
}