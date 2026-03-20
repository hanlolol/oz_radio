class Sentence {
  final String original;
  final String translationLiterary; // 문학형 번역
  final String translationLiteral;  // 직역형 번역

  Sentence({
    required this.original, 
    required this.translationLiterary, 
    required this.translationLiteral
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      original: json['original'] ?? '',
      // 데이터 파트에서 키를 분리하기 전까지는 기존 'translation' 값을 양쪽에 폴백(Fallback)으로 넣습니다.
      translationLiterary: json['translation_literary'] ?? json['translation'] ?? '',
      translationLiteral: json['translation_literal'] ?? json['translation'] ?? '',
    );
  }
}

class Paragraph {
  final int paragraphIndex;
  final List<Sentence> sentences;

  Paragraph({required this.paragraphIndex, required this.sentences});

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    var list = json['sentences'] as List? ?? [];
    List<Sentence> sentencesList = list.map((i) => Sentence.fromJson(i)).toList();
    
    return Paragraph(
      paragraphIndex: json['paragraph_index'] ?? 0,
      sentences: sentencesList,
    );
  }
}

class Chapter {
  final String chapterId;
  final String title;
  final List<Paragraph> content;

  Chapter({required this.chapterId, required this.title, required this.content});

  factory Chapter.fromJson(Map<String, dynamic> json) {
    var list = json['content'] as List? ?? [];
    List<Paragraph> contentList = list.map((i) => Paragraph.fromJson(i)).toList();
    
    return Chapter(
      chapterId: json['chapter_id'] ?? '',
      title: json['title'] ?? '',
      content: contentList,
    );
  }
}