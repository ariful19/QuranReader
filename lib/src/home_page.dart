import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'models.dart';
import 'reader_page.dart';
import 'settings_page.dart';

class QuranHomePage extends StatelessWidget {
  const QuranHomePage({
    super.key,
    required this.controller,
  });

  final QuranAppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('QuranReader'),
            actions: [
              IconButton(
                key: const Key('settings-button'),
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
              IconButton(
                key: const Key('goal-button'),
                onPressed: () => _showGoalDialog(context),
                icon: const Icon(Icons.track_changes_outlined),
                tooltip: 'Reading goal',
              ),
              IconButton(
                key: const Key('about-button'),
                onPressed: () => _showAboutDialog(context),
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'About and attribution',
              ),
              IconButton(
                key: const Key('reset-button'),
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Reset progress',
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  _SummaryCard(controller: controller),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<SurahOrderMode>(
                      segments: const [
                        ButtonSegment(
                          value: SurahOrderMode.normal,
                          label: Text('Normal'),
                          icon: Icon(Icons.format_list_numbered_rounded),
                        ),
                        ButtonSegment(
                          value: SurahOrderMode.chronological,
                          label: Text('Chronological'),
                          icon: Icon(Icons.history_toggle_off_rounded),
                        ),
                      ],
                      selected: {controller.orderMode},
                      onSelectionChanged: (selection) {
                        controller.setOrderMode(selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: controller.visibleSurahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final surah = controller.visibleSurahs[index];
                        return _SurahTile(
                          key: Key('surah-tile-${surah.index}'),
                          controller: controller,
                          surah: surah,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(controller: controller),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reset reading progress?'),
              content: const Text(
                'This clears all saved surah progress, goal data, and returns the list to normal order.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldReset || !context.mounted) {
      return;
    }

    await controller.resetAllProgress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All reading progress has been reset.')),
      );
    }
  }

  Future<void> _showGoalDialog(BuildContext context) async {
    var selectedGoalDate = controller.goalState?.goalDate;
    var errorText = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final metrics = controller.goalMetrics;
            return AlertDialog(
              title: const Text('Reading goal'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedGoalDate == null
                            ? 'No goal date selected yet.'
                            : 'Goal completion date: ${formatYmd(selectedGoalDate!)}',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                selectedGoalDate ?? dateOnly(DateTime.now()),
                            firstDate: dateOnly(DateTime.now()),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedGoalDate = dateOnly(pickedDate);
                              errorText = '';
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          selectedGoalDate == null
                              ? 'Choose date'
                              : 'Change date',
                        ),
                      ),
                      if (errorText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Current goal stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (metrics == null)
                        const Text('No saved goal yet.')
                      else
                        _GoalMetricsView(metrics: metrics),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                if (controller.goalState != null)
                  TextButton(
                    onPressed: () async {
                      await controller.clearGoal();
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('Reset goal'),
                  ),
                FilledButton(
                  onPressed: selectedGoalDate == null
                      ? null
                      : () async {
                          final result =
                              await controller.saveGoal(selectedGoalDate!);
                          if (result != null) {
                            setState(() => errorText = result);
                            return;
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('Save goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About QuranReader'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QuranReader is a native Flutter reading tracker that keeps QuranTracker\'s progress and goal workflows while adding a full Arabic reader.',
              ),
              SizedBox(height: 16),
              Text(
                'Quran text attribution: Tanzil Project, Uthmani text. The bundled text must remain verbatim and should link back to tanzil.net for updates.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                await launchUrl(
                  Uri.parse('https://tanzil.net'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Open Tanzil'),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final QuranAppController controller;

  @override
  Widget build(BuildContext context) {
    final goalMetrics = controller.goalMetrics;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF155E75),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track your Quran reading journey',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              formatPercent(controller.totalPercent),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Total progress based on exact Unicode text lengths from the bundled Quran.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.88),
                  ),
            ),
            if (goalMetrics != null) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text('${goalMetrics.daysRemaining} days left'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.timelapse_rounded, size: 18),
                    label: Text(
                      goalMetrics.estimatedDays == null
                          ? 'Pace not available'
                          : '${goalMetrics.estimatedDays} days at current pace',
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.percent_rounded, size: 18),
                    label: Text(
                      goalMetrics.requiredDailyPercent == null
                          ? 'Daily target unavailable'
                          : '${goalMetrics.requiredDailyPercent!.toStringAsFixed(2)}% per day',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalMetricsView extends StatelessWidget {
  const _GoalMetricsView({required this.metrics});

  final GoalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Days remaining: ${metrics.daysRemaining}',
            style: textTheme.bodyLarge),
        Text(
          'Remaining to read: ${formatPercent(metrics.remainingPercent)}',
          style: textTheme.bodyLarge,
        ),
        Text(
          metrics.estimatedDays == null
              ? 'Estimated completion: not enough reading history yet'
              : 'Estimated days at current pace: ${metrics.estimatedDays}',
          style: textTheme.bodyLarge,
        ),
        Text(
          metrics.projectedCompletionDate == null
              ? 'Projected completion date: unavailable'
              : 'Projected completion date: ${formatYmd(metrics.projectedCompletionDate!)}',
          style: textTheme.bodyLarge,
        ),
        Text(
          metrics.requiredDailyPercent == null
              ? 'Required daily percentage: unavailable'
              : 'Required daily percentage: ${metrics.requiredDailyPercent!.toStringAsFixed(2)}%',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    super.key,
    required this.controller,
    required this.surah,
  });

  final QuranAppController controller;
  final SurahData surah;

  @override
  Widget build(BuildContext context) {
    final percent = controller.percentForSurah(surah);
    final isComplete = controller.isSurahComplete(surah);

    return Card(
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SurahReaderPage(
                controller: controller,
                surahIndex: surah.index,
              ),
            ),
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${surah.index}'),
        ),
        title: Align(
          alignment: Alignment.centerRight,
          child: Text(
            surah.arabicName,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'KFGQPC',
                  fontSize: 26,
                ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            surah.englishName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        trailing: SizedBox(
          width: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatPercent(percent),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Checkbox(
                key: Key('surah-complete-${surah.index}'),
                value: isComplete,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  controller.toggleSurahComplete(surah, value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
