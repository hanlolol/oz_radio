class Paragraph {
  final int paragraphId;
  final String originalText;
  final String translationLiterary;
  final String translationLiteral;

  Paragraph({
    required this.paragraphId,
    required this.originalText,
    required this.translationLiterary,
    required this.translationLiteral,
  });

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    return Paragraph(
      paragraphId: json['paragraph_id'] ?? 0,
      originalText: json['original_text'] ?? '',
      translationLiterary: json['translation_literary'] ?? '',
      translationLiteral: json['translation_literal'] ?? '',
    );
  }
}

class Chapter {
  final String bookId;
  final int chapter;
  final List<Paragraph> paragraphs;

  Chapter({
    required this.bookId, 
    required this.chapter, 
    required this.paragraphs
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    // 🚨 여기서 'content'가 아닌 'paragraphs' 키를 읽도록 수정했습니다!
    var list = json['paragraphs'] as List? ?? [];
    List<Paragraph> paragraphsList = list.map((i) => Paragraph.fromJson(i)).toList();
    
    return Chapter(
      bookId: json['book_id'] ?? '',
      chapter: json['chapter'] ?? 0,
      paragraphs: paragraphsList,
    );
  }
}