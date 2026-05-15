import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/domain.dart';
import '../models/mapping.dart';
import '../models/meta_schema.dart';
import '../services/xml_io.dart';

class ReportEditorScreen extends StatefulWidget {
  final Organization organization;
  final Report report;
  const ReportEditorScreen({
    super.key,
    required this.organization,
    required this.report,
  });

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late List<_TabSpec> _tabs;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _typeNames = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final schema = AppStateScope.of(context).schema;
    final values = await AppStateScope.of(context)
        .repository
        .loadValues(widget.report.id);

    _tabs = _buildTabs(schema);
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Все тэги из таблицы сопоставления.
    for (final row in schema.all) {
      final v = values[row.xmlTag];
      _typeNames[row.xmlTag] = v?.typeName ?? _defaultType(row.xmlTag);
      _controllers[row.xmlTag] = TextEditingController(text: v?.value ?? '');
    }
    // Метаполя (Реквизиты / Технический / Титульный) — их нет в xlsx, но они
    // обязательны в XML.
    for (final f in allMetaFields) {
      final v = values[f.xmlTag];
      _typeNames[f.xmlTag] = v?.typeName ?? f.typeName;
      _controllers[f.xmlTag] = TextEditingController(
          text: v?.value ?? _defaultMetaValue(f.xmlTag));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _defaultType(String tag) {
    if (tag.contains('Reporting_Period_')) return 'DateTime';
    if (tag.startsWith('XMLTAG_Титульный_')) return 'String';
    if (tag.startsWith('XMLTAG_Технический_')) return 'String';
    return 'Double';
  }

  String _defaultMetaValue(String tag) {
    switch (tag) {
      case 'XMLTAG_Реквизиты_КодОкпо':
        return widget.organization.okpo;
      case 'XMLTAG_Технический_Report_Type':
        return widget.report.formType;
      case 'XMLTAG_Технический_Report_Version_Value':
        return widget.report.version;
      case 'XMLTAG_Технический_Reporting_Period_Start':
        return _ddmmyyyy(widget.report.periodStart);
      case 'XMLTAG_Технический_Reporting_Period_End':
        return _ddmmyyyy(widget.report.periodEnd);
      case 'XMLTAG_Титульный_Организация':
        return widget.organization.name;
      case 'XMLTAG_Титульный_ОтчетныйПериод':
        return 'За ${widget.report.periodEnd.year}год';
      default:
        return '';
    }
  }

  String _ddmmyyyy(DateTime d) {
    String z(int v) => v.toString().padLeft(2, '0');
    return '${z(d.day)}.${z(d.month)}.${d.year}';
  }

  List<_TabSpec> _buildTabs(FormSchema schema) {
    final tabs = <_TabSpec>[const _TabSpec.titulnyy()];
    for (final r in schema.razdels) {
      tabs.add(_TabSpec.razdel(r));
    }
    return tabs;
  }

  List<ReportValue> _collectValues() {
    final list = <ReportValue>[];
    for (final entry in _controllers.entries) {
      list.add(ReportValue(
        reportId: widget.report.id,
        xmlTag: entry.key,
        value: entry.value.text,
        typeName: _typeNames[entry.key] ?? 'Double',
        hasFormula: false,
      ));
    }
    return list;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppStateScope.of(context)
        .repository
        .saveValues(widget.report.id, _collectValues());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранено')),
    );
  }

