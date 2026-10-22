// M2 FE-1: the estimated delivery date and the gestational age in weeks, from
// the gestational_age section of the Clinical Rules Table. The date drives the
// ANC schedule (M6 FE-1), the fetal-movement rule (M4 FE-4) and outcome
// classification (M6 FE-4).

/// Where an estimated delivery date came from.
enum EddBasis {
  /// The first day of the last menstrual period.
  lmp,

  /// An expected delivery date the woman already knows (from a card or scan).
  edd,

  /// Only the pregnancy month.
  month;

  /// The value the server stores (lmp, edd, month).
  String get code => name;
}

class GestationalAge {
  const GestationalAge({
    required this.fullTermWeeks,
    required this.lmpToEddDays,
    required this.weeksPerMonth,
    required this.registrationWeeks,
  });

  factory GestationalAge.fromJson(Map<String, dynamic> table) {
    final json = table['gestational_age'] as Map<String, dynamic>;
    final [lo, hi] = (json['registration_weeks'] as List).cast<num>();
    return GestationalAge(
      fullTermWeeks: json['full_term_weeks'] as int,
      lmpToEddDays: json['lmp_to_edd_days'] as int,
      weeksPerMonth: (json['weeks_per_month'] as num).toDouble(),
      registrationWeeks: (lo, hi),
    );
  }

  final int fullTermWeeks;
  final int lmpToEddDays;
  final double weeksPerMonth;

  /// The gestational age a pregnancy may have at registration.
  final (num, num) registrationWeeks;

  /// The estimated delivery date from the LMP date (Naegele: + 280 days).
  DateTime eddFromLmp(DateTime lmp) => _day(lmp).add(Duration(days: lmpToEddDays));

  /// The estimated delivery date from the pregnancy month only: the month's
  /// midpoint, counted from [registeredOn].
  DateTime eddFromMonth(int month, DateTime registeredOn) {
    final weeks = (month - 0.5) * weeksPerMonth;
    return _day(registeredOn).add(Duration(days: ((fullTermWeeks - weeks) * 7).round()));
  }

  /// Gestational age in weeks (with fractions) on [date].
  double weeksOn(DateTime edd, DateTime date) =>
      fullTermWeeks - _day(edd).difference(_day(date)).inDays / 7;

  /// Completed weeks on [date].
  int completedWeeksOn(DateTime edd, DateTime date) => weeksOn(edd, date).floor();

  /// The month of pregnancy (1–10) on [date], for the form's month field:
  /// month m covers the weeks from (m - 1) to m months.
  int monthOn(DateTime edd, DateTime date) => (weeksOn(edd, date) / weeksPerMonth).ceil().clamp(1, 10);

  /// Whether [edd] gives a gestational age that a pregnancy can have at registration on [registeredOn].
  bool fitsRegistration(DateTime edd, DateTime registeredOn) {
    final weeks = weeksOn(edd, registeredOn);
    return weeks >= registrationWeeks.$1 && weeks <= registrationWeeks.$2;
  }

  /// A stored pregnancy's estimated delivery date (YYYY-MM-DD), or, for a
  /// pregnancy saved before the date existed, the estimate from its month.
  DateTime eddOf({required String? estimatedDeliveryDate, required String registeredOn, required int month}) {
    final stored = estimatedDeliveryDate == null ? null : DateTime.tryParse(estimatedDeliveryDate);
    return stored ?? eddFromMonth(month, DateTime.parse(registeredOn));
  }

  static DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
}
