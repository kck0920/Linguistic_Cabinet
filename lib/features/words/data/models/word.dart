import 'package:uuid/uuid.dart';


class Word {
  final String id;
  final String english;
  final String korean;
  final String? exampleSentence;
  final String? pronunciation;
  final List<String> tags;
  final int difficulty; // 1-5
  final String? memo;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Word({
    String? id,
    required this.english,
    required this.korean,
    this.exampleSentence,
    this.pronunciation,
    List<String>? tags,
    this.difficulty = 3,
    this.memo,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'english': english,
      'korean': korean,
      'example_sentence': exampleSentence,
      'pronunciation': pronunciation,
      'tags': tags.join(','),
      'difficulty': difficulty,
      'memo': memo,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      english: map['english'],
      korean: map['korean'],
      exampleSentence: map['example_sentence'],
      pronunciation: map['pronunciation'],
      tags: map['tags'] != null
          ? (map['tags'] as String).split(',').where((t) => t.isNotEmpty).toList()
          : [],
      difficulty: map['difficulty'] ?? 3,
      memo: map['memo'],
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Word copyWith({
    String? english,
    String? korean,
    String? exampleSentence,
    String? pronunciation,
    List<String>? tags,
    int? difficulty,
    String? memo,
    String? imagePath,
  }) {
    return Word(
      id: id,
      english: english ?? this.english,
      korean: korean ?? this.korean,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      pronunciation: pronunciation ?? this.pronunciation,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      memo: memo ?? this.memo,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Word && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Word(id: $id, english: $english, korean: $korean)';
  }
}
