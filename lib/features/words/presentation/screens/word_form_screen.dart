import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/word.dart';
import '../../data/repositories/word_repository.dart';
import '../../../review/data/models/review_card.dart';
import '../../../review/presentation/screens/review_screen.dart';
import 'word_list_screen.dart';
import '../../../../core/theme/cabinet_colors.dart';
import '../../../../core/theme/cabinet_theme.dart';
import '../../../../shared/widgets/cabinet_widgets.dart';

class WordFormScreen extends ConsumerStatefulWidget {
  final Word? word;

  const WordFormScreen({super.key, this.word});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _englishController;
  late TextEditingController _koreanController;
  late TextEditingController _exampleController;
  late TextEditingController _pronunciationController;
  late TextEditingController _memoController;
  late TextEditingController _tagController;
  int _difficulty = 3;
  List<String> _tags = [];
  Uint8List? _imageBytes;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _englishController = TextEditingController(text: widget.word?.english ?? '');
    _koreanController = TextEditingController(text: widget.word?.korean ?? '');
    _exampleController = TextEditingController(text: widget.word?.exampleSentence ?? '');
    _pronunciationController = TextEditingController(text: widget.word?.pronunciation ?? '');
    _memoController = TextEditingController(text: widget.word?.memo ?? '');
    _tagController = TextEditingController();
    _difficulty = widget.word?.difficulty ?? 3;
    _tags = List.from(widget.word?.tags ?? []);
    _imagePath = widget.word?.imagePath;

