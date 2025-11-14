import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing the selected organization ID
/// Persists across app restarts until user selects a different organization or logs out
class OrganizationSelectionService {
  static const String _selectedOrgKey = 'selected_organization_id';

  // Singleton pattern
  static final OrganizationSelectionService _instance = OrganizationSelectionService._internal();
  factory OrganizationSelectionService() => _instance;
  OrganizationSelectionService._internal();

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
}
