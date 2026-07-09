/// Resolves the plausibility script for a loaded schema, re-reading the source
/// when the script was absent at load time.
///
/// Background (TFM-client-app#441): the form used to decide "does this schema
/// ship plausibility?" from a single snapshot taken when the schema was first
/// loaded. But the synced `schemas` row can arrive before its
/// `plausability_script` column does, so that snapshot could be `null` for a
/// schema that DOES ship plausibility — leaving the plausibility engine
/// permanently reported as "unavailable" until a full re-sync. This resolver
/// re-reads the live source on demand instead, and caches the first non-empty
/// result so the hot validation path only hits the source on the recovery
/// attempt (not on every pass).
///
/// The source is injected as [_fetch] (`schemaId -> script?`) so the decision
/// logic is testable without a PowerSync database. In the app the fetch reads
/// `SchemaRepository.getById(id).plausabilityScript`.
class PlausibilityScriptResolver {
  PlausibilityScriptResolver(this._fetch, {String? initialScript})
      : _cached = (initialScript != null && initialScript.isNotEmpty) ? initialScript : null;

  final Future<String?> Function(String schemaId) _fetch;
  String? _cached;

  /// The plausibility script once it has been resolved, else null.
  String? get script => _cached;

  /// True once a non-empty script has been resolved — i.e. this schema is known
  /// to ship plausibility checks. Drives whether an "engine unavailable" marker
  /// is a real outage (true) or should be suppressed as a no-plausibility schema
  /// (false).
  bool get resolved => _cached != null;

  /// Returns the plausibility script, fetching it from the source when it wasn't
  /// present at load. Returns null only when the schema genuinely ships no
  /// script. Caches the first non-empty result.
  Future<String?> ensure(String? schemaId) async {
    if (_cached != null) return _cached;
    if (schemaId == null) return null;
    final code = await _fetch(schemaId);
    if (code != null && code.isNotEmpty) {
      _cached = code;
    }
    return code;
  }
}
