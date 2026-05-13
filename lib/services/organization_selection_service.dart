import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the selected organization ID
/// Persists across app restarts until user selects a different organization or logs out
class OrganizationSelectionService {
  static const String _selectedOrgKey = 'selected_organization_id';

  // Singleton pattern
  static final OrganizationSelectionService _instance = OrganizationSelectionService._internal();
  factory OrganizationSelectionService() => _instance;
  OrganizationSelectionService._internal();

  // Listeners for permission changes
  final List<Function(String permissionId)> _permissionChangeListeners = [];

  /// Register a listener for permission changes
  void addPermissionChangeListener(Function(String permissionId) listener) {
    _permissionChangeListeners.add(listener);
  }

  /// Remove a listener
  void removePermissionChangeListener(Function(String permissionId) listener) {
    _permissionChangeListeners.remove(listener);
  }

  /// Notify all listeners about permission change
  void _notifyPermissionChange(String permissionId) {
    for (final listener in _permissionChangeListeners) {
      listener(permissionId);
    }
  }

  /// Get the currently selected organization ID
  Future<String?> getSelectedOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedOrgKey);
  }

  /// Set the selected organization ID
  Future<bool> setSelectedOrganizationId(String organizationId) async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Saving selected organization: $organizationId');
    return prefs.setString(_selectedOrgKey, organizationId);
  }

  /// Clear the selected organization (e.g., on logout)
  Future<bool> clearSelectedOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Clearing selected organization');
    return prefs.remove(_selectedOrgKey);
  }

  /// Clear ALL selection preferences (org, permission, troop, admin flag).
  /// Must be called on logout so the next user starts with a clean slate.
  Future<void> clearAllSelections() async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Clearing all selections on logout');
    await prefs.remove(_selectedOrgKey);
    await prefs.remove('selected_permission_id');
    await prefs.remove('selected_troop_id');
    await prefs.remove('selected_troop_name');
    await prefs.remove('is_organization_admin');
  }

  /// Check if an organization is currently selected
  Future<bool> hasSelectedOrganization() async {
    final orgId = await getSelectedOrganizationId();
    return orgId != null && orgId.isNotEmpty;
  }

  /// Set the selected permission ID.
  /// Does NOT fire [_notifyPermissionChange] — call [notifyPermissionSelected]
  /// after all related settings (orgId, troopId, isAdmin) have been saved so
  /// that listeners see a consistent state.
  Future<bool> setSelectedPermissionId(String permissionId) async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Saving selected permission: $permissionId');
    return prefs.setString('selected_permission_id', permissionId);
  }

  /// Fire the permission-changed notification.  Call this once ALL related
  /// preferences (org, troop, isAdmin) have been persisted.
  void notifyPermissionSelected(String permissionId) {
    _notifyPermissionChange(permissionId);
  }

  /// Get the currently selected permission ID
  Future<String?> getSelectedPermissionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_permission_id');
  }

  /// Clear the selected permission
  Future<bool> clearSelectedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Clearing selected permission');
    return prefs.remove('selected_permission_id');
  }

  /// Set the selected troop ID
  Future<bool> setSelectedTroopId(String? troopId) async {
    final prefs = await SharedPreferences.getInstance();
    if (troopId == null) {
      return prefs.remove('selected_troop_id');
    }
    print('OrganizationSelectionService: Saving selected troop: $troopId');
    return prefs.setString('selected_troop_id', troopId);
  }

  /// Get the currently selected troop ID
  Future<String?> getSelectedTroopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_troop_id');
  }

  /// Set the selected troop name
  Future<bool> setSelectedTroopName(String? troopName) async {
    final prefs = await SharedPreferences.getInstance();
    if (troopName == null) {
      return prefs.remove('selected_troop_name');
    }
    return prefs.setString('selected_troop_name', troopName);
  }

  /// Get the currently selected troop name
  Future<String?> getSelectedTroopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_troop_name');
  }

  /// Set whether the selected permission is organization admin
  Future<bool> setIsOrganizationAdmin(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Saving is_organization_admin: $isAdmin');
    return prefs.setBool('is_organization_admin', isAdmin);
  }

  /// Get whether the selected permission is organization admin
  Future<bool> getIsOrganizationAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_organization_admin') ?? false;
  }
}
