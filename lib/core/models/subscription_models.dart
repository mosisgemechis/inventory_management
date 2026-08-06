import 'dart:convert';

enum SubscriptionPlan { starter, business, enterprise, trial, free, none }

enum SubscriptionAddOn {
  fefoBatchTracking,
  expiryTracking,
  advancedReports,
  analyticsDashboard,
  auditLogs,
  extraUser,
  extraBranch,
  advancedAnalyticsPack,
  auditLogsPack,
  prioritySupport
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get name {
    switch (this) {
      case SubscriptionPlan.starter:
        return "Starter";
      case SubscriptionPlan.business:
        return "Business";
      case SubscriptionPlan.enterprise:
        return "Enterprise";
      case SubscriptionPlan.trial:
        return "Trial";
      case SubscriptionPlan.free:
        return "Free";
      default:
        return "None";
    }
  }

  double get price {
    switch (this) {
      case SubscriptionPlan.starter:
        return 15;
      case SubscriptionPlan.business:
        return 25;
      case SubscriptionPlan.enterprise:
        return 35;
      case SubscriptionPlan.trial:
        return 0;
      case SubscriptionPlan.free:
        return 0;
      default:
        return 0;
    }
  }
}

extension SubscriptionAddOnExtension on SubscriptionAddOn {
  String get name {
    switch (this) {
      case SubscriptionAddOn.fefoBatchTracking:
        return "FEFO + Batch Tracking";
      case SubscriptionAddOn.expiryTracking:
        return "Expiry Tracking";
      case SubscriptionAddOn.advancedReports:
        return "Advanced Reports";
      case SubscriptionAddOn.analyticsDashboard:
        return "Analytics Dashboard";
      case SubscriptionAddOn.auditLogs:
        return "Audit Logs";
      case SubscriptionAddOn.extraUser:
        return "Extra User";
      case SubscriptionAddOn.extraBranch:
        return "Extra Branch";
      case SubscriptionAddOn.advancedAnalyticsPack:
        return "Advanced Analytics Pack";
      case SubscriptionAddOn.auditLogsPack:
        return "Audit Logs Pack";
      case SubscriptionAddOn.prioritySupport:
        return "Priority Support";
    }
  }

  double getPrice(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        switch (this) {
          case SubscriptionAddOn.fefoBatchTracking:
            return 5;
          case SubscriptionAddOn.expiryTracking:
            return 3;
          case SubscriptionAddOn.advancedReports:
            return 4;
          case SubscriptionAddOn.analyticsDashboard:
            return 4;
          case SubscriptionAddOn.auditLogs:
            return 3;
          case SubscriptionAddOn.extraUser:
            return 2;
          case SubscriptionAddOn.extraBranch:
            return 5;
          default:
            return 0;
        }
      case SubscriptionPlan.business:
        switch (this) {
          case SubscriptionAddOn.extraUser:
            return 1;
          case SubscriptionAddOn.extraBranch:
            return 2;
          case SubscriptionAddOn.advancedAnalyticsPack:
            return 2;
          case SubscriptionAddOn.auditLogsPack:
            return 1;
          default:
            return 0;
        }
      case SubscriptionPlan.enterprise:
        switch (this) {
          case SubscriptionAddOn.extraUser:
            return 1;
          case SubscriptionAddOn.extraBranch:
            return 2;
          case SubscriptionAddOn.advancedAnalyticsPack:
            return 2;
          case SubscriptionAddOn.auditLogsPack:
            return 1;
          default:
            return 0;
        }
      default:
        return 0;
    }
  }
}

enum Feature {
  inventoryManagement,
  bulkImport,
  posBilling,
  barcodeScanning,
  salesTracking,
  profitTracking,
  basicReports,
  debtManagement,
  lowStockAlerts,
  multiDeviceSync,
  offlineSync,
  fefoTracking,
  expiryTracking,
  advancedReports,
  analyticsDashboard,
  auditLogs,
  purchaseTracking,
  customPermissions,
  centralDashboard,
  branchAnalytics,
  advancedMonitoring,
  prioritySync,
  multiBranchManagement,
  staffManagement,
  shopSettings,
}

