import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class CompanyConfig {
  const CompanyConfig({
    required this.id,
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String id;
  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
}

class CompanyService extends ChangeNotifier {
  CompanyService._();

  static final CompanyService instance = CompanyService._();
  static const String _selectedCompanyKey = 'selected_company_id';

  final Map<String, SupabaseClient> _clients = {};
  List<CompanyConfig> _companies = [];
  String? _selectedCompanyId;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<CompanyConfig> get companies => List.unmodifiable(_companies);

  CompanyConfig? get selectedCompany {
    final selectedId = _selectedCompanyId;
    if (selectedId == null) return null;

    for (final company in _companies) {
      if (company.id == selectedId) return company;
    }

    return null;
  }

  bool get needsCompanySelection =>
      _companies.length > 1 && selectedCompany == null;

  SupabaseClient get client {
    final company = selectedCompany ??
        (_companies.isNotEmpty
            ? _companies.first
            : throw StateError('No Supabase company is configured'));

    return _clients.putIfAbsent(
      company.id,
      () => SupabaseClient(company.supabaseUrl, company.supabaseAnonKey),
    );
  }

  SupabaseClient clientFor(String companyId) {
    final company = _companies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => throw ArgumentError('Unknown company: $companyId'),
    );
    return _clients.putIfAbsent(
      company.id,
      () => SupabaseClient(company.supabaseUrl, company.supabaseAnonKey),
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _companies = _loadCompaniesFromEnv();
    if (_companies.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. '
        'Add DIVIT_PLAST_SUPABASE_URL and DIVIT_PLAST_SUPABASE_ANON_KEY to your .env file.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final savedCompanyId = prefs.getString(_selectedCompanyKey);
    if (_companies.any((company) => company.id == savedCompanyId)) {
      _selectedCompanyId = savedCompanyId;
    } else if (_companies.length == 1) {
      _selectedCompanyId = _companies.first.id;
      await prefs.setString(_selectedCompanyKey, _selectedCompanyId!);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> selectCompany(String companyId) async {
    if (!_companies.any((company) => company.id == companyId)) {
      throw ArgumentError('Unknown company: $companyId');
    }

    _selectedCompanyId = companyId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCompanyKey, companyId);
    notifyListeners();
  }

  Future<void> clearSelection() async {
    _selectedCompanyId = _companies.length == 1 ? _companies.first.id : null;
    final prefs = await SharedPreferences.getInstance();

    if (_selectedCompanyId == null) {
      await prefs.remove(_selectedCompanyKey);
    } else {
      await prefs.setString(_selectedCompanyKey, _selectedCompanyId!);
    }

    notifyListeners();
  }

  static List<CompanyConfig> _loadCompaniesFromEnv() {
    final primaryUrl = _envValue(['DIVIT_PLAST_SUPABASE_URL']);
    final primaryAnonKey = _envValue(['DIVIT_PLAST_SUPABASE_ANON_KEY']);
    final llpUrl = _envValue(['DIVIT_PLAST_LLP_SUPABASE_URL']);
    final llpAnonKey = _envValue(['DIVIT_PLAST_LLP_SUPABASE_ANON_KEY']);

    return [
      if (primaryUrl != null && primaryAnonKey != null)
        CompanyConfig(
          id: 'divit_plast',
          name: 'Divit Plast',
          supabaseUrl: primaryUrl,
          supabaseAnonKey: primaryAnonKey,
        ),
      if (llpUrl != null && llpAnonKey != null)
        CompanyConfig(
          id: 'divit_plast_llp',
          name: 'Divit Plast LLP',
          supabaseUrl: llpUrl,
          supabaseAnonKey: llpAnonKey,
        ),
    ];
  }

  static String? _envValue(List<String> keys) {
    for (final key in keys) {
      final value = dotenv.env[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }
}
