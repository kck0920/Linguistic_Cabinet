import 'package:flutter/material.dart';
import '../../data/models/word.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const WordCard({
    super.key,
    required this.word,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.english,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildDifficultyBadge(context),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                      color: Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                word.korean,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (word.pronunciation != null && word.pronunciation!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  word.pronunciation!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
              if (word.exampleSentence != null && word.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  word.exampleSentence!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (word.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: word.tags.map((tag) {
                    return Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context) {
    Color color;
    String label;

    switch (word.difficulty) {
      case 1:
      case 2:
        color = Colors.green;
        label = '쉬움';
        break;
      case 3:
        color = Colors.orange;
        label = '보통';
        break;
      case 4:
      case 5:
        color = Colors.red;
        label = '어려움';
        break;
      default:
        color = Colors.orange;
        label = '보통';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
