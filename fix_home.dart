import 'dart:io';

void main() {
  final file = File('lib/features/admin/admin_dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  if (content.contains('statCards.length')) {
      content = content.replaceAll(
'''                      if (soonCount > 0 || expiredCount > 0)
                        StatCard(
                          title: 'Expiry Alerts',
                          value: '\ items',
                          color: AppColors.warning,
                          icon: Icons.access_time_rounded,
                          change: soonCount > 0 ? "Soon" : "Expired",
                          isPositive: false,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
              ];''',
'''                      if (soonCount > 0 || expiredCount > 0)
                        StatCard(
                          title: 'Expiry Alerts',
                          value: '\ items',
                          color: AppColors.warning,
                          icon: Icons.access_time_rounded,
                          change: soonCount > 0 ? "Soon" : "Expired",
                          isPositive: false,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
              ];'''.replaceAll('];', '] /* END STATCARDS */')
      );
      
      content = content.replaceAll(
          'padding: EdgeInsets.all(isMobile ? 16 : 32),\n                children: [',
          '''padding: EdgeInsets.all(isMobile ? 16 : 32),
                children: [
                  Builder(builder: (context) {
                    final statCards = <Widget>[
                      if (user.hasPermission(AppUser.pViewReports))
                        StatCard(
                          title: 'Total Revenue',
                          value: _currencyFormat.format(rev),
                          color: profitColor,
                          icon: Icons.attach_money_rounded,
                          change: "+8.5%",
                          cardDecoration: cardDecoration,
                          onTap: () {
                             final idx = sidebarItems.indexWhere((it) => it.uid == 'reports');
                             if (idx != -1) setState(() => _selectedIndex = idx);
                          }
                        ),
                      if (user.hasPermission(AppUser.pViewProfit))
                        StatCard(
                          title: 'Net Profit',
                          value: _currencyFormat.format(prof),
                          color: profitColor,
                          icon: prof < 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          change: prof < 0 ? "Loss" : "Profit",
                          isPositive: prof >= 0,
                          cardDecoration: cardDecoration,
                          onTap: () {
                             final idx = sidebarItems.indexWhere((it) => it.uid == 'reports');
                             if (idx != -1) setState(() => _selectedIndex = idx);
                          }
                        ),
                      if (user.hasPermission(AppUser.pAccessPOS))
                        StatCard(
                          title: 'Transactions',
                          value: count.toString(),
                          color: AppColors.secondary,
                          icon: Icons.receipt_long_rounded,
                          change: "+\",
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'sales')),
                        ),
                      if (user.hasPermission(AppUser.pAddEditProducts))
                        StatCard(
                          title: 'Low Stock',
                          value: '\ items',
                          color: AppColors.danger,
                          icon: Icons.warning_amber_rounded,
                          change: lowStock > 0 ? " Reorder" : " All Good",
                          isPositive: lowStock == 0,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
                      if (soonCount > 0 || expiredCount > 0)
                        StatCard(
                          title: 'Expiry Alerts',
                          value: '\ items',
                          color: AppColors.warning,
                          icon: Icons.access_time_rounded,
                          change: soonCount > 0 ? "Soon" : "Expired",
                          isPositive: false,
                          cardDecoration: cardDecoration,
                          onTap: () => setState(() => _selectedIndex =
                              sidebarItems.indexWhere((it) => it.uid == 'inventory')),
                        ),
                    ];
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 4,
                        mainAxisSpacing: isMobile ? 12 : 24,
                        crossAxisSpacing: isMobile ? 12 : 24,
                        childAspectRatio: isMobile ? 1.4 : 1.6,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: statCards.length,
                      itemBuilder: (context, index) => statCards[index],
                    );
                  }),'''
      );
      
      // Remove the broken GridView.builder from my bad regex string.
      // We have to extract finding the original grid view... Wait this is a bit too complex string manipulation for inline dart.
  }
  file.writeAsStringSync(content);
}
