import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import 'dart:ui';
import '../constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

extension StringCasingExtension on String {
  String toTitleCase() => isNotEmpty ? (this[0].toUpperCase() + substring(1)) : this;
}

class EnterpriseToken extends StatelessWidget {
  final String label;
  const EnterpriseToken({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.robotoMono(
          fontSize: 10,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class PastelBadge extends StatelessWidget {
  final String label;
  final Color baseColor;
  const PastelBadge({super.key, required this.label, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.alphaBlend(Colors.black.withOpacity(0.4), baseColor),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class ERPSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<SidebarItem> items;

  const ERPSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors
            .primary, // ALWAYS force 'Navy Blue' background per blueprint
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: -2)
                      ]),
                  child: const Icon(Icons.barcode_reader, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Core Inventory',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Sidebar Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                final activeColor = AppColors.secondary;
                final inactiveColor = const Color(
                    0xFF9CA3AF); // Force light gray for dark sidebar
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => onItemSelected(index),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.secondary.withOpacity(0.3),
                                width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? activeColor : inactiveColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? activeColor : inactiveColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Theme Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Consumer<ThemeService>(builder: (context, theme, _) {
              final isDark = theme.themeMode == ThemeMode.dark;
              final toggleBg =
                  Colors.white.withOpacity(0.05); // Always dark translucent
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: toggleBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ThemeToggleItem(
                      icon: Icons.light_mode_outlined,
                      label: "Light",
                      isActive: !isDark,
                      onTap: () => theme.toggleTheme(false),
                    ),
                    _ThemeToggleItem(
                      icon: Icons.dark_mode_outlined,
                      label: "Dark",
                      isActive: isDark,
                      onTap: () => theme.toggleTheme(true),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ThemeToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeToggleItem(
      {required this.icon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.4)),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  final IconData icon;
  final String label;
  final String uid;
  const SidebarItem(
      {required this.icon, required this.label, required this.uid});
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String change;
  final bool isPositive;
  final BoxDecoration? cardDecoration;

  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.change = "+0.0%",
    this.isPositive = true,
    this.cardDecoration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = cardDecoration ??
        BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? null
              : Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                _BuildStatChange(change: change, isPositive: isPositive),
              ],
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildStatChange extends StatelessWidget {
  final String change;
  final bool isPositive;

  const _BuildStatChange({required this.change, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isPositive ? AppColors.success : AppColors.danger)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPositive ? Icons.trending_up : Icons.trending_down,
              color: isPositive ? AppColors.success : AppColors.danger,
              size: 12),
          const SizedBox(width: 4),
          Text(
            change,
            style: TextStyle(
                color: isPositive ? AppColors.success : AppColors.danger,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class CoreInventoryDataTable extends StatelessWidget {
  final List<String> columns;
  final List<DataRow> rows;

  const CoreInventoryDataTable(
      {super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
          dataRowHeight: 64,
          headingRowHeight: 56,
          horizontalMargin: 24,
          columnSpacing: 32,
          columns: columns
              .map((c) => DataColumn(
                  label: Text(c,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5))))
              .toList(),
          rows: rows,
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const DashboardCard({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = height ?? 380.0;
    
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: padding ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: child,
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 1.6,
          children: List.generate(4, (i) => _item()),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(flex: 3, child: _item(height: 300)),
            const SizedBox(width: 32),
            Expanded(flex: 2, child: _item(height: 300)),
          ],
        ),
      ],
    );
  }

  Widget _item({double height = 100}) {
    return ShimmerLoading(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
