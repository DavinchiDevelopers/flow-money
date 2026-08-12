import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency_rate.dart';

class CurrencyService {
  CurrencyService._();

  static const _baseUrl = 'https://api.exchangerate-api.com/v4/latest';
  static const _currencies = ['USD', 'RUB', 'CNY', 'EUR', 'TRY'];
  static const _cacheKey = 'cached_currency_rates';
  static const _cacheTimeKey = 'cached_currency_rates_time';

  static Future<List<CurrencyRate>> fetchAllRates() async {
    final rates = <CurrencyRate>[];
    try {
      for (final code in _currencies) {
        final rate = await _fetchRate(code);
        if (rate != null) rates.add(rate);
      }
      if (rates.isNotEmpty) await _saveCache(rates);
      return rates;
    } catch (e) {
      debugPrint('Currency fetch error: $e');
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) return cached;
      throw Exception('Failed to load exchange rates');
    }
  }

  static Future<CurrencyRate?> _fetchRate(String code) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/$code')).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates.containsKey('KZT')) {
          return CurrencyRate.fromApiResponse(code, data);
        }
      }
    } catch (e) {
      debugPrint('Error fetching $code: $e');
    }
    return null;
  }

  static Future<void> _saveCache(List<CurrencyRate> rates) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = rates.map((r) => {
        'code': r.code, 'rate': r.rate, 'flag': r.flag, 'name': r.name,
        'updatedAt': r.updatedAt.toIso8601String(),
      }).toList();
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  static Future<List<CurrencyRate>?> _loadCache() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str == null) return null;
      final list = json.decode(str) as List<dynamic>;
      return list.map((d) => CurrencyRate(
        code: d['code'], rate: (d['rate'] as num).toDouble(),
        flag: d['flag'], name: d['name'],
        updatedAt: DateTime.parse(d['updatedAt']),
      )).toList();
    } catch (_) { return null; }
  }
}