    if (_imagePath != null) {
      if (kIsWeb) {
        try {
          _imageBytes = base64Decode(_imagePath!);
        } catch (_) {}
      } else {
        try {
          final file = File(_imagePath!);
          if (file.existsSync()) {
            _imageBytes = file.readAsBytesSync();
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _englishController.dispose();
    _koreanController.dispose();
    _exampleController.dispose();
    _pronunciationController.dispose();
    _memoController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(cabinetThemeModeProvider);
    final colors = CabinetColors.fromMode(themeMode);
    final theme = CabinetTheme(colors);
    final isEditing = widget.word != null;

    return CabinetPaperScaffold(
      colors: colors,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'EDIT CARD' : 'NEW COLLECTED WORD',
          style: theme.labelMono.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.accent),
              onPressed: _deleteWord,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CabinetPaperCard(
                    colors: colors,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CABINET CATALOG FORM', style: theme.labelMono),
                            CabinetStamp(
                              text: isEditing ? 'EDITING' : 'NEW CARD',
                              color: colors.accent,
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Word English
                        _buildLabel('ENGLISH WORD *', theme),
                        TextFormField(
                          controller: _englishController,
                          style: theme.wordTitle.copyWith(fontSize: 24),
                          decoration: _buildInputDecoration('e.g. serendipity', colors, theme),
                          validator: (val) => val == null || val.isEmpty ? '단어를 입력해 주세요.' : null,
                        ),
                        const SizedBox(height: 16),

                        // Korean Meaning
                        _buildLabel('KOREAN MEANING *', theme),
                        TextFormField(
                          controller: _koreanController,
                          style: theme.meaningSerif.copyWith(fontSize: 20),
                          decoration: _buildInputDecoration('e.g. 뜻밖의 발견, 우연한 행운', colors, theme),
                          validator: (val) => val == null || val.isEmpty ? '뜻을 입력해 주세요.' : null,
                        ),
                        const SizedBox(height: 16),

                        // Pronunciation / IPA
                        _buildLabel('IPA / PRONUNCIATION', theme),
                        TextFormField(
                          controller: _pronunciationController,
                          style: theme.labelMono.copyWith(fontSize: 13),
                          decoration: _buildInputDecoration('e.g. /ˌserənˈdɪpəti/', colors, theme),
                        ),
                        const SizedBox(height: 16),

                        // Example Sentence
                        _buildLabel('EXAMPLE SENTENCE', theme),
                        TextFormField(
                          controller: _exampleController,
                          style: theme.meaningSerif.copyWith(fontSize: 15),
                          maxLines: 2,
                          decoration: _buildInputDecoration('e.g. Finding this place was pure serendipity.', colors, theme),
                        ),
                        const SizedBox(height: 16),

                        // Moment Note (Caveat style memo)
                        _buildLabel('MOMENT NOTE (손글씨 메모)', theme),
                        TextFormField(
                          controller: _memoController,
                          style: theme.handNote.copyWith(fontSize: 19),
                          maxLines: 3,
                          decoration: _buildInputDecoration('어디서, 왜 이 단어를 저장했나요?', colors, theme),
                        ),
                        const SizedBox(height: 20),

                        // Tag Input
                        _buildLabel('TAGS', theme),
                        Wrap(
                          spacing: 6,
                          children: [
                            ..._tags.map((t) => Chip(
                                  backgroundColor: colors.paper3,
                                  label: Text(t.toUpperCase(), style: theme.labelMono.copyWith(fontSize: 9)),
                                  deleteIcon: Icon(Icons.close, size: 14, color: colors.ink3),
                                  onDeleted: () => setState(() => _tags.remove(t)),
                                )),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.paperEdge,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                _showAddTagDialog(context, colors, theme);
                              },
                              child: Text('+ TAG', style: theme.labelMono.copyWith(fontSize: 9, color: colors.ink)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Neo-Brutal Save Button
                        CabinetBrutalButton(
                          text: isEditing ? '저장 및 업데이트' : '카탈로그 카드 추가',
                          icon: Icons.check,
                          fullWidth: true,
                          onPressed: _saveWord,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: 20,
                    child: CabinetTape(color: colors.tapeYellow, rotateDegrees: 4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, CabinetTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: theme.labelMono.copyWith(fontSize: 10)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, CabinetColors colors, CabinetTheme theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: theme.labelMono.copyWith(color: colors.ink4, fontSize: 12),
      filled: true,
      fillColor: colors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.inkLineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, CabinetColors colors, CabinetTheme theme) {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.paper2,
          title: Text('새 태그 추가', style: theme.wordTitle.copyWith(fontSize: 18)),
          content: TextField(
            controller: tagCtrl,
            autofocus: true,
            style: theme.bodySans,
            decoration: InputDecoration(
              hintText: 'e.g. TOEIC, Novel, Cafe',
              hintStyle: theme.labelMono,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: theme.bodySans),
            ),
            CabinetBrutalButton(
              text: '추가',
              onPressed: () {
                if (tagCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _tags.add(tagCtrl.text.trim().toLowerCase());
                  });
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(wordRepositoryProvider);
    final reviewRepo = ref.read(reviewRepositoryProvider);

    if (widget.word != null) {
      final updatedWord = widget.word!.copyWith(
        english: _englishController.text.trim(),
        korean: _koreanController.text.trim(),
        pronunciation: _pronunciationController.text.trim(),
        exampleSentence: _exampleController.text.trim(),
        tags: _tags.isEmpty ? ['general'] : _tags,
        difficulty: _difficulty,
        memo: _memoController.text.trim(),
        imagePath: _imagePath,
      );
      await repo.updateWord(updatedWord);
    } else {
      final newWord = Word(
        english: _englishController.text.trim(),
        korean: _koreanController.text.trim(),
        pronunciation: _pronunciationController.text.trim(),
        exampleSentence: _exampleController.text.trim(),
        tags: _tags.isEmpty ? ['general'] : _tags,
        difficulty: _difficulty,
        memo: _memoController.text.trim(),
        imagePath: _imagePath,
      );
      await repo.insertWord(newWord);

      final newCard = ReviewCard(
        wordId: newWord.id,
        reviewMethod: ReviewMethod.linear,
        nextReviewDate: DateTime.now(),
      );
      await reviewRepo.insertReviewCard(newCard);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteWord() async {
    if (widget.word == null) return;
    final repo = ref.read(wordRepositoryProvider);
    final reviewRepo = ref.read(reviewRepositoryProvider);
    await reviewRepo.deleteReviewCardByWordId(widget.word!.id);
    await repo.deleteWord(widget.word!.id);
    if (mounted) Navigator.pop(context);
  }
}
