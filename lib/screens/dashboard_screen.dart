import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'raw_materials_screen.dart';
import 'supply_orders_screen.dart';
import 'production_screen.dart';
import 'settings_screen.dart';
import '../services/database_services.dart';
import '../services/company_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final effectiveIndex = _selectedIndex.clamp(0, 4);
        final companyId = authService.selectedCompany?.id ?? 'none';
        const navItems = [
          _BottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          _BottomNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2,
            label: 'Materials',
          ),
          _BottomNavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Customers',
          ),
          _BottomNavItem(
            icon: Icons.precision_manufacturing_outlined,
            activeIcon: Icons.precision_manufacturing,
            label: 'Production',
          ),
          _BottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
          ),
        ];

        final screens = [
          HomeTab(
            key: ValueKey('$companyId-home'),
            onNavigate: (index) => setState(() => _selectedIndex = index),
          ),
          RawMaterialsScreen(key: ValueKey('$companyId-materials')),
          SupplyOrdersScreen(key: ValueKey('$companyId-customers')),
          ProductionScreen(key: ValueKey('$companyId-production')),
          SettingsScreen(key: ValueKey('$companyId-settings')),
        ];

        return Scaffold(
          // Match status bar area to the home tab header color
          backgroundColor: effectiveIndex == 0 ? cs.surface : null,
          body: screens[effectiveIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    return Expanded(
                      child: _buildNavItem(
                        context: context,
                        index: index,
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        label: item.label,
                        isSelected: effectiveIndex == index,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final navTheme = theme.bottomNavigationBarTheme;
    final isDark = theme.brightness == Brightness.dark;

    final selectedColor =
        navTheme.selectedItemColor ?? theme.colorScheme.primary;
    final unselectedColor =
        navTheme.unselectedItemColor ?? theme.colorScheme.onSurfaceVariant;
    final pillColor = selectedColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? pillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: isSelected ? selectedColor : unselectedColor,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const HomeTab({super.key, this.onNavigate});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DatabaseService databaseService = DatabaseService();
  StreamSubscription<Map<String, int>>? _summarySubscription;

  int pendingMaterialOrders = 0;
  int pendingSupplyOrders = 0;
  int activeProductionJobs = 0;

  @override
  void initState() {
    super.initState();
    _subscribeSummary();
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    super.dispose();
  }

  void _subscribeSummary() {
    _summarySubscription = databaseService.watchDashboardSummary().listen(
      (summary) {
        if (!mounted) return;
        setState(() {
          pendingMaterialOrders = summary['rawMaterials'] ?? 0;
          pendingSupplyOrders = summary['supplyOrders'] ?? 0;
          activeProductionJobs = summary['production'] ?? 0;
        });
      },
      onError: (Object error) {
        debugPrint('Dashboard summary stream error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header — extends behind status bar so color matches
          Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 20),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.70),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          authService.currentUser?.displayName ??
                              authService.currentUser?.email
                                  ?.split('@')
                                  .first ??
                              'User',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        if (authService.selectedCompany != null) ...[
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: authService.companies.length <= 1
                                  ? null
                                  : () => _showCompanyPicker(context,
                                      authService, authService.companies),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCC2200)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFCC2200)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      authService.selectedCompany!.name,
                                      style: const TextStyle(
                                        color: Color(0xFFF89832),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (authService.companies.length > 1) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Color(0xFFF89832),
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.logout,
                          color: cs.error.withValues(alpha: 0.8)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content:
                                const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await authService.logout();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                DashboardCard(
                  icon: Icons.inventory_2_outlined,
                  count: pendingMaterialOrders.toString(),
                  title: 'Open Material Orders',
                  color: const Color(0xFFFF9800),
                  onTap: () => widget.onNavigate?.call(1),
                ),
                const SizedBox(height: 14),
                DashboardCard(
                  icon: Icons.people_outline,
                  count: pendingSupplyOrders.toString(),
                  title: 'Pending Customer Orders',
                  color: const Color(0xFF2196F3),
                  onTap: () => widget.onNavigate?.call(2),
                ),
                const SizedBox(height: 14),
                DashboardCard(
                  icon: Icons.engineering_outlined,
                  count: activeProductionJobs.toString(),
                  title: 'Active Production Jobs',
                  color: const Color(0xFF4CAF50),
                  onTap: () => widget.onNavigate?.call(3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showCompanyPicker(
    BuildContext context,
    AuthService auth,
    List<CompanyConfig> companies,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    final selected = await showModalBottomSheet<CompanyConfig>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Switch Organization',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: companies.map((c) {
                    final isCurrent = c.id == auth.selectedCompany?.id;
                    return InkWell(
                      onTap: isCurrent ? null : () => Navigator.pop(ctx, c),
                      child: Container(
                        color: isCurrent
                            ? cs.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isCurrent ? cs.primary : cs.onSurface,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Icon(Icons.check_circle,
                                  color: cs.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected.id == auth.selectedCompany?.id) return;
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Switch to ${selected.name}?'),
        content: const Text(
            'This will reload all data for the selected organization.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    await auth.selectCompany(selected.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${selected.name}')),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String count;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.count,
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withValues(alpha: 0.15),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          height: 160,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
