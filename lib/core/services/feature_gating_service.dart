import '../models/subscription_models.dart';
import 'subscription_service.dart';

/// SUBSCRIPTION ENFORCEMENT IS CURRENTLY DISABLED FOR TESTING.
/// All feature checks return true and isReadOnly() returns false
/// so the full app version is accessible.
/// To re-enable, remove the overrides below and uncomment the real logic.
class FeatureGatingService {

  // ── TESTING OVERRIDES ──────────────────────────────────────────────────────
  // Set to false to re-enable real subscription enforcement.
  static const bool _subscriptionDisabled = true;

  static bool hasFeature(Feature feature) {
    if (_subscriptionDisabled) return true; // << TESTING: always granted
    final sub = subscriptionService.current;
    if (sub == null) return false;
    return sub.hasFeature(feature, ignoreExpiry: true);
  }

  static bool hasAddon(SubscriptionAddOn addon) {
    if (_subscriptionDisabled) return true;
    final sub = subscriptionService.current;
    if (sub == null) return false;
    return sub.addOns.contains(addon.name);
  }

  static bool isReadOnly() {
    if (_subscriptionDisabled) return false; // << TESTING: never read-only
    if (subscriptionService.isInitializing) return false;
    final sub = subscriptionService.current;
    if (sub == null) return true;
    return sub.isExpired;
  }

  static bool canAccess(Feature feature) {
    if (_subscriptionDisabled) return true;
    return !isReadOnly() && hasFeature(feature);
  }

  static int maxUsers() {
    if (_subscriptionDisabled) return 9999;
    final sub = subscriptionService.current;
    return sub?.userLimit ?? 3;
  }

  static int maxBranches() {
    if (_subscriptionDisabled) return 9999;
    final sub = subscriptionService.current;
    return sub?.branchLimit ?? 1;
  }

  // ── WRITE GUARDS ───────────────────────────────────────────────────────────
  static bool canSell() => !isReadOnly() && hasFeature(Feature.posBilling);
  static bool canAddInventory() => !isReadOnly() && hasFeature(Feature.inventoryManagement);
  static bool canEditProducts() => !isReadOnly() && hasFeature(Feature.inventoryManagement);
  static bool canDeleteProducts() => !isReadOnly() && hasFeature(Feature.inventoryManagement);
  static bool canAddPurchases() => !isReadOnly() && hasFeature(Feature.purchaseTracking);
  static bool canAdjustStock() => !isReadOnly() && hasFeature(Feature.inventoryManagement);
  static bool canTransferStock() => !isReadOnly() && hasFeature(Feature.multiBranchManagement);
  static bool canManageBranches() => !isReadOnly() && hasFeature(Feature.multiBranchManagement);
  static bool canViewAdvancedReports() => hasFeature(Feature.advancedReports);
  static bool canEditUsers() => !isReadOnly() && hasFeature(Feature.staffManagement);
  static bool canAddUsers() => !isReadOnly() && hasFeature(Feature.staffManagement);
  static bool canCustomizeRoles() => !isReadOnly() && hasFeature(Feature.customPermissions);
  static bool canManageShop() => !isReadOnly() && hasFeature(Feature.shopSettings);
  static bool canCollectDebt() => !isReadOnly() && hasFeature(Feature.debtManagement);
}
