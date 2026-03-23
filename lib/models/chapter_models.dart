class Sentence {
  final int sentenceId;
  final String originalText;
  final String translationLiterary;
  final String translationLiteral;

  Sentence({
    required this.sentenceId,
    required this.originalText,
    required this.translationLiterary,
    required this.translationLiteral,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      sentenceId: json['sentence_id'] ?? 0,
      originalText: json['original_text'] ?? '',
      translationLiterary: json['translation_literary'] ?? '',
      translationLiteral: json['translation_literal'] ?? '',
    );
  }
}

class Paragraph {
  final int paragraphId;
  final List<Sentence> sentences;

  Paragraph({required this.paragraphId, required this.sentences});

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    var list = json['sentences'] as List? ?? [];
    List<Sentence> sentencesList = list.map((i) => Sentence.fromJson(i)).toList();
    
    return Paragraph(
      paragraphId: json['paragraph_id'] ?? 0,
      sentences: sentencesList,
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
    var list = json['paragraphs'] as List? ?? [];
    List<Paragraph> paragraphsList = list.map((i) => Paragraph.fromJson(i)).toList();
    
    return Chapter(
      bookId: json['book_id'] ?? '',
      chapter: json['chapter'] ?? 0,
      paragraphs: paragraphsList,
    );
  }
}