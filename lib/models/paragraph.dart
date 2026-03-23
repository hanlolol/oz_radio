class Paragraph {
  final int id;
  final String original;           // 영어 원문
  final String translationLiterary;  // 의역
  final String translationLiteral;   // 직역

  final double originalSpeed;
  final double midGap;
  final double postGap;

  Paragraph({
    required this.id,
    required this.original,
    required this.translationLiterary,
    required this.translationLiteral,
    this.originalSpeed = 0.92,
    this.midGap = 0.8,
    this.postGap = 1.1,
  });

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>? ?? {};
    
    return Paragraph(
      id: json['paragraph_id'] ?? 0,
      // 🚨 [수정] JSON의 'original_text'를 우선적으로 읽어옵니다.
      original: json['original_text'] ?? json['original'] ?? '', 
      translationLiterary: json['translation_literary'] ?? json['translation'] ?? '',
      translationLiteral: json['translation_literal'] ?? '',
      originalSpeed: (settings['original_speed'] ?? 0.92).toDouble(),
      midGap: (settings['mid_gap'] ?? 0.8).toDouble(),
      postGap: (settings['post_gap'] ?? 1.1).toDouble(),
    );
  }
}