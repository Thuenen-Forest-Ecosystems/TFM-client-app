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

  /// Check if an organization is currently selected
  Future<bool> hasSelectedOrganization() async {
    final orgId = await getSelectedOrganizationId();
    return orgId != null && orgId.isNotEmpty;
  }

  /// Set the selected permission ID
  Future<bool> setSelectedPermissionId(String permissionId) async {
    final prefs = await SharedPreferences.getInstance();
    print('OrganizationSelectionService: Saving selected permission: $permissionId');
    final result = await prefs.setString('selected_permission_id', permissionId);
    if (result) {
      _notifyPermissionChange(permissionId);
    }
    return result;
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