  Future<void> _exportXml() async {
    final schema = AppStateScope.of(context).schema;
    final values = {
      for (final v in _collectValues()) v.xmlTag: v,
    };
    final xml = XmlExporter.build(XmlExportInput(
      org: widget.organization,
      report: widget.report,
      values: values,
      schema: schema,
    ));
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: xml));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XML скопирован в буфер обмена')),
      );
      return;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить XML',
      fileName: 'report_${widget.report.id}.xml',
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );
    if (path == null) return;
    await File(path).writeAsString(xml);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сохранено в $path')),
    );
  }

  Future<void> _importXml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    final raw = bytes != null
        ? String.fromCharCodes(bytes)
        : await File(f.path!).readAsString();
    final parsed = XmlImporter.parse(widget.report.id, raw);
    int applied = 0;
    for (final entry in parsed.entries) {
      final ctrl = _controllers[entry.key];
      if (ctrl == null) continue;
      ctrl.text = entry.value.value ?? '';
      _typeNames[entry.key] = entry.value.typeName;
      applied++;
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импортировано показателей: $applied')),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    final period = 'за ${widget.report.periodEnd.year} год';
    final title = '${org.name} (ОКПО: ${org.okpo}'
        '${org.konh != null ? ", КОНХ: ${org.konh}" : ""}) $period';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загрузка отчёта…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
        actions: [
          IconButton(
            tooltip: 'Импорт XML',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _importXml,
          ),
          IconButton(
            tooltip: 'Экспорт XML',
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportXml,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E88E5),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Сохранение…' : 'Сохранить'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map(_buildTabContent).toList(),
      ),
    );
  }

  Widget _buildTabContent(_TabSpec spec) {
    if (spec.isTitulnyy) {
      return _TitulnyyView(
        controllers: _controllers,
        typeNames: _typeNames,
      );
    }
    final schema = AppStateScope.of(context).schema;
    final razdel = spec.razdel!;
    return _RazdelView(
      schema: schema,
      razdel: razdel,
      controllers: _controllers,
      typeNames: _typeNames,
    );
  }
}

class _TabSpec {
  final bool isTitulnyy;
  final ReportRazdel? razdel;
  const _TabSpec._({required this.isTitulnyy, this.razdel});
  const _TabSpec.titulnyy() : this._(isTitulnyy: true);
  _TabSpec.razdel(ReportRazdel r) : this._(isTitulnyy: false, razdel: r);

  String get label =>
      isTitulnyy ? 'ТИТУЛЬНЫЙ' : razdel!.tabLabel.toUpperCase();
}

class _TitulnyyView extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Map<String, String> typeNames;
  const _TitulnyyView({
    required this.controllers,
    required this.typeNames,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Титульный',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          for (final section in titulnyySections)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final f in section.fields)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.label),
                                  if (f.helper != null)
                                    Text(f.helper!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: controllers[f.xmlTag],
                                readOnly: f.readOnly,
                                keyboardType: f.typeName == 'Double'
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true)
                                    : TextInputType.text,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: f.readOnly,
                                  fillColor: f.readOnly
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RazdelView extends StatelessWidget {
  final FormSchema schema;
  final ReportRazdel razdel;
  final Map<String, TextEditingController> controllers;
  final Map<String, String> typeNames;
  const _RazdelView({
    required this.schema,
    required this.razdel,
    required this.controllers,
    required this.typeNames,
  });

  @override
  Widget build(BuildContext context) {
    final headers = schema.grafHeadersOf(razdel);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            razdel.displayTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _RazdelTable(
                razdel: razdel,
                headers: headers,
                controllers: controllers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RazdelTable extends StatelessWidget {
  final ReportRazdel razdel;
  final List<({int? codeGraf, String label})> headers;
  final Map<String, TextEditingController> controllers;
  const _RazdelTable({
    required this.razdel,
    required this.headers,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        );
    return DataTable(
      headingRowColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      columnSpacing: 24,
      columns: [
        DataColumn(label: Text('Наименование показателя', style: headingStyle)),
        DataColumn(label: Text('Код', style: headingStyle)),
        for (final h in headers)
          DataColumn(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(h.label, style: headingStyle),
            ),
          ),
      ],
      rows: razdel.rows
          .map((p) => DataRow(cells: [
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(p.namePokazatel),
                )),
                DataCell(Text(p.codeStr?.toString() ?? '')),
                for (final h in headers)
                  DataCell(_buildCell(p, h.codeGraf)),
              ]))
          .toList(),
    );
  }

  Widget _buildCell(ReportPokazatel p, int? codeGraf) {
    ReportGrafa? g;
    for (final candidate in p.grafs) {
      if (candidate.codeGraf == codeGraf) {
        g = candidate;
        break;
      }
    }
    if (g == null) {
      return const SizedBox(width: 160);
    }
    final tag = g.row.xmlTag;
    return SizedBox(
      width: 160,
      child: TextFormField(
        controller: controllers[tag],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        decoration: const InputDecoration(isDense: true),
      ),
    );
  }
}
