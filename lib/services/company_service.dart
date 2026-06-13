import 'package:flutter/foundation.dart';
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
    return const [
      CompanyConfig(
        id: 'divit_plast',
        name: 'Divit Plast',
        supabaseUrl: 'https://mzhtepivprtxaqucyrlu.supabase.co',
        supabaseAnonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16aHRlcGl2cHJ0eGFxdWN5cmx1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExMDc4NzYsImV4cCI6MjA5NjY4Mzg3Nn0.i17KF40r3vTp_cSZ-zu5iGxEiAU_Rpf3W4WzCwF_hWQ',
      ),
      CompanyConfig(
        id: 'divit_plast_llp',
        name: 'Divit Plast LLP',
        supabaseUrl: 'https://mbcyfehrqznfwvfyvrhe.supabase.co',
        supabaseAnonKey: 'sb_publishable_8borVLuL1JcD0w9GObmHiw_U1TAT3Pl',
      ),
    ];
  }
}
