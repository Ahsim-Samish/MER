import 'package:xml/xml.dart';

import '../models/domain.dart';
import '../models/mapping.dart';
import '../models/meta_schema.dart';

/// Возвращает имя секции по имени XML-тэга вида `XMLTAG_<секция>_<остаток>`.
String? sectionForTag(String tag) {
  if (!tag.startsWith('XMLTAG_')) return null;
  final rest = tag.substring('XMLTAG_'.length);
  final idx = rest.indexOf('_');
  if (idx < 0) return rest;
  return rest.substring(0, idx);
}

class XmlExportInput {
  final Organization org;
  final Report report;
  final Map<String, ReportValue> values;
  final FormSchema schema;

  const XmlExportInput({
    required this.org,
    required this.report,
    required this.values,
    required this.schema,
  });
}

class XmlExporter {
  /// Собирает XML-документ в формате ГИС «Электронная отчётность».
  static String build(XmlExportInput input) {
    // Собираем плоский список «(тэг, секция, тип)» из xlsx + метасекций.
    final entries = <_TagEntry>[];
    final seen = <String>{};
    for (final r in input.schema.all) {
      if (seen.add(r.xmlTag)) {
        entries.add(_TagEntry(
          tag: r.xmlTag,
          section: sectionForTag(r.xmlTag) ?? 'Отчет',
          typeName: _defaultTypeForTag(r.xmlTag),
        ));
      }
    }
    for (final section in titulnyySections) {
      for (final f in section.fields) {
        if (seen.add(f.xmlTag)) {
          entries.add(_TagEntry(
            tag: f.xmlTag,
            section: section.name,
            typeName: f.typeName,
          ));
        }
      }
    }

    final bySection = <String, List<_TagEntry>>{};
    for (final e in entries) {
      bySection.putIfAbsent(e.section, () => []).add(e);
    }
    const order = ['Отчет', 'Реквизиты', 'Технический', 'Титульный'];
    final keys = [
      ...order.where(bySection.containsKey),
      ...bySection.keys.where((k) => !order.contains(k)),
    ];

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element('Root', nest: () {
      builder.element('ReportData', attributes: {'Id': 'signed'}, nest: () {
        for (final section in keys) {
          builder.element('Section',
              attributes: {'Name': section}, nest: () {
            for (final e in bySection[section]!) {
              final v = input.values[e.tag];
              final typeName = v?.typeName ?? e.typeName;
              final hasFormula = v?.hasFormula ?? false;
              final value = v?.value ?? _defaultValueForTag(e.tag, input) ?? '';
              builder.element('ReportValue', attributes: {
                'Name': e.tag,
                'TypeName': typeName,
                'HasFormula': hasFormula ? 'True' : 'False',
              }, nest: value);
            }
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  static String _defaultTypeForTag(String tag) {
    if (tag.contains('Reporting_Period_')) return 'DateTime';
    if (tag.startsWith('XMLTAG_Титульный_')) return 'String';
    if (tag.startsWith('XMLTAG_Технический_')) return 'String';
    return 'Double';
  }

  static String? _defaultValueForTag(String tag, XmlExportInput input) {
    switch (tag) {
      case 'XMLTAG_Реквизиты_КодОкпо':
        return input.org.okpo;
      case 'XMLTAG_Технический_Report_Type':
        return input.report.formType;
      case 'XMLTAG_Технический_Report_Version_Value':
        return input.report.version;
      case 'XMLTAG_Технический_Reporting_Period_Start':
        return _ddmmyyyy(input.report.periodStart);
      case 'XMLTAG_Технический_Reporting_Period_End':
        return _ddmmyyyy(input.report.periodEnd);
      case 'XMLTAG_Титульный_Организация':
        return input.org.name;
      case 'XMLTAG_Титульный_ОтчетныйПериод':
        return 'За ${input.report.periodEnd.year}год';
      default:
        return null;
    }
  }

  static String _ddmmyyyy(DateTime d) {
    String z(int v) => v.toString().padLeft(2, '0');
    return '${z(d.day)}.${z(d.month)}.${d.year}';
  }
}

class _TagEntry {
  final String tag;
  final String section;
  final String typeName;
  _TagEntry({required this.tag, required this.section, required this.typeName});
}

class XmlImporter {
  /// Парсит XML-файл и возвращает map тэг → ReportValue.
  static Map<String, ReportValue> parse(int reportId, String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    final out = <String, ReportValue>{};
    for (final el in doc.findAllElements('ReportValue')) {
      final tag = el.getAttribute('Name');
      if (tag == null) continue;
      out[tag] = ReportValue(
        reportId: reportId,
        xmlTag: tag,
        value: el.innerText,
        typeName: el.getAttribute('TypeName') ?? 'Double',
        hasFormula: (el.getAttribute('HasFormula') ?? 'False') == 'True',
      );
    }
    return out;
  }
}
