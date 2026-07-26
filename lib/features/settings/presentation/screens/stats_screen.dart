import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../review/presentation/screens/review_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(reviewRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 통계'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repo.getReviewStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('에러: ${snapshot.error}'));
          }

          final stats = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewSection(context, stats),
                const SizedBox(height: 24),
                _buildAccuracySection(context, stats),
                const SizedBox(height: 24),
                _buildActivitySection(context, stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '전체 현황',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.book,
                value: '${stats['totalWords']}',
                label: '전체 단어',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.autorenew,
                value: '${stats['dueForReview']}',
                label: '복습 예정',
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccuracySection(BuildContext context, Map<String, dynamic> stats) {
    final accuracy = stats['accuracy'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '정답률',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: accuracy / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accuracy >= 80 ? Colors.green : 
                          accuracy >= 60 ? Colors.orange : Colors.red,
                        ),
                      ),
                      Center(
                        child: Text(
                          '$accuracy%',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '총 ${stats['totalReviews']}회 복습',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection(BuildContext context, Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '학습 팁',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTipItem(
                  context,
                  icon: Icons.lightbulb,
                  text: '매일 조금씩 복습하는 것이 효과적입니다',
                ),
                const Divider(),
                _buildTipItem(
                  context,
                  icon: Icons.star,
                  text: '어려운 단어는 복습 빈도를 높이세요',
                ),
                const Divider(),
                _buildTipItem(
                  context,
                  icon: Icons.quiz,
                  text: '퀴즈를 통해 기억을 테스트하세요',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
