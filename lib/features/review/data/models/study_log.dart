class StudyLog {
  final String id;
  final String wordId;
  final DateTime reviewedAt;
  final bool isCorrect;
  final String? studyMethod; // 'flashcard', 'meaning_quiz', 'fill_blank', 'meaning_typing', 'spelling_typing', 'word_matching', 'grid_matching'
  final int? durationMs;
  final String? answerType; // 'swipe', 'tap', 'typing'

  const StudyLog({
    required this.id,
    required this.wordId,
    required this.reviewedAt,
    required this.isCorrect,
    this.studyMethod,
    this.durationMs,
    this.answerType,
  });

  factory StudyLog.create({
    required String wordId,
    required bool isCorrect,
    String? studyMethod,
    int? durationMs,
    String? answerType,
  }) {
    return StudyLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      wordId: wordId,
      reviewedAt: DateTime.now(),
      isCorrect: isCorrect,
      studyMethod: studyMethod,
      durationMs: durationMs,
      answerType: answerType,
    );
  }

  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      id: map['id'] as String,
      wordId: map['word_id'] as String,
      reviewedAt: DateTime.parse(map['reviewed_at'] as String),
      isCorrect: (map['is_correct'] as int) == 1,
      studyMethod: map['study_method'] as String?,
      durationMs: map['duration_ms'] as int?,
      answerType: map['answer_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'reviewed_at': reviewedAt.toIso8601String(),
      'is_correct': isCorrect ? 1 : 0,
      'study_method': studyMethod,
      'duration_ms': durationMs,
      'answer_type': answerType,
    };
  }
}