class ActiveSubscription {
  final String shopId;
  final SubscriptionPlan plan;
  final DateTime activationDate;
  final DateTime expiryDate;
  final List<SubscriptionAddOn> addOns;
  final bool isTrial;
  final int userLimit;
  final int branchLimit;

  ActiveSubscription({
    required this.shopId,
    required this.plan,
    required this.activationDate,
    required this.expiryDate,
    required this.addOns,
    required this.isTrial,
    required this.userLimit,
    required this.branchLimit,
  });

  bool get isExpired {
    return DateTime.now().isAfter(expiryDate);
  }

  Duration get remainingTime {
    final diff = expiryDate.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool hasFeature(Feature feature, {bool ignoreExpiry = false}) {
    if (!ignoreExpiry && isExpired) return false;

    // Feature gating based on Plan + Add-ons
    final planFeatures = _getPlanFeatures(plan);
    if (planFeatures.contains(feature)) return true;

    // Check Add-ons
    for (var addon in addOns) {
      if (_getAddOnFeatures(addon).contains(feature)) return true;
    }

    return false;
  }

  static List<Feature> _getPlanFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
      case SubscriptionPlan.trial:
        return [
          Feature.inventoryManagement,
          Feature.bulkImport,
          Feature.posBilling,
          Feature.barcodeScanning,
          Feature.salesTracking,
          Feature.profitTracking,
          Feature.basicReports,
          Feature.debtManagement,
          Feature.lowStockAlerts,
          Feature.multiDeviceSync,
          Feature.offlineSync,
          Feature.shopSettings,
          Feature.staffManagement,
        ];
      case SubscriptionPlan.business:
        return [
          ..._getPlanFeatures(SubscriptionPlan.starter),
          Feature.fefoTracking,
          Feature.expiryTracking,
          Feature.purchaseTracking,
          Feature.advancedReports,
          Feature.analyticsDashboard,
          Feature.customPermissions,
          Feature.multiBranchManagement,
        ];
      case SubscriptionPlan.enterprise:
        return [
          ..._getPlanFeatures(SubscriptionPlan.business),
          Feature.centralDashboard,
          Feature.branchAnalytics,
          Feature.prioritySync,
          Feature.advancedMonitoring,
        ];
      case SubscriptionPlan.free:
      case SubscriptionPlan.none:
        return [];
    }
  }

  static List<Feature> _getAddOnFeatures(SubscriptionAddOn addon) {
    switch (addon) {
      case SubscriptionAddOn.fefoBatchTracking:
        return [Feature.fefoTracking];
      case SubscriptionAddOn.expiryTracking:
        return [Feature.expiryTracking];
      case SubscriptionAddOn.advancedReports:
        return [Feature.advancedReports];
      case SubscriptionAddOn.analyticsDashboard:
      case SubscriptionAddOn.advancedAnalyticsPack:
        return [Feature.analyticsDashboard];
      case SubscriptionAddOn.auditLogs:
      case SubscriptionAddOn.auditLogsPack:
        return [Feature.auditLogs];
      case SubscriptionAddOn.extraBranch:
        return [Feature.multiBranchManagement];
      default:
        return [];
    }
  }

  factory ActiveSubscription.fromMap(Map<String, dynamic> map) {
    return ActiveSubscription(
      shopId: map['shopId'],
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.name.toLowerCase() == map['plan'].toString().toLowerCase(),
        orElse: () => SubscriptionPlan.none,
      ),
      activationDate: DateTime.parse(map['activationDate']),
      expiryDate: DateTime.parse(map['expiryDate']),
      addOns: (jsonDecode(map['addOns'] ?? '[]') as List)
          .map((e) => SubscriptionAddOn.values.firstWhere((f) => f.name == e))
          .toList(),
      isTrial: map['isTrial'] == true || map['isTrial'] == 1,
      userLimit: map['userLimit'] ?? 3,
      branchLimit: map['branchLimit'] ?? 1,
    );
  }
}
