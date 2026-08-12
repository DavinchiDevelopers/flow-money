class CurrencyRate {
  final String code;
  final double rate;
  final String flag;
  final String name;
  final DateTime updatedAt;

  const CurrencyRate({
    required this.code,
    required this.rate,
    required this.flag,
    required this.name,
    required this.updatedAt,
  });

  factory CurrencyRate.fromApiResponse(String code, Map<String, dynamic> apiResponse) {
    final rates = apiResponse['rates'] as Map<String, dynamic>;
    final kztRate = rates['KZT'] as num;

    double rateToKzt;
    if (code == 'USD') {
      rateToKzt = kztRate.toDouble();
    } else {
      final codeRate = rates[code] as num;
      rateToKzt = kztRate / codeRate;
    }

    return CurrencyRate(
      code: code,
      rate: rateToKzt,
      flag: _flagFor(code),
      name: _nameFor(code),
      updatedAt: DateTime.now(),
    );
  }

  static String _flagFor(String code) => switch (code) {
    'USD' => '\u{1F1FA}\u{1F1F8}',
    'RUB' => '\u{1F1F7}\u{1F1FA}',
    'EUR' => '\u{1F1EA}\u{1F1FA}',
    'CNY' => '\u{1F1E8}\u{1F1F3}',
    'TRY' => '\u{1F1F9}\u{1F1F7}',
    _ => '\u{1F3F3}\u{FE0F}',
  };

  static String _nameFor(String code) => switch (code) {
    'USD' => 'US Dollar',
    'RUB' => 'Russian Ruble',
    'EUR' => 'Euro',
    'CNY' => 'Chinese Yuan',
    'TRY' => 'Turkish Lira',
    _ => code,
  };

  String get formattedRate => rate.toStringAsFixed(2);
}
