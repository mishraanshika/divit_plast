import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/company_service.dart';
import 'services/theme_service.dart';
import 'screens/company_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    throw StateError(
      'Failed to load .env file. '
      'Make sure .env exists in the project root and is listed under '
      'flutter > assets in pubspec.yaml. Error: $e',
    );
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final companyService = CompanyService.instance;
  await companyService.initialize();
  final defaultCompany = companyService.companies.first;

  await Supabase.initialize(
    url: defaultCompany.supabaseUrl,
    publishableKey: defaultCompany.supabaseAnonKey,
  );

  final themeService = ThemeService();
  await themeService.initialize();

  runApp(ManufacturingApp(
    companyService: companyService,
    themeService: themeService,
  ));
}

class ManufacturingApp extends StatelessWidget {
  const ManufacturingApp({
    super.key,
    required this.companyService,
    required this.themeService,
  });

  final CompanyService companyService;
  final ThemeService themeService;

  static ThemeData _lightTheme(TextTheme base) => ThemeData(
        useMaterial3: true,
        textTheme: base,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
          iconTheme: IconThemeData(color: Color(0xFF555555)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF2196F3),
          unselectedItemColor: Color(0xFF616161),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedIconTheme: IconThemeData(size: 24),
          unselectedIconTheme: IconThemeData(size: 24),
          selectedLabelStyle: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
          unselectedLabelStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerColor: const Color(0xFFEEEEEE),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2196F3)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  static ThemeData _darkTheme(TextTheme base) => ThemeData(
        useMaterial3: true,
        textTheme: base.apply(
          bodyColor: const Color(0xFFE4E4E4),
          displayColor: const Color(0xFFE4E4E4),
        ),
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: const Color(0xFFE4E4E4),
          surfaceContainerHighest: const Color(0xFF2A2A2A),
          outline: const Color(0xFF3A3A3A),
          outlineVariant: const Color(0xFF2E2E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF111111),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Color(0xFFE4E4E4),
          titleTextStyle: TextStyle(
            color: Color(0xFFE4E4E4),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
          iconTheme: IconThemeData(color: Color(0xFFAAAAAA)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF64B5F6),
          unselectedItemColor: Color(0xFF9E9E9E),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedIconTheme: IconThemeData(size: 24),
          unselectedIconTheme: IconThemeData(size: 24),
          selectedLabelStyle: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
          unselectedLabelStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        dividerColor: const Color(0xFF2A2A2A),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF64B5F6)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.interTextTheme();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<CompanyService>.value(value: companyService),
        ChangeNotifierProvider(
          create: (_) => AuthService(companyService: companyService),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Divit Plast',
          themeMode: theme.mode,
          theme: _lightTheme(base),
          darkTheme: _darkTheme(base),
          debugShowCheckedModeBanner: false,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthService>().initializeAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isInitialized ||
            (auth.isLoading && auth.currentUser == null)) {
          return const SplashScreen();
        }

        if (auth.currentUser == null) {
          return const LoginScreen();
        }

        if (auth.needsCompanySelection) {
          return const CompanySelectionScreen();
        }

        return const DashboardScreen();
      },
    );
  }
}
