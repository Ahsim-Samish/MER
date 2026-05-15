import 'package:flutter/material.dart';

import '../main.dart';
import '../models/domain.dart';
import 'report_editor_screen.dart';

class ReportsScreen extends StatefulWidget {
  final Organization organization;
  const ReportsScreen({super.key, required this.organization});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Report> _reports = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final list = await AppStateScope.of(context)
        .repository
        .listReports(widget.organization.id);
    if (!mounted) return;
    setState(() => _reports = list);
  }

  Future<void> _createReport() async {
    final now = DateTime.now();
    DateTime start = DateTime(now.year, 1, 1);
    DateTime end = DateTime(now.year, 12, 31);
    final repository = AppStateScope.of(context).repository;
    final navigator = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          Future<void> pick({required bool isStart}) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isStart ? start : end,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                if (isStart) {
                  start = picked;
                } else {
                  end = picked;
                }
              });
            }
          }

          String fmt(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: const Text('Выберите параметры отчёта'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => pick(isStart: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата начала периода',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(fmt(start)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => pick(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата завершения периода',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(fmt(end)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Создать отчёт'),
              ),
            ],
          );
        });
      },
    );
    if (result == true) {
      final report = await repository.createReport(
        organizationId: widget.organization.id,
        formType: '2-фермер',
        periodStart: start,
        periodEnd: end,
      );
      await _refresh();
      navigator.push(MaterialPageRoute(
        builder: (_) => ReportEditorScreen(
          organization: widget.organization,
          report: report,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Отчёты ${org.name} (ОКПО: ${org.okpo})'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            onPressed: _createReport,
            icon: const Icon(Icons.add),
            label: const Text('Создать отчёт'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(children: [
                  SizedBox(width: 100, child: Text('ID отчёта')),
                  Expanded(child: Text('Период отчёта')),
                  SizedBox(width: 220),
                ]),
              ),
              if (_reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Отчёты ещё не создавались'),
                )
              else
                ..._reports.map((r) => ListTile(
                      title: Row(children: [
                        SizedBox(width: 100, child: Text('${r.id}')),
                        Expanded(child: Text(r.periodLabel())),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ReportEditorScreen(
                                organization: org,
                                report: r,
                              ),
                            ));
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Редактировать отчёт'),
                        ),
                      ]),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
