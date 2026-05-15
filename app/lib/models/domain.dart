/// Доменные модели приложения «Электронная отчётность».
class AppUser {
  final int id;
  final String login;
  final String district;
  final String passwordHash;

  const AppUser({
    required this.id,
    required this.login,
    required this.district,
    required this.passwordHash,
  });

  factory AppUser.fromRow(Map<String, Object?> r) => AppUser(
        id: r['id'] as int,
        login: r['login'] as String,
        district: r['district'] as String,
        passwordHash: r['password_hash'] as String,
      );
}

class Organization {
  final int id;
  final String regionCode;
  final String okpo;
  final String name;
  final String? konh;
  final String? legalForm;

  const Organization({
    required this.id,
    required this.regionCode,
    required this.okpo,
    required this.name,
    required this.konh,
    required this.legalForm,
  });

  factory Organization.fromRow(Map<String, Object?> r) => Organization(
        id: r['id'] as int,
        regionCode: (r['region_code'] ?? '') as String,
        okpo: (r['okpo'] ?? '') as String,
        name: (r['name'] ?? '') as String,
        konh: r['konh'] as String?,
        legalForm: r['legal_form'] as String?,
      );
}

class Report {
  final int id;
  final int organizationId;
  final String formType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String version;
  final DateTime updatedAt;

  const Report({
    required this.id,
    required this.organizationId,
    required this.formType,
    required this.periodStart,
    required this.periodEnd,
    required this.version,
    required this.updatedAt,
  });

  factory Report.fromRow(Map<String, Object?> r) => Report(
        id: r['id'] as int,
        organizationId: r['organization_id'] as int,
        formType: r['form_type'] as String,
        periodStart: DateTime.parse(r['period_start'] as String),
        periodEnd: DateTime.parse(r['period_end'] as String),
        version: (r['version'] ?? '') as String,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  String periodLabel() {
    final months = const [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря'
    ];
    String fmt(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
    return '${fmt(periodStart)} - ${fmt(periodEnd)}';
  }
}

class ReportValue {
  final int reportId;
  final String xmlTag;
  final String? value;
  final String typeName;
  final bool hasFormula;

  const ReportValue({
    required this.reportId,
    required this.xmlTag,
    required this.value,
    required this.typeName,
    required this.hasFormula,
  });
}
