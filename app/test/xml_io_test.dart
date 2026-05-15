import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:mer_app/models/domain.dart';
import 'package:mer_app/models/mapping.dart';
import 'package:mer_app/services/xml_io.dart';

void main() {
  test('XmlExporter+XmlImporter roundtrip preserves values', () {
    final rows = [
      const MappingRow(
        id: 1,
        xmlTag: 'XMLTAG_Отчет_Графа1Стр_1101',
        razdelNumber: 1,
        razdelName: 'Сельхоз',
        codeStr: 1101,
        namePokazatel: 'Озимые',
        codeGraf: 1,
        nameColumn: 'Площадь',
        filenameDbf: null,
        filenameDistrict: null,
        fieldInFile: null,
        idForm: null,
        isService: false,
        primech: null,
        fullName: null,
        sortId: 1,
      ),
    ];
    final schema = FormSchema.fromRows('2-фермер', rows);
    final org = const Organization(
      id: 3017,
      regionCode: '0299',
      okpo: '3017',
      name: 'АРТЕМОВ С.В.',
      konh: null,
      legalForm: null,
    );
    final report = Report(
      id: 1,
      organizationId: 3017,
      formType: '2-фермер',
      periodStart: DateTime(2025, 1, 1),
      periodEnd: DateTime(2025, 12, 31),
      version: '11',
      updatedAt: DateTime.now(),
    );
    final values = {
      'XMLTAG_Отчет_Графа1Стр_1101': const ReportValue(
        reportId: 1,
        xmlTag: 'XMLTAG_Отчет_Графа1Стр_1101',
        value: '42.5',
        typeName: 'Double',
        hasFormula: false,
      ),
    };
    final xml = XmlExporter.build(XmlExportInput(
      org: org,
      report: report,
      values: values,
      schema: schema,
    ));
    // Sanity check: should contain required attributes.
    expect(xml, contains('XMLTAG_Отчет_Графа1Стр_1101'));
    expect(xml, contains('XMLTAG_Технический_Report_Type'));
    expect(xml, contains('XMLTAG_Реквизиты_КодОкпо'));
    // Should be valid XML.
    final doc = XmlDocument.parse(xml);
    final values2 = XmlImporter.parse(1, xml);
    expect(values2['XMLTAG_Отчет_Графа1Стр_1101']?.value, '42.5');
    expect(values2['XMLTAG_Реквизиты_КодОкпо']?.value, '3017');
    expect(values2['XMLTAG_Технический_Report_Type']?.value, '2-фермер');
    // Sections present.
    final sections =
        doc.findAllElements('Section').map((e) => e.getAttribute('Name'));
    expect(sections, containsAll(['Отчет', 'Реквизиты', 'Технический', 'Титульный']));
  });
}
