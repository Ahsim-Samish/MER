/// Метаданные отчёта (секции `Реквизиты`, `Технический`, `Титульный`),
/// которые отсутствуют в таблице сопоставления (xlsx), но обязательны в XML
/// формате ГИС «Электронная отчётность».
class MetaField {
  final String xmlTag;
  final String typeName;
  final String label;
  final String? helper;
  final bool readOnly;
  final List<({String value, String label})>? choices;

  const MetaField({
    required this.xmlTag,
    required this.typeName,
    required this.label,
    this.helper,
    this.readOnly = false,
    this.choices,
  });
}

class MetaSection {
  final String name;
  final List<MetaField> fields;
  const MetaSection({required this.name, required this.fields});
}

/// Метасекции для формы 2-фермер. Перечень тэгов взят из эталонного
/// `Пример отчёта XML.xml`.
const titulnyySections = <MetaSection>[
  MetaSection(name: 'Реквизиты', fields: [
    MetaField(
      xmlTag: 'XMLTAG_Реквизиты_КодОкпо',
      typeName: 'Double',
      label: 'Код ОКПО',
      helper: 'Заполняется автоматически из карточки организации',
      readOnly: true,
    ),
  ]),
  MetaSection(name: 'Технический', fields: [
    MetaField(
      xmlTag: 'XMLTAG_Технический_Report_Type',
      typeName: 'String',
      label: 'Тип отчёта',
      readOnly: true,
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Report_Version_Value',
      typeName: 'String',
      label: 'Версия отчёта',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Reporting_Period_Start',
      typeName: 'DateTime',
      label: 'Начало периода',
      readOnly: true,
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Reporting_Period_End',
      typeName: 'DateTime',
      label: 'Конец периода',
      readOnly: true,
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Execute_Report_Finalizer_Macros',
      typeName: 'String',
      label: 'Финализатор (макрос)',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Parent',
      typeName: 'Double',
      label: 'Parent',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Технический_Target_Office',
      typeName: 'Double',
      label: 'Target_Office',
    ),
  ]),
  MetaSection(name: 'Титульный', fields: [
    MetaField(
      xmlTag: 'XMLTAG_Титульный_Организация',
      typeName: 'String',
      label: 'Организация',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_РегНомер',
      typeName: 'String',
      label: 'Регистрационный номер',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_ФискКод',
      typeName: 'String',
      label: 'Фискальный код',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_ГородРегистрацииОрганизации',
      typeName: 'String',
      label: 'Город регистрации организации',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_НомерТелефона',
      typeName: 'String',
      label: 'Номер телефона',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_РуководительОрганизации',
      typeName: 'String',
      label: 'Руководитель организации',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_ГлавныйБухгалтер',
      typeName: 'String',
      label: 'Главный бухгалтер',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_Исполнитель',
      typeName: 'String',
      label: 'Исполнитель',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_НаправитьОтчетВ',
      typeName: 'String',
      label: 'Направить отчёт в',
    ),
    MetaField(
      xmlTag: 'XMLTAG_Титульный_ОтчетныйПериод',
      typeName: 'String',
      label: 'Отчётный период',
      readOnly: true,
    ),
  ]),
];

/// Плоский список всех тэгов из метасекций.
Iterable<MetaField> get allMetaFields =>
    titulnyySections.expand((s) => s.fields);
