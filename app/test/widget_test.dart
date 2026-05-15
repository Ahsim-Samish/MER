import 'package:flutter_test/flutter_test.dart';

import 'package:mer_app/models/mapping.dart';

void main() {
  test('FormSchema groups mapping rows into razdels/pokazateli/grafs', () {
    final rows = [
      const MappingRow(
        id: 1,
        xmlTag: 'XMLTAG_Отчет_Графа1Стр_1101',
        razdelNumber: 1,
        razdelName: 'Сельхозкультуры',
        codeStr: 1101,
        namePokazatel: 'Озимые',
        codeGraf: 1,
        nameColumn: 'Площадь, га',
        filenameDbf: null,
        filenameDistrict: null,
        fieldInFile: null,
        idForm: null,
        isService: false,
        primech: null,
        fullName: null,
        sortId: 1,
      ),
      const MappingRow(
        id: 2,
        xmlTag: 'XMLTAG_Отчет_Графа2Стр_1101',
        razdelNumber: 1,
        razdelName: 'Сельхозкультуры',
        codeStr: 1101,
        namePokazatel: 'Озимые',
        codeGraf: 2,
        nameColumn: 'Сбор, ц',
        filenameDbf: null,
        filenameDistrict: null,
        fieldInFile: null,
        idForm: null,
        isService: false,
        primech: null,
        fullName: null,
        sortId: 2,
      ),
      const MappingRow(
        id: 3,
        xmlTag: 'XMLTAG_Отчет_Справочно_X1',
        razdelNumber: null,
        razdelName: 'Справочно',
        codeStr: 9001,
        namePokazatel: 'Прим',
        codeGraf: null,
        nameColumn: null,
        filenameDbf: null,
        filenameDistrict: null,
        fieldInFile: null,
        idForm: null,
        isService: false,
        primech: null,
        fullName: null,
        sortId: 100,
      ),
    ];
    final schema = FormSchema.fromRows('2-фермер', rows);
    expect(schema.razdels.length, 2);
    expect(schema.razdels.first.number, 1);
    expect(schema.razdels.first.rows.length, 1);
    expect(schema.razdels.first.rows.first.grafs.length, 2);
    expect(schema.razdels.last.number, null);
    expect(schema.byTag.containsKey('XMLTAG_Отчет_Графа1Стр_1101'), true);
  });
}
