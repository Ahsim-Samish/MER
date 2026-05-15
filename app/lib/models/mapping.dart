/// Описание одной строки таблицы соответствия XML-тэг ↔ показатель.
class MappingRow {
  final int id;
  final String xmlTag;
  final int? razdelNumber;
  final String? razdelName;
  final int? codeStr;
  final String? namePokazatel;
  final int? codeGraf;
  final String? nameColumn;
  final String? filenameDbf;
  final String? filenameDistrict;
  final String? fieldInFile;
  final int? idForm;
  final bool isService;
  final String? primech;
  final String? fullName;
  final int? sortId;

  const MappingRow({
    required this.id,
    required this.xmlTag,
    required this.razdelNumber,
    required this.razdelName,
    required this.codeStr,
    required this.namePokazatel,
    required this.codeGraf,
    required this.nameColumn,
    required this.filenameDbf,
    required this.filenameDistrict,
    required this.fieldInFile,
    required this.idForm,
    required this.isService,
    required this.primech,
    required this.fullName,
    required this.sortId,
  });

  factory MappingRow.fromJson(Map<String, dynamic> j) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString());
    }

    bool asBool(Object? v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      return v.toString() == 'true' || v.toString() == '1';
    }

    return MappingRow(
      id: asInt(j['id']) ?? 0,
      xmlTag: (j['xmltag_name'] ?? '').toString(),
      razdelNumber: asInt(j['number_razdel']),
      razdelName: j['name_razdel']?.toString(),
      codeStr: asInt(j['code_str']),
      namePokazatel: j['name_pokazatel']?.toString(),
      codeGraf: asInt(j['code_graf']),
      nameColumn: j['name_column']?.toString(),
      filenameDbf: j['filename_dbf']?.toString(),
      filenameDistrict: j['filename_district']?.toString(),
      fieldInFile: j['field_in_file']?.toString(),
      idForm: asInt(j['id_form']),
      isService: asBool(j['is_service']),
      primech: j['primech']?.toString(),
      fullName: j['full_name']?.toString(),
      sortId: asInt(j['sort_id']),
    );
  }
}

/// Раздел отчёта, агрегирующий показатели с одинаковым `number_razdel`.
class ReportRazdel {
  final int? number;
  final String name;
  final List<ReportPokazatel> rows;

  ReportRazdel({required this.number, required this.name, required this.rows});

  String get displayTitle =>
      number == null ? name : 'Раздел $number — $name';

  String get tabLabel => number == null ? name : 'Раздел $number';
}

/// Один показатель (строка таблицы в редакторе). Может содержать несколько граф
/// (колонок), каждая из которых соответствует своему XML-тэгу.
class ReportPokazatel {
  final int? codeStr;
  final String namePokazatel;
  final List<ReportGrafa> grafs;

  ReportPokazatel({
    required this.codeStr,
    required this.namePokazatel,
    required this.grafs,
  });
}

/// Одна колонка («графа») в строке показателя — конкретный XML-тэг.
class ReportGrafa {
  final int? codeGraf;
  final String? nameColumn;
  final MappingRow row;

  ReportGrafa({
    required this.codeGraf,
    required this.nameColumn,
    required this.row,
  });
}

/// Полная схема формы 2-фермер: список разделов с показателями и графами.
class FormSchema {
  final String formName;
  final List<MappingRow> all;
  final List<ReportRazdel> razdels;
  final Map<String, MappingRow> byTag;

  FormSchema({
    required this.formName,
    required this.all,
    required this.razdels,
    required this.byTag,
  });

  /// Группирует строки сопоставления в разделы/показатели/графы.
  factory FormSchema.fromRows(String formName, List<MappingRow> rows) {
    final sorted = [...rows]
      ..sort((a, b) {
        int cmp(int? x, int? y) => (x ?? 1 << 30).compareTo(y ?? 1 << 30);
        final r = cmp(a.razdelNumber, b.razdelNumber);
        if (r != 0) return r;
        final s = cmp(a.sortId, b.sortId);
        if (s != 0) return s;
        final c = cmp(a.codeStr, b.codeStr);
        if (c != 0) return c;
        return cmp(a.codeGraf, b.codeGraf);
      });

    // Group by razdel preserving order.
    final razdels = <ReportRazdel>[];
    final byRazdel = <String, List<MappingRow>>{};
    final razdelOrder = <String>[];
    for (final r in sorted) {
      final key = '${r.razdelNumber}|${r.razdelName}';
      byRazdel.putIfAbsent(key, () {
        razdelOrder.add(key);
        return <MappingRow>[];
      }).add(r);
    }
    for (final key in razdelOrder) {
      final group = byRazdel[key]!;
      final num = group.first.razdelNumber;
      final name = group.first.razdelName ?? '';
      // Group by code_str preserving order to form pokazateli with grafs.
      final pokazateli = <ReportPokazatel>[];
      final byStr = <String, List<MappingRow>>{};
      final strOrder = <String>[];
      for (final r in group) {
        final k = '${r.codeStr}|${r.namePokazatel}';
        byStr.putIfAbsent(k, () {
          strOrder.add(k);
          return <MappingRow>[];
        }).add(r);
      }
      for (final k in strOrder) {
        final rowsK = byStr[k]!;
        final grafs = rowsK
            .map((r) => ReportGrafa(
                  codeGraf: r.codeGraf,
                  nameColumn: r.nameColumn,
                  row: r,
                ))
            .toList();
        pokazateli.add(ReportPokazatel(
          codeStr: rowsK.first.codeStr,
          namePokazatel: rowsK.first.namePokazatel ?? '',
          grafs: grafs,
        ));
      }
      razdels.add(ReportRazdel(number: num, name: name, rows: pokazateli));
    }

    final byTag = {for (final r in rows) r.xmlTag: r};
    return FormSchema(
      formName: formName,
      all: rows,
      razdels: razdels,
      byTag: byTag,
    );
  }

  /// Возвращает уникальные графы в разделе (для построения заголовка таблицы).
  List<({int? codeGraf, String label})> grafHeadersOf(ReportRazdel r) {
    final seen = <int?>{};
    final out = <({int? codeGraf, String label})>[];
    for (final p in r.rows) {
      for (final g in p.grafs) {
        if (seen.add(g.codeGraf)) {
          out.add((codeGraf: g.codeGraf, label: g.nameColumn ?? ''));
        }
      }
    }
    return out;
  }
}
