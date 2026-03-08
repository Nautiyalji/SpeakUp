import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../providers/progress_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressDataProvider(_selectedDays));
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('My Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector chips
            Row(children: [7, 30, 90].map((d) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text('${d}d'),
                selected: _selectedDays == d,
                onSelected: (_) => setState(() => _selectedDays = d),
                selectedColor: AppColors.primaryBlue,
                backgroundColor: AppColors.darkSurface,
                labelStyle: TextStyle(color: _selectedDays == d ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold),
              ),
            )).toList()),
            const SizedBox(height: 24),

            // Chart
            progress.when(
              data: (data) => data.isEmpty
                  ? _EmptyState()
                  : _ProgressChart(data: data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.errorRed)),
            ),
            const SizedBox(height: 32),

            // Session History
            const Text('Session History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            history.when(
              data: (sessions) => sessions.isEmpty
                  ? const Text('No sessions yet.', style: TextStyle(color: AppColors.textSecondary))
                  : Column(children: sessions.map((s) => _HistoryTile(session: s)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.errorRed)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  final List<dynamic> data;
  const _ProgressChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.successGreen, AppColors.accentBlue, const Color(0xFFD97706), const Color(0xFF9333EA)];
    final keys = ['avg_grammar', 'avg_vocabulary', 'avg_confidence', 'avg_fluency'];
    final labels = ['Grammar', 'Vocab', 'Confidence', 'Fluency'];

    LineChartBarData _line(String key, Color color) => LineChartBarData(
          spots: data.asMap().entries.map((e) {
            final val = (e.value[key] as num?)?.toDouble() ?? 0;
            return FlSpot(e.key.toDouble(), val);
          }).toList(),
          color: color,
          isCurved: true,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
        );

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Expanded(child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: keys.asMap().entries.map((e) => _line(e.value, colors[e.key])).toList(),
          minY: 0, maxY: 100,
        ))),
        const SizedBox(height: 12),
        // Legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: labels.asMap().entries.map((e) =>
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
            Container(width: 12, height: 3, color: colors[e.key]),
            const SizedBox(width: 4),
            Text(e.value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]))).toList()),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16)),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.textSecondary),
        SizedBox(height: 8),
        Text('No data yet. Complete a session!', style: TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _HistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = (session['overall_score'] as num?)?.toDouble() ?? 0;
    final date = session['started_at'] != null
        ? DateTime.tryParse(session['started_at']) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.mic, color: AppColors.accentBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date != null ? '${date.day}/${date.month}/${date.year}' : 'Unknown',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          Text('Turns: ${session['turns_count'] ?? 0} • ${session['level_at_session'] ?? ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Text('${score.toStringAsFixed(0)}%',
            style: TextStyle(color: score >= 70 ? AppColors.successGreen : AppColors.warningOrange,
                fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}
