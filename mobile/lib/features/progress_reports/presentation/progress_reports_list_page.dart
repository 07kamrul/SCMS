import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/shared/widgets/error_view.dart';
import 'package:mobile/shared/widgets/loading_view.dart';

import '../bloc/progress_reports_list_bloc.dart';
import '../bloc/progress_reports_list_event.dart';
import '../bloc/progress_reports_list_state.dart';
import '../data/progress_report_models.dart';
import 'progress_report_form_page.dart';

/// Per-project list of past daily progress reports. Tapping a row opens a
/// simple read-only detail view of that report.
class ProgressReportsListPage extends StatelessWidget {
  const ProgressReportsListPage({super.key, required this.projectId});

  final String projectId;

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProgressReportFormPage(projectId: projectId)),
    );
    if (context.mounted) {
      context.read<ProgressReportsListBloc>().add(ProgressReportsListStarted(projectId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProgressReportsListBloc>()..add(ProgressReportsListStarted(projectId)),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Progress Reports')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context),
            tooltip: 'New progress report',
            child: const Icon(Icons.add),
          ),
          body: BlocBuilder<ProgressReportsListBloc, ProgressReportsListState>(
            builder: (context, state) => switch (state) {
              ProgressReportsListInitial() ||
              ProgressReportsListLoading() => const LoadingView(),
              ProgressReportsListFailure(:final message) => ErrorView(
                message: message,
                onRetry: () => context.read<ProgressReportsListBloc>().add(
                  ProgressReportsListStarted(projectId),
                ),
              ),
              ProgressReportsListLoaded() => _ReportsList(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList({required this.state});

  final ProgressReportsListLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.reports.isEmpty) {
      return const Center(child: Text('No progress reports yet.'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final isNearBottom =
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200;
        if (isNearBottom && state.hasMore && !state.isLoadingMore) {
          context.read<ProgressReportsListBloc>().add(const ProgressReportsListMoreRequested());
        }
        return false;
      },
      child: ListView.separated(
        itemCount: state.reports.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.reports.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final report = state.reports[index];
          return ListTile(
            title: Text(DateFormat.yMMMd().format(report.reportDate)),
            subtitle: Text(
              (report.summary?.isNotEmpty ?? false) ? report.summary! : 'No summary',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              report.overallProgressPercent != null
                  ? '${report.overallProgressPercent}%'
                  : '${report.stageEntries.length} stage${report.stageEntries.length == 1 ? '' : 's'}',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => _ProgressReportDetailPage(report: report)),
            ),
          );
        },
      ),
    );
  }
}

/// Simple read-only detail view for a single report.
class _ProgressReportDetailPage extends StatelessWidget {
  const _ProgressReportDetailPage({required this.report});

  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMd().format(report.reportDate))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (report.overallProgressPercent != null) ...[
            Text('Overall progress', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('${report.overallProgressPercent}%', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
          ],
          if (report.summary != null && report.summary!.isNotEmpty) ...[
            Text('Summary', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(report.summary!),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Stages', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (report.stageEntries.isEmpty) const Text('No stage entries recorded.'),
          for (final entry in report.stageEntries)
            Card(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              child: ListTile(
                title: Text(entry.stageName),
                subtitle: entry.notes != null && entry.notes!.isNotEmpty ? Text(entry.notes!) : null,
                trailing: Text('${entry.progressPercent}%'),
              ),
            ),
        ],
      ),
    );
  }
}
