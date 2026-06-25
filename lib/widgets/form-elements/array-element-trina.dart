import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:terrestrial_forest_monitor/services/lookup_service.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';
import 'package:terrestrial_forest_monitor/services/grid_density_service.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-textfield.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-grid-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-row-form-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-filter-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/validation_status_indicator.dart';

/// ArrayElementTrina - TrinaGrid-based array data editor widget
///
/// Features:
/// - Schema-driven column generation with sortBy support
/// - Type-aware column rendering (Text, Number, Boolean, Select/Enum)
/// - Automatic type conversion and formatting
/// - Unit display from schema ($tfm.unit_short)
/// - German enum labels support ($tfm.name_de)
/// - Inline editing with proper type handling
/// - Add/delete row operations
/// - FAB for adding new rows
///
/// Similar functionality to ArrayElementSyncfusion but using TrinaGrid library
class ArrayElementTrina extends StatefulWidget {
  final Map<String, dynamic> jsonSchema;
  final List<dynamic>? data;
  final TFMValidationResult? validationResult;
  final String? propertyName;
  final Function(List<dynamic>?)? onDataChanged;

  /// Optional column styling configuration from layout (takes precedence over schema $tfm.form)
  final Map<String, dynamic>? columnConfig;

  /// Optional column items array from layout (new structure with groups)
  final List<dynamic>? columnItems;

  /// Optional layout options (e.g., fullSize, autoIncrement defaults)
  final Map<String, dynamic>? layoutOptions;

  /// Previous data array for calculated fields (same-index matching)
  final List<dynamic>? previousData;

  /// Optional identifier field for matching rows between current and previous data
  final String? identifierField;

  /// Optional filter configuration from layout
  final List<dynamic>? filterConfig;

  /// When true, the grid sizes its height to fit all rows (no internal vertical
  /// scrolling) and grows as rows are added, instead of filling its parent with
  /// [Expanded]. The parent must NOT impose a fixed height in this mode.
  final bool autoHeight;

  const ArrayElementTrina({
    super.key,
    required this.jsonSchema,
    required this.data,
    this.propertyName,
    this.validationResult,
    this.onDataChanged,
    this.columnConfig,
    this.columnItems,
    this.layoutOptions,
    this.previousData,
    this.identifierField,
    this.filterConfig,
    this.autoHeight = false,
  });

  @override
  State<ArrayElementTrina> createState() => ArrayElementTrinaState();
}

class ArrayElementTrinaState extends State<ArrayElementTrina> with AutomaticKeepAliveClientMixin {
  // Keep the grid alive when its tab is off-screen so sorting and scroll
  // position survive tab switches (TabBarView disposes inactive children).
  @override
  bool get wantKeepAlive => true;

  /// Auto-generated display columns whose cells are never part of the row data.
  static const Set<String> _internalColumnFields = {
    '__row_number__',
    '__row_menu__',
    '__validation_status__',
    '__row_drag__',
  };

  List<TrinaColumn> _columns = [];
  List<TrinaRow> _rows = [];
  List<TrinaColumnGroup> _columnGroups = [];
  TrinaGridStateManager? _stateManager;
  bool _isArrayReadOnly = false;
  DateTime? _lastSelectionTimestamp;
  MapControllerProvider? _mapControllerProvider;

  // Track sort states for each column to cycle through: none -> ascending -> descending -> none
  final Map<String, int> _columnSortStates = {}; // 0=none, 1=ascending, 2=descending

  // Store original column widths so we can scale up to fill available width
  final Map<String, double> _originalColumnWidths = {};

  // Filter support
  List<ArrayFilterRule> _filters = [];
  Set<int> _activeFilterIndices = {};
  bool _filtersLoaded = false;
  final Map<int, Map<String, dynamic>> _hiddenRowsByOriginalIndex = {};

  // Maps field name -> layout item config for calculated columns (used to pre-compute sortable cell values)
  final Map<String, Map<String, dynamic>> _calculatedColumnConfigs = {};

  // Track which column groups are currently collapsed (by group title)
  final Set<String> _collapsedGroups = {};

  // Persisted column widths
  Map<String, double> _savedColumnWidths = {};
  bool _savedWidthsLoaded = false;
  Map<String, double> _lastKnownWidths = {};
  Timer? _widthSaveTimer;

  bool get _isScrollable => widget.layoutOptions?['isScrollable'] != false;
  bool get _usesAutoHeight => widget.autoHeight || !_isScrollable;
  bool get _rowDragEnabled =>
      widget.layoutOptions?['isDraggable'] == true && _isScrollable && !_isArrayReadOnly;

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _initializeGrid();
    GridDensityService.notifier.addListener(_onDensityChanged);
    LookupService.versionNotifier.addListener(_onLookupReloaded);
    _loadColumnWidths();
  }

  void _onLookupReloaded() {
    // Only refresh cell renders — do NOT reinitialize the grid, as that would
    // reset scroll position and disrupt in-progress edits.
    _stateManager?.notifyListeners();
  }

  void _onDensityChanged() {
    if (mounted) setState(() {});
  }

  /// Load persisted column widths from SharedPreferences.
  /// Applies widths directly to column objects BEFORE the grid builds,
  /// then calls setState so the grid is built for the first time with
  /// the correct widths — no post-build corrections needed.
  Future<void> _loadColumnWidths() async {
    if (widget.propertyName != null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('col_widths_${widget.propertyName}');
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          _savedColumnWidths = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        } catch (_) {}
      }
      for (final col in _columns) {
        final saved = _savedColumnWidths[col.field];
        if (saved != null && saved > 0) col.width = saved;
      }
    }
    if (mounted) setState(() => _savedWidthsLoaded = true);
  }

  /// Called whenever the state manager notifies. Detects column width changes
  /// and debounces a save to SharedPreferences.
  void _onColumnWidthChanged() {
    if (_stateManager == null) return;
    bool changed = false;
    for (final col in _stateManager!.columns) {
      if ((_lastKnownWidths[col.field] ?? -1.0) != col.width) {
        changed = true;
        break;
      }
    }
    if (!changed) return;
    for (final col in _stateManager!.columns) {
      _lastKnownWidths[col.field] = col.width;
      // Immediately update the in-memory cache so _adjustColumnsToFitWidth
      // returns early on the very next build, preserving the user's resize.
      // Without this, the 600ms debounce window leaves _savedColumnWidths stale
      // and _adjustColumnsToFitWidth overwrites the user's new width.
      if (!col.field.startsWith('__')) {
        _savedColumnWidths[col.field] = col.width;
        _originalColumnWidths[col.field] = col.width;
      }
    }
    _widthSaveTimer?.cancel();
    _widthSaveTimer = Timer(const Duration(milliseconds: 600), _saveColumnWidths);
  }

  /// Persist the in-memory _savedColumnWidths to SharedPreferences.
  /// In-memory cache is already up-to-date (written in _onColumnWidthChanged)
  /// so we just flush it to disk here.
  Future<void> _saveColumnWidths() async {
    if (widget.propertyName == null || _savedColumnWidths.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('col_widths_${widget.propertyName}', jsonEncode(_savedColumnWidths));
  }

  void _initializeFilters() {
    // Parse filter configuration from layout

    if (widget.filterConfig != null && widget.filterConfig!.isNotEmpty) {
      _filters = widget.filterConfig!
          .map((config) => ArrayFilterRule.fromJson(config as Map<String, dynamic>))
          .toList();

      // Set default active filters
      _activeFilterIndices.clear();
      for (int i = 0; i < _filters.length; i++) {
        if (_filters[i].defaultActive) {
          _activeFilterIndices.add(i);
        }
      }

      // Load saved filter state asynchronously
      _loadFilterState();
    }
  }

  Future<void> _loadFilterState() async {
    if (widget.propertyName == null || _filters.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'array_filter_${widget.propertyName}';
      final savedIndices = prefs.getStringList(key);

      if (savedIndices != null) {
        if (!mounted) return;
        setState(() {
          _activeFilterIndices = savedIndices.map((s) => int.parse(s)).toSet();
          _filtersLoaded = true;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _filtersLoaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filtersLoaded = true;
      });
    }
  }

  Future<void> _saveFilterState() async {
    if (widget.propertyName == null || _filters.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'array_filter_${widget.propertyName}';
      await prefs.setStringList(key, _activeFilterIndices.map((i) => i.toString()).toList());
    } catch (e) {}
  }

  Future<void> _showFilterDialog() async {
    if (_filters.isEmpty) return;

    await ArrayFilterDialog.show(
      context: context,
      filters: _filters,
      activeFilterIndices: _activeFilterIndices,
      onChanged: (newIndices) {
        if (!mounted) return;
        setState(() {
          _activeFilterIndices = newIndices;
          _rows = _buildRows();
          _stateManager?.removeAllRows();
          _stateManager?.appendRows(_rows);
        });
        _saveFilterState();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up listener for MapControllerProvider if not already done
    if (_mapControllerProvider == null) {
      try {
        _mapControllerProvider = context.read<MapControllerProvider>();
        _mapControllerProvider!.addListener(_onMapControllerChanged);
      } catch (e) {}
    }
  }

  void _onMapControllerChanged() {
    if (!mounted) return;

    try {
      final selectedArrayName = _mapControllerProvider?.selectedArrayName;
      final selectedIdentifier = _mapControllerProvider?.selectedRowIdentifier;
      final selectionTimestamp = _mapControllerProvider?.selectionTimestamp;

      // Check if selection is for this grid and hasn't been processed yet
      if (selectedArrayName == widget.propertyName &&
          selectedIdentifier != null &&
          selectionTimestamp != null &&
          selectionTimestamp != _lastSelectionTimestamp) {
        _lastSelectionTimestamp = selectionTimestamp;

        // Open form dialog for the matching row
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            openRowFormByIdentifier(selectedIdentifier);
            // Clear the selection request after processing
            _mapControllerProvider?.clearGridRowSelection();
          }
        });
      }
    } catch (e) {}
  }

  void _scrollToAndSelectRow(dynamic identifier) {
    final stateManager = _stateManager;
    if (stateManager == null || widget.data == null) return;

    final identifierField = widget.identifierField ?? 'tree_number';

    // Find the row index with matching identifier
    int? matchingRowIndex;
    for (int i = 0; i < widget.data!.length; i++) {
      final rowData = widget.data![i];
      if (rowData is Map<String, dynamic> && rowData[identifierField] == identifier) {
        matchingRowIndex = i;
        break;
      }
    }

    if (matchingRowIndex == null) {
      return;
    }

    if (matchingRowIndex < 0 || matchingRowIndex >= stateManager.rows.length) {
      return;
    }

    // Select the row in the grid
    try {
      final targetRow = stateManager.rows[matchingRowIndex];
      if (targetRow.cells.isEmpty) return;
      stateManager.setCurrentCell(targetRow.cells.entries.first.value, matchingRowIndex);
      stateManager.setKeepFocus(true);
    } catch (e) {}
  }

  /// Open the form dialog for a row identified by its identifier value (e.g. tree_number)
  void openRowFormByIdentifier(dynamic identifier) {
    final identifierField = widget.identifierField ?? 'tree_number';
    final rows = _stateManager?.rows ?? _rows;

    // Find the row index in the grid rows by matching the identifier field
    int? matchingRowIndex;
    for (int i = 0; i < rows.length; i++) {
      final cellValue = rows[i].cells[identifierField]?.value;
      if (cellValue == identifier) {
        matchingRowIndex = i;
        break;
      }
    }

    if (matchingRowIndex == null) {
      return;
    }

    _editRowAsFormDialog(matchingRowIndex);
  }

  @override
  void didUpdateWidget(ArrayElementTrina oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if schema changes or data changes
    bool shouldRebuild = false;

    if (widget.jsonSchema != oldWidget.jsonSchema) {
      // Debug: Check if readonly status changed in schema
      final oldItems = oldWidget.jsonSchema['items'] as Map<String, dynamic>?;
      final newItems = widget.jsonSchema['items'] as Map<String, dynamic>?;
      final oldProps = oldItems?['properties'] as Map<String, dynamic>?;
      final newProps = newItems?['properties'] as Map<String, dynamic>?;

      if (oldProps != null && newProps != null) {
        newProps.forEach((key, value) {
          final oldReadOnly = oldProps[key]?['readOnly'];
          final newReadOnly = value['readOnly'];
          if (oldReadOnly != newReadOnly) {}
        });
      }

      shouldRebuild = true;
    }

    // Check if data has changed
    if (widget.data != oldWidget.data) {
      shouldRebuild = true;
    }

    if (shouldRebuild) {
      _initializeGrid();
    }

    // If validation result changes, force grid to rebuild cells
    if (widget.validationResult != oldWidget.validationResult) {
      _stateManager?.notifyListeners();
    }
  }

  void _initializeGrid() {
    // Check if the entire array is readonly (support both 'readOnly' and 'readonly')
    _isArrayReadOnly =
        widget.jsonSchema['readOnly'] as bool? ?? widget.jsonSchema['readonly'] as bool? ?? false;
    if (_isArrayReadOnly) {}

    _calculatedColumnConfigs.clear();
    _columns = _buildColumns();
    _originalColumnWidths.clear();
    for (final col in _columns) {
      _originalColumnWidths[col.field] = col.width;
    }
    _columnGroups = _buildColumnGroups();
    _rows = _buildRows();
  }

  /// Scale non-frozen column widths so the total fills at least [availableWidth].
  /// Frozen columns keep their current size (which may have been resized by the
  /// user); only the scrollable body columns are proportionally widened when
  /// their total is narrower than the viewport.
  void _adjustColumnsToFitWidth(double availableWidth) {
    if (_columns.isEmpty || availableWidth <= 0) return;
    // Skip auto-fit when the user has explicitly saved column widths.
    // Their saved widths take precedence; the grid will scroll horizontally if needed.
    if (_savedWidthsLoaded && _savedColumnWidths.isNotEmpty) return;

    double frozenWidth = 0;
    double nonFrozenOriginalWidth = 0;

    for (final col in _columns) {
      if (col.frozen != TrinaColumnFrozen.none) {
        // Use current width for frozen columns (may have been resized by user)
        frozenWidth += col.width;
      } else {
        nonFrozenOriginalWidth += _originalColumnWidths[col.field] ?? col.width;
      }
    }

    final availableForNonFrozen = availableWidth - frozenWidth;

    if (nonFrozenOriginalWidth > 0 && nonFrozenOriginalWidth < availableForNonFrozen) {
      // Scale up non-frozen columns to fill available width
      final scale = availableForNonFrozen / nonFrozenOriginalWidth;
      for (final col in _columns) {
        if (col.frozen == TrinaColumnFrozen.none) {
          col.width = (_originalColumnWidths[col.field] ?? col.width) * scale;
        }
      }
    } else {
      // Restore original widths for non-frozen columns only;
      // frozen columns keep their current (possibly user-resized) width.
      for (final col in _columns) {
        if (col.frozen == TrinaColumnFrozen.none) {
          final original = _originalColumnWidths[col.field];
          if (original != null) col.width = original;
        }
      }
    }
  }

  /// Get column configuration for a field (layout takes precedence over schema)
  Map<String, dynamic> _getColumnConfig(String fieldKey, Map<String, dynamic> propertySchema) {
    final config = <String, dynamic>{};

    // First, check layout column config
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      final layoutConfig = widget.columnConfig![fieldKey] as Map<String, dynamic>;

      // Layout properties
      config['pinned'] = layoutConfig['pinned'];
      config['width'] = layoutConfig['width'];
      config['display'] = layoutConfig['display'] ?? true;
      config['autoIncrement'] = layoutConfig['autoIncrement'];
      config['groupBy'] = layoutConfig['groupBy'];
      config['readonly'] = layoutConfig['readonly'];
      config['title'] = layoutConfig['title'];
    }

    // Fallback to schema $tfm.form if layout config not provided
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final form = tfm?['form'] as Map<String, dynamic>?;
    final uiOptions = form?['ui:options'] as Map<String, dynamic>?;

    config['pinned'] ??= uiOptions?['pinned'];
    config['width'] ??= uiOptions?['width'];
    config['display'] ??= uiOptions?['display'] ?? true;
    config['autoIncrement'] ??= form?['autoIncrement'];
    config['groupBy'] ??= form?['groupBy'];
    config['readonly'] ??= propertySchema['readOnly'] ?? propertySchema['readonly'];

    return config;
  }

  /// Check if a specific cell has validation errors
  /// Uses original data index from row cells to ensure errors stay with correct rows after sorting
  bool _hasValidationError(TrinaRow row, String fieldKey) {
    if (widget.validationResult == null || widget.propertyName == null) {
      return false;
    }

    // Use the original data index stored in the row so validation errors
    // stay attached to the correct row even after sorting/reordering.
    final originalIndex = row.cells['__original_index__']?.value as int?;
    if (originalIndex == null) return false;

    // Only match field-specific errors like: "/propertyName/0/fieldKey"
    // Row-level errors ("/propertyName/0") should NOT cascade to individual cells
    final cellPath = '/${widget.propertyName}/$originalIndex/$fieldKey';

    // Check AJV validation errors
    final ajvErrors = widget.validationResult!.ajvErrors;
    if (ajvErrors.any((error) => error.instancePath == cellPath)) {
      return true;
    }

    // Check TFM plausibility errors
    final tfmErrors = widget.validationResult!.tfmErrors;
    return tfmErrors.any((error) => error.instancePath == cellPath);
  }

  /// Get background color for cell based on validation state or readonly status
  Color? _getCellBackgroundColor(
    TrinaRow row,
    String fieldKey,
    bool isDark, {
    bool isReadOnly = false,
  }) {
    if (_hasValidationError(row, fieldKey)) {
      return isDark ? const Color.fromARGB(137, 90, 31, 31) : const Color(0xFFFFCDD2); // Light red
    }
    if (isReadOnly) {
      return isDark ? Colors.grey.withAlpha(30) : Colors.grey.withAlpha(25);
    }
    return null;
  }

  /// Evaluate a calculated column's expression to get a sortable/storable value.
  /// Only handles expression-based calculated fields (not calculatedFunction).
  /// Returns a numeric value if the expression resolves to a number, otherwise a string.
  dynamic _resolveCalculatedValue(
    Map<String, dynamic> config,
    Map<String, dynamic> currentRowData,
    Map<String, dynamic>? previousRowData,
  ) {
    final expression = config['expression'] as String?;
    if (expression == null || expression.isEmpty) return null;

    final variables = config['variables'] as List?;
    if (variables == null || variables.isEmpty) return null;

    String processedExpression = expression;
    for (final variable in variables) {
      if (variable is! Map<String, dynamic>) continue;
      final varName = variable['name'] as String?;
      final source = variable['source'] as String?;
      if (varName == null || source == null) continue;

      final dataSource = source == 'previousData' ? previousRowData : currentRowData;
      if (dataSource == null) {
        processedExpression = processedExpression.replaceAll(RegExp('\\b$varName\\b'), '0');
        continue;
      }

      final fieldKey = varName.startsWith('previous_') ? varName.substring(9) : varName;
      final value = dataSource[fieldKey];
      final numVal = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
      processedExpression = processedExpression.replaceAll(
        RegExp('\\b$varName\\b'),
        (numVal ?? 0.0).toString(),
      );
    }

    return double.tryParse(processedExpression.trim());
  }

  /// Check if current row has matching data in previous inventory (by identifier)
  bool _hasMatchingPreviousData(Map<String, dynamic> currentRowData) {
    if (widget.previousData == null) return false;

    if (widget.identifierField == null) {}

    // Use configured identifier field or fall back to common fields
    final identifierFields = widget.identifierField != null
        ? [widget.identifierField!]
        : ['tree_number', 'edge_number', 'row_number', 'id'];

    for (final idField in identifierFields) {
      if (currentRowData.containsKey(idField) && currentRowData[idField] != null) {
        final currentId = currentRowData[idField];

        // Find matching row in previousData by this identifier
        final matchFound = (widget.previousData as List).cast<Map<String, dynamic>?>().any(
          (prevRow) => prevRow != null && prevRow[idField] == currentId,
        );

        if (matchFound) return true;
      }
    }

    return false;
  }

  List<TrinaColumn> _buildColumns() {
    final columns = <TrinaColumn>[];
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;

    if (itemSchema == null) {
      return columns;
    }

    final properties = itemSchema['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      return columns;
    }

    // Add drag-handle column (leftmost, pinned) when the array is draggable.
    // Setting enableRowDrag renders a drag_indicator icon in this column's
    // cells; TrinaGrid auto-hides it while the grid is sorted/filtered/grouped
    // (see canRowDrag), so a reorder can never corrupt the sort/validation map.
    if (_rowDragEnabled) {
      columns.add(
        TrinaColumn(
          title: '',
          field: '__row_drag__',
          type: TrinaColumnTypeText(),
          width: 40,
          frozen: TrinaColumnFrozen.start,
          enableRowDrag: true,
          enableSorting: false,
          enableColumnDrag: false,
          enableContextMenu: false,
          enableDropToResize: false,
          readOnly: true,
          enableEditingMode: false,
          renderer: (_) => const SizedBox.shrink(),
        ),
      );
    }

    // Add menu column (always second, pinned left)
    columns.add(
      TrinaColumn(
        title: '',
        field: '__row_menu__',
        type: TrinaColumnTypeText(),
        width: 50,
        frozen: TrinaColumnFrozen.start,
        enableSorting: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableDropToResize: false,
        readOnly: true,
        enableEditingMode: false,
        renderer: (rendererContext) {
          // Check if row has previous data (exists in previous inventory)
          final currentRowData = rendererContext.row.cells.map(
            (key, cell) => MapEntry(key, cell.value),
          );

          final hasPreviousData = _hasMatchingPreviousData(currentRowData);

          return Container(
            alignment: Alignment.center,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: AppLocalizations.of(context)!.gridRowOptions,
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteRow(rendererContext.rowIdx);
                } else if (value == 'copy') {
                  _copyRow(rendererContext.rowIdx);
                } else if (value == 'edit') {
                  _editRowAsFormDialog(rendererContext.rowIdx);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  enabled: !_isArrayReadOnly,
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: _isArrayReadOnly ? Colors.grey : null),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.gridRowEdit,
                        style: TextStyle(color: _isArrayReadOnly ? Colors.grey : null),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  enabled: !_isArrayReadOnly,
                  child: Row(
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 18,
                        color: _isArrayReadOnly ? Colors.grey : null,
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.gridRowCopy,
                        style: TextStyle(color: _isArrayReadOnly ? Colors.grey : null),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !hasPreviousData && !_isArrayReadOnly,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 18,
                        color: (hasPreviousData || _isArrayReadOnly) ? Colors.grey : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.gridRowDelete,
                        style: TextStyle(
                          color: (hasPreviousData || _isArrayReadOnly) ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add validation status column (first, before menu, pinned left)
    columns.add(
      TrinaColumn(
        title: '',
        field: '__validation_status__',
        type: TrinaColumnTypeText(),
        width: 50,
        frozen: TrinaColumnFrozen.start,
        enableSorting: false,
        enableColumnDrag: false,
        enableContextMenu: false,
        enableDropToResize: false,
        readOnly: true,
        enableEditingMode: false,
        renderer: (rendererContext) {
          // Use the original data index stored in the row so the validation
          // indicator stays with the correct row after sorting.
          final originalIndex = rendererContext.row.cells['__original_index__']?.value as int?;
          return ValidationStatusIndicator.build(
            context: context,
            rowIndex: originalIndex ?? rendererContext.rowIdx,
            propertyName: widget.propertyName ?? 'unknown',
            validationResult: widget.validationResult,
          );
        },
      ),
    );

    // Add row number column if enabled
    if (widget.layoutOptions?['rowNumber'] == true) {
      columns.add(
        TrinaColumn(
          title: '#',
          field: '__row_number__',
          type: TrinaColumnTypeText(),
          width: 50,
          frozen: TrinaColumnFrozen.start,
          enableSorting: false,
          enableColumnDrag: false,
          enableContextMenu: false,
          enableDropToResize: false,
          readOnly: true,
          enableEditingMode: false,
          renderer: (rendererContext) {
            return Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: GridDensityService.cellVerticalPadding,
              ),
              child: Text(
                '${rendererContext.rowIdx + 1}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            );
          },
        ),
      );
    }

    // NEW STRUCTURE: Use columnItems array if provided (items with groups)
    if (widget.columnItems != null && widget.columnItems!.isNotEmpty) {
      int frozenColumnCount = 0;

      // Helper function to create a column from item config
      TrinaColumn? createColumnFromItem(Map<String, dynamic> itemConfig) {
        final fieldName = itemConfig['name'] as String?;
        if (fieldName == null) return null;
        if (itemConfig['display'] == false) return null;

        // Get schema for this field (or create synthetic for calculated)
        Map<String, dynamic> propertySchema;

        if (!properties.containsKey(fieldName)) {
          // Calculated or nested array field defined only in layout
          if (itemConfig['type'] == 'calculated') {
            propertySchema = {
              'type': 'calculated',
              'title': itemConfig['title'] ?? fieldName,
              'expression': itemConfig['expression'],
              if (itemConfig['variables'] != null) 'variables': itemConfig['variables'],
              'readonly': true,
              if (itemConfig['unit_short'] != null)
                '\$tfm': {'unit_short': itemConfig['unit_short']},
            };
          } else if (itemConfig['type'] == 'array' && itemConfig['component'] == 'datagrid') {
            // Nested array column
            propertySchema = properties[fieldName] ?? {'type': 'array'};
          } else {
            return null;
          }
        } else {
          propertySchema = properties[fieldName] as Map<String, dynamic>;
        }

        // Merge config from item with schema defaults
        final title =
            itemConfig['title'] as String? ?? propertySchema['title'] as String? ?? fieldName;
        final width = (itemConfig['width'] as num?)?.toDouble() ?? 150.0;
        final pinnedValue = itemConfig['pinned'] as String?;
        final isReadOnly =
            itemConfig['readonly'] as bool? ??
            propertySchema['readOnly'] as bool? ??
            propertySchema['readonly'] as bool? ??
            false;

        // Determine frozen position
        final frozen = pinnedValue == 'left'
            ? TrinaColumnFrozen.start
            : pinnedValue == 'right'
            ? TrinaColumnFrozen.end
            : TrinaColumnFrozen.none;

        if (frozen == TrinaColumnFrozen.start) {
          frozenColumnCount++;
        }

        // Determine type and renderer
        final typeValue = itemConfig['type'] ?? propertySchema['type'];
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;

        TrinaColumnType columnType = TrinaColumnTypeText();
        bool isEnum = false;
        bool isNumeric = false;
        bool isBoolean = false;
        bool isCalculated = type == 'calculated';
        bool isNestedArray = false;
        Map<String, dynamic>? nestedArrayConfig;

        if (isCalculated) {
          _calculatedColumnConfigs[fieldName] = itemConfig;
        }

        if (type == 'array' && itemConfig['component'] == 'datagrid') {
          isNestedArray = true;
          nestedArrayConfig = itemConfig;
        } else if (propertySchema.containsKey('enum')) {
          isEnum = true;
          columnType = const EnumCodeColumnType();
        } else if (type == 'boolean') {
          isBoolean = true;
        } else if (type == 'integer' || type == 'number') {
          isNumeric = true;
          columnType = TrinaColumnTypeNumber(
            negative: true,
            format: type == 'number' ? '#,###.##' : '#,###',
            applyFormatOnInit: false,
            allowFirstDot: true,
            locale: 'de_DE',
          );
        }

        final trinaColumn = TrinaColumn(
          title: title, //unit != null ? '$title ($unit)' : title,
          field: fieldName,
          type: columnType,
          width: width,
          frozen: frozen,
          enableSorting: true,
          enableColumnDrag: false,
          enableContextMenu: false,
          enableDropToResize: true,
          readOnly: isReadOnly || isCalculated,
          enableEditingMode: false,
          renderer: isNestedArray
              ? (rendererContext) => _buildNestedArrayCell(
                  rendererContext,
                  propertySchema,
                  fieldName,
                  nestedArrayConfig!,
                )
              : isCalculated
              ? (rendererContext) =>
                    _buildGenericFieldCell(rendererContext, propertySchema, fieldName)
              : isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, fieldName)
              : isNumeric
              ? (rendererContext) =>
                    _buildNumericEditableCell(rendererContext, propertySchema, fieldName)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, propertySchema, fieldName)
              : (rendererContext) => _buildTextCell(rendererContext, fieldName),
        );

        return trinaColumn;
      }

      // Process items in order
      for (int i = 0; i < widget.columnItems!.length; i++) {
        final item = widget.columnItems![i];
        final itemMap = item as Map<String, dynamic>;

        if (itemMap['type'] == 'group') {
          // This is a group - process its nested items
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              final column = createColumnFromItem(groupItemMap);
              if (column != null) {
                columns.add(column);
              }
            }
          }
        } else {
          // This is an ungrouped column
          final column = createColumnFromItem(itemMap);
          if (column != null) {
            columns.add(column);
          } else {}
        }
      }

      return columns;
    }

    // Create list of column entries with sortBy for sorting
    final columnEntries = <MapEntry<String, dynamic>>[];

    // If columnConfig is provided, ONLY use fields defined there (layout-driven)
    // Otherwise, fall back to using all schema properties
    final fieldsToProcess = widget.columnConfig != null
        ? widget.columnConfig!.keys
        : properties.keys;

    for (final key in fieldsToProcess) {
      // For calculated fields defined only in layout, create a synthetic schema
      Map<String, dynamic> propertySchema;

      if (!properties.containsKey(key)) {
        // Check if this is a calculated field defined in columnConfig
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig != null && layoutConfig['type'] == 'calculated') {
          // Create synthetic schema for calculated field
          propertySchema = {
            'type': 'calculated',
            'title': layoutConfig['title'] ?? key,
            'expression': layoutConfig['expression'],
            if (layoutConfig['variables'] != null) 'variables': layoutConfig['variables'],
            if (layoutConfig['unit_short'] != null)
              '\$tfm': {'unit_short': layoutConfig['unit_short']},
          };
        } else {
          // Skip if property doesn't exist in schema and isn't a calculated field
          continue;
        }
      } else {
        propertySchema = properties[key] as Map<String, dynamic>;
      }

      final config = _getColumnConfig(key, propertySchema);

      // Skip if explicitly set to not display
      if (config['display'] == false) {
        continue;
      }

      final groupBy = config['groupBy'];
      final columnGroupShow = groupBy?['columnGroupShow'] as String?;
      final pinned = config['pinned'];

      columnEntries.add(
        MapEntry(key, {
          'schema': propertySchema,
          'groupBy': groupBy,
          'columnGroupShow': columnGroupShow,
          'pinned': pinned,
          'width': config['width'],
          'readonly': config['readonly'],
          'title': config['title'],
        }),
      );
    }

    // Column order determined by position in columnConfig/properties

    // Count frozen columns (pinned left)
    int frozenColumnCount = 0;

    // Create columns from sorted entries
    for (final entry in columnEntries) {
      final key = entry.key;
      final propertySchema = entry.value['schema'] as Map<String, dynamic>;
      // Use title from layout config if provided, otherwise from schema
      final title = entry.value['title'] as String? ?? propertySchema['title'] as String? ?? key;

      // Determine type
      final typeValue = propertySchema['type'];
      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Create appropriate column type based on schema
      TrinaColumnType columnType;
      bool isEnum = false;
      bool isNumeric = false;
      bool isBoolean = false;
      bool isCalculated = false;
      bool isNestedArray = false;
      Map<String, dynamic>? nestedArrayConfig;

      // Check if this is a nested array column
      if (type == 'array') {
        // This is a nested array - check if layout defines it as datagrid
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig?['component'] == 'datagrid') {
          isNestedArray = true;
          nestedArrayConfig = layoutConfig;
          columnType = TrinaColumnTypeText();
        } else {
          // Not configured as datagrid, skip this column
          continue;
        }
      } else if (type == 'calculated') {
        // Calculated column - always readonly
        columnType = TrinaColumnTypeText();
        isCalculated = true;
      } else if (propertySchema.containsKey('enum')) {
        // Enum column - will use custom renderer with GenericEnumDialog
        columnType = const EnumCodeColumnType();
        isEnum = true;
      } else if (type == 'boolean') {
        columnType = TrinaColumnTypeText();
        isBoolean = true;
      } else if (type == 'integer' || type == 'number') {
        columnType = TrinaColumnTypeNumber(
          negative: true,
          format: type == 'number' ? '#,###.##' : '#,###',
          applyFormatOnInit: false,
          allowFirstDot: true,
          locale: 'de_DE',
        );
        isNumeric = true;
      } else {
        columnType = TrinaColumnTypeText();
      }

      final groupBy = entry.value['groupBy'] as Map<String, dynamic>?;
      final groupName = groupBy?['headerName'] as String?;
      final pinnedValue = entry.value['pinned'] as String?;

      // Check if field is readonly
      final isReadOnly = entry.value['readonly'] as bool? ?? false;

      /*if (isReadOnly) {
      }*/

      // Determine frozen position from pinned value
      final frozen = pinnedValue == 'left'
          ? TrinaColumnFrozen.start
          : pinnedValue == 'right'
          ? TrinaColumnFrozen.end
          : TrinaColumnFrozen.none;

      // Count frozen columns at start
      if (frozen == TrinaColumnFrozen.start) {
        frozenColumnCount++;
      }

      // Get column width (default 150)
      final columnWidth = (entry.value['width'] as num?)?.toDouble() ?? 150.0;

      columns.add(
        TrinaColumn(
          title: title, //unit != null ? '$title ($unit)' : title,
          field: key,
          type: columnType,
          width: columnWidth,
          frozen: frozen,
          enableSorting: true,
          enableColumnDrag: false,
          enableContextMenu: false,
          enableDropToResize: true,
          readOnly: isReadOnly || isCalculated,
          enableEditingMode: false,
          // Custom renderer for calculated, enum, numeric, boolean, nested array, or grouped columns
          renderer: isNestedArray
              ? (rendererContext) =>
                    _buildNestedArrayCell(rendererContext, propertySchema, key, nestedArrayConfig!)
              : isCalculated
              ? (rendererContext) => _buildGenericFieldCell(rendererContext, propertySchema, key)
              : isEnum
              ? (rendererContext) => _buildEnumCell(rendererContext, propertySchema, key)
              : isNumeric
              ? (rendererContext) => _buildNumericEditableCell(rendererContext, propertySchema, key)
              : isBoolean
              ? (rendererContext) => _buildBooleanCell(rendererContext, propertySchema, key)
              : groupName != null
              ? (rendererContext) => _buildTextCell(rendererContext, key)
              : (rendererContext) => _buildTextCell(rendererContext, key),
        ),
      );
    }

    // Store frozen column count for configuration

    return columns;
  }

  /// Determine which fields in a group should remain visible when collapsed.
  /// Fields with "columnGroupShow": "open" stay visible; otherwise the first field does.
  Set<String> _getAlwaysVisibleFields(String groupTitle, List<String> fields) {
    final alwaysVisible = <String>{};

    // Check columnItems for columnGroupShow config
    if (widget.columnItems != null) {
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group' && itemMap['label'] == groupTitle) {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final gi = groupItem as Map<String, dynamic>;
              if (gi['columnGroupShow'] == 'open') {
                final name = gi['name'] as String?;
                if (name != null) alwaysVisible.add(name);
              }
            }
          }
          break;
        }
      }
    }

    // Fallback: if nothing marked, keep the first field visible
    if (alwaysVisible.isEmpty && fields.isNotEmpty) {
      alwaysVisible.add(fields.first);
    }

    return alwaysVisible;
  }

  /// Check if any row has a validation error for the given field.
  bool _fieldHasAnyValidationError(String fieldKey) {
    if (widget.validationResult == null || widget.propertyName == null) return false;
    final rows = _stateManager?.rows ?? _rows;
    for (final row in rows) {
      if (_hasValidationError(row, fieldKey)) return true;
    }
    return false;
  }

  /// Toggle column group visibility: hide all columns in the group, or show them again.
  /// Columns with columnGroupShow "open" (or the first column) always stay visible.
  /// Columns with validation errors are never hidden.
  void _toggleColumnGroup(TrinaColumnGroup group, TrinaGridStateManager stateManager) {
    final fields = group.fields;
    if (fields == null || fields.isEmpty) return;

    final isCollapsed = _collapsedGroups.contains(group.title);
    // Use originalList because refColumns filters out hidden columns
    final allColumns = stateManager.refColumns.originalList;
    final columnsInGroup = allColumns.where((c) => fields.contains(c.field)).toList();

    if (isCollapsed) {
      // Expand: show all columns in this group
      stateManager.hideColumns(columnsInGroup, false);
      _collapsedGroups.remove(group.title);
      group.isCollapsed = false;
    } else {
      // Collapse: hide columns except those that should stay visible or have errors
      final alwaysVisible = _getAlwaysVisibleFields(group.title, fields);
      final columnsToHide = columnsInGroup
          .where((c) => !alwaysVisible.contains(c.field) && !_fieldHasAnyValidationError(c.field))
          .toList();
      stateManager.hideColumns(columnsToHide, true);
      _collapsedGroups.add(group.title);
      group.isCollapsed = true;
    }
  }

  List<TrinaColumnGroup> _buildColumnGroups() {
    // NEW STRUCTURE: Extract groups from columnItems
    if (widget.columnItems != null && widget.columnItems!.isNotEmpty) {
      final groups = <TrinaColumnGroup>[];

      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;

        if (itemMap['type'] == 'group') {
          final groupLabel = itemMap['label'] as String;
          final groupItems = itemMap['items'] as List?;

          if (groupItems != null) {
            final fields = <String>[];
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              final fieldName = groupItemMap['name'] as String?;
              if (fieldName != null) {
                fields.add(fieldName);
              }
            }

            if (fields.isNotEmpty) {
              final canExpand = fields.length == 1;
              groups.add(
                TrinaColumnGroup(
                  title: groupLabel,
                  fields: fields,
                  expandedColumn: canExpand,
                  titleTextAlign: TrinaColumnTextAlign.left,
                  onTap: _toggleColumnGroup,
                ),
              );
            }
          }
        }
      }

      return groups;
    }

    // OLD STRUCTURE: Fallback to groupBy approach
    final groups = <String, List<TrinaColumn>>{};
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return [];

    // Group columns by headerName
    final columnEntries = <MapEntry<String, dynamic>>[];

    // If columnConfig is provided, ONLY use fields defined there (layout-driven)
    // Otherwise, fall back to using all schema properties
    final fieldsToProcess = widget.columnConfig != null
        ? widget.columnConfig!.keys
        : properties.keys;

    for (final key in fieldsToProcess) {
      // For calculated fields defined only in layout, create a synthetic schema
      Map<String, dynamic> propertySchema;
      Map<String, dynamic> config;

      if (!properties.containsKey(key)) {
        // Check if this is a calculated field defined in columnConfig
        final layoutConfig = widget.columnConfig?[key] as Map<String, dynamic>?;
        if (layoutConfig != null && layoutConfig['type'] == 'calculated') {
          // For calculated fields, extract groupBy directly from layout config
          config = <String, dynamic>{
            'groupBy': layoutConfig['groupBy'],
            'display': layoutConfig['display'] ?? true,
            'sortBy': 999,
          };
        } else {
          // Skip if property doesn't exist in schema and isn't a calculated field
          continue;
        }
      } else {
        propertySchema = properties[key] as Map<String, dynamic>;
        config = _getColumnConfig(key, propertySchema);
      }

      // Skip if explicitly set to not display
      if (config['display'] == false) {
        continue;
      }

      final groupBy = config['groupBy'] as Map<String, dynamic>?;
      final headerName = groupBy?['headerName'] as String?;

      if (headerName != null) {
        columnEntries.add(MapEntry(key, {'headerName': headerName}));
      }
    }

    // Column order determined by position in columnConfig/properties

    // Group columns by headerName
    for (final entry in columnEntries) {
      final headerName = entry.value['headerName'] as String;
      final column = _columns.firstWhere((col) => col.field == entry.key);

      if (!groups.containsKey(headerName)) {
        groups[headerName] = [];
      }

      groups[headerName]!.add(column);
    }

    // Create TrinaColumnGroup for each group
    return groups.entries.map((entry) {
      final fields = entry.value.map((col) => col.field).toList();
      final canExpand = fields.length == 1;
      return TrinaColumnGroup(
        title: entry.key,
        fields: fields,
        expandedColumn: canExpand,
        titleTextAlign: TrinaColumnTextAlign.left,
        onTap: _toggleColumnGroup,
      );
    }).toList();
  }

  List<TrinaRow> _buildRows() {
    if (widget.data == null) return [];

    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    _hiddenRowsByOriginalIndex.clear();

    // Build visible candidate rows first, excluding deprecated rows.
    final visibleCandidates = <dynamic>[];
    final candidateIndices = <int>[];

    for (int i = 0; i < widget.data!.length; i++) {
      final item = widget.data![i];
      final itemMap = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      final isDeprecated = itemMap['_deprecated'] == true;

      if (isDeprecated) {
        _hiddenRowsByOriginalIndex[i] = itemMap;
        continue;
      }

      visibleCandidates.add(item);
      candidateIndices.add(i);
    }

    // Apply user filters to non-deprecated candidates, tracking original indices.
    List<dynamic> filteredData = visibleCandidates;
    List<int> originalIndices = candidateIndices;

    if (_filters.isNotEmpty && _activeFilterIndices.isNotEmpty) {
      final tempFiltered = <dynamic>[];
      final tempIndices = <int>[];

      for (int i = 0; i < visibleCandidates.length; i++) {
        final item = visibleCandidates[i];
        final originalIndex = candidateIndices[i];
        bool passesFilters = true;

        // Row must pass ALL active filters
        for (final filterIndex in _activeFilterIndices) {
          if (filterIndex >= _filters.length) continue;

          final filter = _filters[filterIndex];
          final itemMap = item is Map ? item : {};
          final fieldValue = itemMap[filter.field];

          // If filter doesn't match, exclude this row
          if (!filter.matches(fieldValue)) {
            passesFilters = false;
            break;
          }
        }

        if (passesFilters) {
          tempFiltered.add(item);
          tempIndices.add(originalIndex); // Keep track of original index
        } else {
          _hiddenRowsByOriginalIndex[originalIndex] = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
        }
      }

      filteredData = tempFiltered;
      originalIndices = tempIndices;
    }

    return filteredData.asMap().entries.map((entry) {
      final filteredIndex = entry.key;
      final item = entry.value;
      final originalIndex = originalIndices[filteredIndex];

      final rowData = Map<String, dynamic>.from(item is Map ? item : {});
      final cells = <String, TrinaCell>{};

      for (final column in _columns) {
        // Skip auto-generated fields
        if (_internalColumnFields.contains(column.field)) {
          cells[column.field] = TrinaCell(value: null);
        } else {
          // Get value from data, or apply schema default if missing/null
          dynamic cellValue = rowData[column.field];

          // Apply schema default if value is null and schema has a default
          if (cellValue == null && properties != null && properties.containsKey(column.field)) {
            final propertySchema = properties[column.field] as Map<String, dynamic>;
            if (propertySchema.containsKey('default')) {
              cellValue = propertySchema['default'];
              // Also update the rowData so the default is persisted
              rowData[column.field] = cellValue;
            }
          }

          // For calculated columns, pre-compute a sortable value
          if (cellValue == null && _calculatedColumnConfigs.containsKey(column.field)) {
            Map<String, dynamic>? previousRowData;
            if (widget.previousData != null) {
              final identifierFields = widget.identifierField != null
                  ? [widget.identifierField!]
                  : ['tree_number', 'edge_number', 'row_number', 'id'];
              for (final idField in identifierFields) {
                if (rowData.containsKey(idField) && rowData[idField] != null) {
                  previousRowData = (widget.previousData as List)
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                        (prevRow) => prevRow != null && prevRow[idField] == rowData[idField],
                        orElse: () => null,
                      );
                  if (previousRowData != null) break;
                }
              }
            }
            cellValue = _resolveCalculatedValue(
              _calculatedColumnConfigs[column.field]!,
              rowData,
              previousRowData,
            );
          }

          cells[column.field] = TrinaCell(value: cellValue);
        }
      }

      // Preserve hidden fields (display: false) as orphan cells so they survive _notifyDataChanged
      rowData.forEach((key, value) {
        if (!cells.containsKey(key)) cells[key] = TrinaCell(value: value);
      });

      // Store original data array index for validation lookup (survives sorting/filtering)
      cells['__original_index__'] = TrinaCell(value: originalIndex);

      return TrinaRow(cells: cells);
    }).toList();
  }

  Widget _buildTextCell(TrinaColumnRendererContext rendererContext, String fieldKey) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Get field options from column config or columnItems
    Map<String, dynamic>? fieldOptions;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      fieldOptions = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
    } else if (widget.columnItems != null) {
      // Extract field options from columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey) {
                fieldOptions = groupItemMap;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey) {
          fieldOptions = itemMap;
          break;
        }
        if (fieldOptions != null) break;
      }
    }

    // Check if cell is in edit mode (current cell) and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected && !rendererContext.column.readOnly) {
      // Edit mode: use GenericTextField
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: bgColor,
          child: GenericTextField(
            key: ValueKey('cell_${rowIndex}_${fieldKey}'),
            autofocus: true,
            fieldName: fieldKey,
            fieldSchema: const {'type': 'string'},
            value: value,
            errors: const [],
            compact: true,
            currentData: rendererContext.row.cells.map((k, v) => MapEntry(k, v.value)),
            fieldOptions: fieldOptions,
            onChanged: (newValue) {
              rendererContext.cell.value = newValue;
              _stateManager?.notifyListeners();
              _notifyDataChanged();
            },
          ),
        ),
      );
    }

    // Display mode
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(value?.toString() ?? '', overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }

  Widget _buildEnumCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    // Prefer inline name_de/name_en; fall back to lookup table cache when absent.
    final langCode = context.read<Language>().locale.languageCode;
    final enumVals = propertySchema['enum'] as List? ?? [];
    final lookupTable = tfm?['lookup_table'] as String? ?? 'lookup_$fieldKey';
    final resolved = LookupService.instance.getNameList(lookupTable, enumVals, langCode);
    List? nameDe = resolved.any((e) => e != null) ? resolved : null;
    if (nameDe == null) {
      if (langCode == 'en') {
        nameDe = tfm?['name_en'] as List? ?? tfm?['name_de'] as List?;
      } else {
        nameDe = tfm?['name_de'] as List?;
      }
    }
    final enumValues = propertySchema['enum'] as List?;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if field is readonly
    final isReadOnly =
        propertySchema['readOnly'] as bool? ?? propertySchema['readonly'] as bool? ?? false;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Get display text
    String displayText = '';
    if (value != null && nameDe != null && enumValues != null) {
      final index = enumValues.indexOf(value);
      if (index >= 0 && index < nameDe.length) {
        final germanName = nameDe[index];
        displayText = germanName != null ? '$value | $germanName' : value.toString();
      } else {
        displayText = value.toString();
      }
    } else if (value != null) {
      displayText = value.toString();
    }

    return InkWell(
      onTap: isReadOnly ? null : () => _openEnumDialog(rendererContext, propertySchema, fieldKey),
      child: Container(
        color: bgColor,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: GridDensityService.cellVerticalPadding,
        ),
        alignment: Alignment.centerLeft,
        child: Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  Widget _buildNumericEditableCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    final unit = tfm?['unit_short'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Check if this column has upDownBtn (spinner buttons)
    bool hasSpinner = false;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      final columnCfg = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
      hasSpinner = columnCfg?['upDownBtn'] != null;
    } else if (widget.columnItems != null) {
      // Check in columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey && groupItemMap['upDownBtn'] != null) {
                hasSpinner = true;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey && itemMap['upDownBtn'] != null) {
          hasSpinner = true;
          break;
        }
      }
    }

    // Get field options from column config or columnItems
    Map<String, dynamic>? fieldOptions;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      fieldOptions = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
    } else if (widget.columnItems != null) {
      // Extract field options from columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey) {
                fieldOptions = groupItemMap;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey) {
          fieldOptions = itemMap;
          break;
        }
        if (fieldOptions != null) break;
      }
    }

    // Check if cell is in edit mode and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected) {
      // Edit mode: use GenericTextField in compact mode for grid
      return Container(
        color: bgColor,
        child: GenericTextField(
          key: ValueKey('cell_${rowIndex}_${fieldKey}'),
          autofocus: true,
          fieldName: fieldKey,
          fieldSchema: propertySchema,
          value: value,
          errors: const [],
          compact: true,
          fieldOptions: fieldOptions,
          // When the user confirms (floating ✓ or soft-keyboard Done), clear
          // Trina's current cell so the cell exits edit mode BEFORE validation
          // rebuilds the grid. Without this, the rebuild remounts the
          // GenericTextField (autofocus: true), which reopens the keyboard.
          onConfirm: () => _stateManager?.clearCurrentCell(),
          onChanged: (newValue) {
            rendererContext.cell.value = newValue;
            _stateManager?.notifyListeners();
            _notifyDataChanged();
          },
        ),
      );
    }

    // Display mode: show text
    String displayText = '';
    if (value != null && value.toString() != 'null') {
      displayText = value.toString();
      if (unit != null && unit.isNotEmpty) {
        displayText = '$displayText $unit';
      }
    }

    // Check for attentionIfNot: show warning icon when value differs from expected
    final attentionIfNot = fieldOptions?['attentionIfNot'] ?? tfm?['attentionIfNot'];
    final showAttention =
        attentionIfNot != null &&
        value != null &&
        value.toString() != 'null' &&
        value != attentionIfNot;

    return Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: GridDensityService.cellVerticalPadding,
      ),
      alignment: hasSpinner ? Alignment.center : Alignment.centerRight,
      child: showAttention
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Flexible(child: Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            )
          : Text(displayText, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }

  Widget _buildBooleanCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final boolValue = value == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if field is readonly (support both 'readOnly' and 'readonly')
    final isReadOnly =
        propertySchema['readOnly'] as bool? ?? propertySchema['readonly'] as bool? ?? false;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Get field options from column config or columnItems
    Map<String, dynamic>? fieldOptions;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      fieldOptions = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
    } else if (widget.columnItems != null) {
      // Extract field options from columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey) {
                fieldOptions = groupItemMap;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey) {
          fieldOptions = itemMap;
          break;
        }
        if (fieldOptions != null) break;
      }
    }

    // Check if cell is in edit mode and row is selected
    final isCurrentCell = rendererContext.stateManager.currentCell?.key == rendererContext.cell.key;
    final isRowSelected = rendererContext.stateManager.currentRowIdx == rowIndex;

    if (isCurrentCell && isRowSelected && !isReadOnly) {
      // Edit mode: use GenericTextField with switch
      return Container(
        color: bgColor,
        alignment: Alignment.center,
        child: GenericTextField(
          key: ValueKey('cell_${rowIndex}_${fieldKey}'),
          autofocus: true,
          fieldName: fieldKey,
          fieldSchema: propertySchema,
          value: value,
          errors: const [],
          compact: true,
          fieldOptions: fieldOptions,
          onChanged: (newValue) {
            rendererContext.cell.value = newValue;
            _stateManager?.notifyListeners();
            _notifyDataChanged();
          },
        ),
      );
    }

    // Display mode: show localised boolean text
    final l10n = AppLocalizations.of(context)!;
    final displayText = boolValue ? l10n.gridBoolYes : l10n.gridBoolNo;

    return Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: GridDensityService.cellVerticalPadding,
      ),
      alignment: Alignment.center,
      child: Text(displayText),
    );
  }

  Widget _buildNestedArrayCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
    Map<String, dynamic> nestedArrayConfig,
  ) {
    final value = rendererContext.cell.value;
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Get nested array data
    List<dynamic>? nestedData;
    if (value is List) {
      nestedData = value;
    } else if (value is String && nestedArrayConfig['options']?['asJson'] == true) {
      // Try to parse JSON string
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          nestedData = decoded;
        }
      } catch (e) {}
    }

    final itemCount = nestedData?.length ?? 0;
    final l10nNested = AppLocalizations.of(context)!;
    final displayText = itemCount == 0
        ? l10nNested.gridNestedEmpty
        : l10nNested.gridNestedEntries(itemCount);

    // Check if parent array or this field is readonly
    final isReadOnly =
        _isArrayReadOnly ||
        (propertySchema['readOnly'] as bool? ?? propertySchema['readonly'] as bool? ?? false);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(fontSize: 14, color: itemCount == 0 ? Colors.grey : null),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: AppLocalizations.of(context)!.gridNestedEdit,
            onPressed: isReadOnly
                ? null
                : () => _openNestedArrayDialog(
                    rendererContext,
                    propertySchema,
                    fieldKey,
                    nestedArrayConfig,
                    nestedData,
                  ),
          ),
        ],
      ),
    );
  }

  /// Find the previous-survey row matching [currentRowData], using the
  /// configured [identifierField] (or common fallbacks) to pair rows.
  Map<String, dynamic>? _findMatchingPreviousRow(Map<String, dynamic> currentRowData) {
    if (widget.previousData == null) return null;

    // Use configured identifier field or fall back to common fields
    final identifierFields = widget.identifierField != null
        ? [widget.identifierField!]
        : ['tree_number', 'edge_number', 'row_number', 'id'];

    for (final idField in identifierFields) {
      if (currentRowData.containsKey(idField) && currentRowData[idField] != null) {
        final currentId = currentRowData[idField];

        // Find matching row in previousData by this identifier
        final match = (widget.previousData as List).cast<Map<String, dynamic>?>().firstWhere(
          (prevRow) => prevRow != null && prevRow[idField] == currentId,
          orElse: () => null,
        );

        if (match != null) return match;
      }
    }
    return null;
  }

  Future<void> _openNestedArrayDialog(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
    Map<String, dynamic> nestedArrayConfig,
    List<dynamic>? currentData,
  ) async {
    // Create schema for nested array from property schema
    final nestedArraySchema = Map<String, dynamic>.from(propertySchema);

    // Get nested columns config and options
    final nestedColumns = nestedArrayConfig['columns'] as Map<String, dynamic>?;
    final nestedOptions = nestedArrayConfig['options'] as Map<String, dynamic>?;

    // Build property path for validation
    final rowIndex = rendererContext.rowIdx;
    final nestedPath = widget.propertyName != null
        ? '${widget.propertyName}/$rowIndex/$fieldKey'
        : '$rowIndex/$fieldKey';

    // Find the matching previous-survey row for this grid row and slice its
    // nested array, so the nested grid's cell info dialogs can show previous
    // values too.
    final currentRowData = rendererContext.row.cells.map((key, cell) => MapEntry(key, cell.value));
    final previousRow = _findMatchingPreviousRow(currentRowData);
    final previousNested = previousRow?[fieldKey];
    final previousData = previousNested is List ? previousNested : null;

    final result = await ArrayGridDialog.show(
      context: context,
      nestedArraySchema: nestedArraySchema,
      data: currentData,
      title: propertySchema['title'] as String? ?? fieldKey,
      validationResult: widget.validationResult,
      propertyPath: nestedPath,
      columnConfig: nestedColumns,
      layoutOptions: nestedOptions,
      parentReadOnly: _isArrayReadOnly,
      previousData: previousData,
      identifierField: nestedColumns?['identifierField'] as String?,
    );

    if (result != null) {
      // Update cell value based on storage format
      if (nestedOptions?['asJson'] == true) {
        // Store as JSON string
        rendererContext.cell.value = jsonEncode(result);
      } else {
        // Store as List
        rendererContext.cell.value = result;
      }
      _stateManager?.notifyListeners();
      _notifyDataChanged();
    }
  }

  Widget _buildGenericFieldCell(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) {
    final rowIndex = rendererContext.rowIdx;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _getCellBackgroundColor(
      rendererContext.row,
      fieldKey,
      isDark,
      isReadOnly: rendererContext.column.readOnly,
    );

    // Get current row data to find matching previous row by identifier
    final currentRowData = rendererContext.row.cells.map((key, cell) => MapEntry(key, cell.value));

    // Find matching previous row by identifier (tree_number, edge_number, etc.)
    final previousRowData = _findMatchingPreviousRow(currentRowData);

    // Get field options from column config or columnItems
    Map<String, dynamic>? fieldOptions;
    if (widget.columnConfig != null && widget.columnConfig!.containsKey(fieldKey)) {
      fieldOptions = widget.columnConfig![fieldKey] as Map<String, dynamic>?;
    } else if (widget.columnItems != null) {
      // Extract field options from columnItems structure
      for (final item in widget.columnItems!) {
        final itemMap = item as Map<String, dynamic>;
        if (itemMap['type'] == 'group') {
          final groupItems = itemMap['items'] as List?;
          if (groupItems != null) {
            for (final groupItem in groupItems) {
              final groupItemMap = groupItem as Map<String, dynamic>;
              if (groupItemMap['name'] == fieldKey) {
                fieldOptions = groupItemMap;
                break;
              }
            }
          }
        } else if (itemMap['name'] == fieldKey) {
          fieldOptions = itemMap;
          break;
        }
        if (fieldOptions != null) break;
      }
    }

    return Container(
      color: bgColor,
      child: GenericTextField(
        key: ValueKey('cell_${rowIndex}_${fieldKey}'),
        fieldName: fieldKey,
        fieldSchema: propertySchema,
        value: rendererContext.cell.value,
        errors: const [],
        compact: true,
        previousData: previousRowData,
        currentData: rendererContext.row.cells.map((k, v) => MapEntry(k, v.value)),
        fieldOptions: fieldOptions,
      ),
    );
  }

  Future<void> _openEnumDialog(
    TrinaColumnRendererContext rendererContext,
    Map<String, dynamic> propertySchema,
    String fieldKey,
  ) async {
    final enumValues = propertySchema['enum'] as List? ?? [];
    final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
    // Prefer inline name_de/name_en; fall back to lookup table cache when absent.
    final langCode = context.read<Language>().locale.languageCode;
    final lookupTable = tfm?['lookup_table'] as String? ?? 'lookup_$fieldKey';
    final resolved = LookupService.instance.getNameList(lookupTable, enumValues, langCode);
    List? nameDe = resolved.any((e) => e != null) ? resolved : null;
    if (nameDe == null) {
      if (langCode == 'en') {
        nameDe = tfm?['name_en'] as List? ?? tfm?['name_de'] as List?;
      } else {
        nameDe = tfm?['name_de'] as List?;
      }
    }
    List? interval = tfm?['interval'] as List?;
    if (interval == null) {
      final lookupTable = tfm?['lookup_table'] as String? ?? 'lookup_$fieldKey';
      interval = LookupService.instance.getIntervalList(lookupTable, enumValues);
    }

    final result = await GenericEnumDialog.show(
      context: context,
      fieldName: fieldKey,
      fieldSchema: propertySchema,
      currentValue: rendererContext.cell.value,
      enumValues: enumValues,
      nameDe: nameDe,
      interval: interval,
      fullscreen: true,
    );

    if (result != null) {
      // Check if user selected "Leeren" (clear selection)
      if (result is ClearSelection) {
        rendererContext.cell.value = null;
      } else {
        rendererContext.cell.value = result;
      }
      _stateManager?.notifyListeners();
      _notifyDataChanged();
    }
  }

  void _setEmptyArray() {
    // Clear all rows - this will set data to null via _notifyDataChanged
    _rows.clear();
    _stateManager?.removeAllRows();
    _notifyDataChanged(true);
  }

  Future<void> _editRowAsFormDialog(int rowIndex) async {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    if (itemSchema == null) return;

    // Build current row data from cells
    final rows = _stateManager?.rows ?? _rows;
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    final row = rows[rowIndex];
    final currentData = <String, dynamic>{};
    row.cells.forEach((key, cell) {
      if (!_internalColumnFields.contains(key) && key != '__original_index__') {
        currentData[key] = cell.value;
      }
    });

    // Find matching previous row by identifier so calculated fields can display
    // values that depend on previous inventory data (e.g. dbh_previous).
    Map<String, dynamic>? previousRowData;
    if (widget.previousData != null) {
      final identifierFields = widget.identifierField != null
          ? [widget.identifierField!]
          : ['tree_number', 'edge_number', 'row_number', 'id'];
      for (final idField in identifierFields) {
        if (currentData.containsKey(idField) && currentData[idField] != null) {
          previousRowData = (widget.previousData as List).cast<Map<String, dynamic>?>().firstWhere(
            (prevRow) => prevRow != null && prevRow[idField] == currentData[idField],
            orElse: () => null,
          );
          if (previousRowData != null) break;
        }
      }
    }

    // Filter the parent validation result to only this row's errors so the
    // form dialog header shows the same issues as the grid row indicator.
    final originalIndex = row.cells['__original_index__']?.value as int? ?? rowIndex;
    TFMValidationResult? rowValidationResult;
    if (widget.validationResult != null && widget.propertyName != null) {
      final rowPath = '/${widget.propertyName}/$originalIndex';
      final filteredAjvErrors = widget.validationResult!.ajvErrors
          .where(
            (e) => e.instancePath == rowPath || (e.instancePath?.startsWith('$rowPath/') ?? false),
          )
          .toList();
      final filteredTfmErrors = widget.validationResult!.tfmErrors
          .where(
            (e) => e.instancePath == rowPath || (e.instancePath?.startsWith('$rowPath/') ?? false),
          )
          .toList();
      rowValidationResult = TFMValidationResult(
        ajvValid: filteredAjvErrors.isEmpty,
        ajvErrors: filteredAjvErrors,
        tfmAvailable: widget.validationResult!.tfmAvailable,
        tfmErrors: filteredTfmErrors,
      );
    }

    final result = await ArrayRowFormDialog.show(
      context: context,
      itemSchema: itemSchema,
      initialData: currentData,
      columnConfig: widget.columnConfig,
      columnItems: widget.columnItems,
      layoutOptions: widget.layoutOptions,
      title: AppLocalizations.of(context)!.gridRowEditTitle,
      saveButtonText: AppLocalizations.of(context)!.gridRowEditSave,
      readOnly: _isArrayReadOnly,
      previousRowData: previousRowData,
      rowValidationResult: rowValidationResult,
    );

    if (result != null) {
      // Update existing row cells with form result
      final rows = _stateManager?.rows ?? _rows;
      if (rowIndex < 0 || rowIndex >= rows.length) return;
      final targetRow = rows[rowIndex];
      result.forEach((key, value) {
        if (targetRow.cells.containsKey(key)) {
          targetRow.cells[key]!.value = value;
        }
      });
      _stateManager?.notifyListeners();
      _notifyDataChanged();
      setState(() {});
    }
  }

  /// Collect all field names that have autoIncrement enabled,
  /// checking schema ($tfm.form.autoIncrement), columnItems, and columnConfig.
  Set<String> _getAutoIncrementFields(Map<String, dynamic> properties) {
    final fields = <String>{};

    // Schema-based autoIncrement
    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      if (form?['autoIncrement'] == true) {
        fields.add(key);
      }
    });

    // columnItems-based autoIncrement (new structure with groups)
    if (widget.columnItems != null) {
      for (final item in widget.columnItems!) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] == 'group') {
          final groupItems = item['items'] as List<dynamic>? ?? [];
          for (final subItem in groupItems) {
            if (subItem is! Map<String, dynamic>) continue;
            final name = subItem['name'] as String?;
            if (name != null && subItem['autoIncrement'] == true) fields.add(name);
          }
        } else {
          final name = item['name'] as String?;
          if (name != null && item['autoIncrement'] == true) fields.add(name);
        }
      }
    }

    // columnConfig-based autoIncrement (old flat structure)
    if (widget.columnConfig != null) {
      widget.columnConfig!.forEach((key, config) {
        if (config is Map<String, dynamic> && config['autoIncrement'] == true) {
          fields.add(key);
        }
      });
    }

    return fields;
  }

  /// Collect all field names that have resetOnCopy enabled,
  /// checking columnItems and columnConfig.
  Set<String> _getResetOnCopyFields(Map<String, dynamic> properties) {
    final fields = <String>{};

    // columnItems-based resetOnCopy (new structure with groups)
    if (widget.columnItems != null) {
      for (final item in widget.columnItems!) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] == 'group') {
          final groupItems = item['items'] as List<dynamic>? ?? [];
          for (final subItem in groupItems) {
            if (subItem is! Map<String, dynamic>) continue;
            final name = subItem['name'] as String?;
            if (name != null && subItem['resetOnCopy'] == true) fields.add(name);
          }
        } else {
          final name = item['name'] as String?;
          if (name != null && item['resetOnCopy'] == true) fields.add(name);
        }
      }
    }

    // columnConfig-based resetOnCopy (old flat structure)
    if (widget.columnConfig != null) {
      widget.columnConfig!.forEach((key, config) {
        if (config is Map<String, dynamic> && config['resetOnCopy'] == true) {
          fields.add(key);
        }
      });
    }

    return fields;
  }

  /// Collect default values defined in columnItems (and nested groups).
  /// Returns a map of fieldName → defaultValue.
  Map<String, dynamic> _getColumnItemDefaultsMap() {
    final defaults = <String, dynamic>{};
    if (widget.columnItems == null) return defaults;

    void processItem(Map<String, dynamic> item) {
      final name = item['name'] as String?;
      if (name != null && item.containsKey('default')) {
        defaults[name] = item['default'];
      }
      final children = item['items'] as List?;
      if (children != null) {
        for (final child in children) {
          if (child is Map<String, dynamic>) processItem(child);
        }
      }
    }

    for (final item in widget.columnItems!) {
      if (item is Map<String, dynamic>) processItem(item);
    }
    return defaults;
  }

  /// Compute the next auto-increment value for a field given current rows.
  int _computeNextAutoIncrementValue(String key, Map<String, dynamic> propertySchema) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final existingValues = <int>{};

    final rowsToUse = _stateManager?.rows ?? _rows;
    for (final row in rowsToUse) {
      final intValue = parseInt(row.cells[key]?.value);
      if (intValue != null) existingValues.add(intValue);
    }

    if (widget.data != null) {
      for (final item in widget.data!) {
        if (item is! Map) continue;
        final intValue = parseInt(item[key]);
        if (intValue != null) existingValues.add(intValue);
      }
    }

    final defaultValue = propertySchema['default'] as int? ?? 1;
    if (existingValues.isEmpty) return defaultValue;

    int maxValue = existingValues.first;
    for (final value in existingValues) {
      if (value > maxValue) maxValue = value;
    }

    return maxValue + 1;
  }

  Future<void> _addRowAsFormDialog() async {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    if (itemSchema == null) return;

    final properties = itemSchema['properties'] as Map<String, dynamic>?;

    // Pre-compute auto-increment values so the form opens with correct defaults.
    // Checks both schema ($tfm.form.autoIncrement) and columnItems/columnConfig.
    final autoIncrementInitialData = <String, dynamic>{};

    // Apply defaults from columnItems first (lowest priority)
    autoIncrementInitialData.addAll(_getColumnItemDefaultsMap());

    if (properties != null) {
      final autoIncrFields = _getAutoIncrementFields(properties);
      for (final key in autoIncrFields) {
        final propertySchema = properties[key] as Map<String, dynamic>?;
        if (propertySchema != null) {
          autoIncrementInitialData[key] = _computeNextAutoIncrementValue(key, propertySchema);
        }
      }
    }

    final result = await ArrayRowFormDialog.show(
      context: context,
      itemSchema: itemSchema,
      initialData: autoIncrementInitialData.isNotEmpty ? autoIncrementInitialData : null,
      columnConfig: widget.columnConfig,
      columnItems: widget.columnItems,
      layoutOptions: widget.layoutOptions,
      title: AppLocalizations.of(context)!.gridRowAddTitle,
      saveButtonText: AppLocalizations.of(context)!.gridRowAddSave,
      readOnly: _isArrayReadOnly,
    );

    if (result != null) {
      // Add the row with data from form
      if (properties == null) return;

      final newRow = <String, dynamic>{};
      final autoIncrFields = _getAutoIncrementFields(properties);

      // Initialize with form data and apply defaults/auto-increment
      properties.forEach((key, value) {
        final propertySchema = value as Map<String, dynamic>;
        final typeValue = propertySchema['type'];

        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        if (autoIncrFields.contains(key) && (type == 'integer' || type == 'number')) {
          // Use the pre-computed auto-increment value (consistent with what was shown in form)
          newRow[key] =
              autoIncrementInitialData[key] ?? _computeNextAutoIncrementValue(key, propertySchema);
        } else {
          // Use value from form, or default, or type-based default
          newRow[key] = result[key] ?? propertySchema['default'] ?? _getDefaultValue(type);
        }
      });

      // Create cells and add row
      final cells = <String, TrinaCell>{};
      for (final column in _columns) {
        if (_internalColumnFields.contains(column.field)) {
          cells[column.field] = TrinaCell(value: null);
        } else {
          cells[column.field] = TrinaCell(value: newRow[column.field]);
        }
      }
      // Preserve hidden fields (display: false) as orphan cells so they survive _notifyDataChanged
      newRow.forEach((key, value) {
        if (!cells.containsKey(key)) cells[key] = TrinaCell(value: value);
      });

      // Set original index for new row (will be the current data length after adding)
      cells['__original_index__'] = TrinaCell(value: widget.data?.length ?? 0);

      final newTrinaRow = TrinaRow(cells: cells);
      _rows.add(newTrinaRow);

      if (_stateManager != null) {
        final insertIdx = _sortedInsertIndex(newTrinaRow);
        _stateManager!.insertRows(insertIdx, [newTrinaRow]);
        _notifyDataChanged();
        _scrollToRow(newTrinaRow);
      } else {
        _notifyDataChanged();
        setState(() {});
      }
    }
  }

  dynamic _getDefaultValue(String? type) {
    switch (type) {
      case 'string':
        return '';
      case 'number':
      case 'integer':
        return null;
      case 'boolean':
        return false;
      case 'array':
        return [];
      case 'object':
        return {};
      default:
        return null;
    }
  }

  void addRow() {
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    if (properties == null) return;

    final newRow = <String, dynamic>{};

    // Seed with defaults from columnItems (overridden below by schema defaults / autoIncrement)
    newRow.addAll(_getColumnItemDefaultsMap());

    properties.forEach((key, value) {
      final propertySchema = value as Map<String, dynamic>;
      final typeValue = propertySchema['type'];

      String? type;
      if (typeValue is String) {
        type = typeValue;
      } else if (typeValue is List) {
        type = typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
      }

      // Check if field has autoIncrement enabled
      final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
      final form = tfm?['form'] as Map<String, dynamic>?;
      final autoIncrement = form?['autoIncrement'] as bool? ?? false;

      if (autoIncrement && (type == 'integer' || type == 'number')) {
        // Auto-increment from full dataset (including hidden/deprecated rows).
        newRow[key] = _computeNextAutoIncrementValue(key, propertySchema);
      } else if (propertySchema.containsKey('default')) {
        newRow[key] = propertySchema['default'];
      } else if (!newRow.containsKey(key)) {
        // Only apply type-based default if not already seeded (e.g. from columnItems default)
        switch (type) {
          case 'string':
            newRow[key] = '';
            break;
          case 'number':
          case 'integer':
            newRow[key] = null;
            break;
          case 'boolean':
            newRow[key] = false;
            break;
          case 'array':
            newRow[key] = [];
            break;
          case 'object':
            newRow[key] = {};
            break;
          default:
            newRow[key] = null;
        }
      }
    });

    final cells = <String, TrinaCell>{};
    for (final column in _columns) {
      // Skip auto-generated fields
      if (_internalColumnFields.contains(column.field)) {
        cells[column.field] = TrinaCell(value: null);
      } else {
        cells[column.field] = TrinaCell(value: newRow[column.field]);
      }
    }
    // Preserve hidden fields (display: false) as orphan cells so they survive _notifyDataChanged
    newRow.forEach((key, value) {
      if (!cells.containsKey(key)) cells[key] = TrinaCell(value: value);
    });

    // Set original index for new row (will be the current data length after adding)
    cells['__original_index__'] = TrinaCell(value: widget.data?.length ?? 0);

    final newTrinaRow = TrinaRow(cells: cells);

    // Add to internal state first
    _rows.add(newTrinaRow);

    if (_stateManager != null) {
      // Sync to state manager - this should trigger onChanged but it doesn't always
      final insertIdx = _sortedInsertIndex(newTrinaRow);
      _stateManager!.insertRows(insertIdx, [newTrinaRow]);
      // Explicitly notify parent since onChanged might not fire for insertRows
      _notifyDataChanged();
      _scrollToRow(newTrinaRow);
    } else {
      // If grid not loaded yet (empty state), notify parent directly
      _notifyDataChanged();
      // Trigger rebuild to show the grid
      setState(() {});
    }
  }

  void _deleteRow(int rowIndex) {
    if (_stateManager != null) {
      if (rowIndex < 0 || rowIndex >= _stateManager!.rows.length) return;
      _stateManager!.removeRows([_stateManager!.rows[rowIndex]]);
      _rows = _stateManager!.rows;
      _notifyDataChanged();
    } else {
      if (rowIndex < 0 || rowIndex >= _rows.length) return;
      _rows.removeAt(rowIndex);
      _notifyDataChanged();
      setState(() {});
    }
  }

  void _copyRow(int rowIndex) {
    final sourceRows = _stateManager?.rows ?? _rows;
    if (rowIndex < 0 || rowIndex >= sourceRows.length) return;
    final rowToCopy = sourceRows[rowIndex];
    final newCells = <String, TrinaCell>{};

    // Get schema to check for autoIncrement fields
    final itemSchema = widget.jsonSchema['items'] as Map<String, dynamic>?;
    final properties = itemSchema?['properties'] as Map<String, dynamic>?;

    // Get fields that should reset to default on copy
    final resetOnCopyFields = properties != null ? _getResetOnCopyFields(properties) : <String>{};

    rowToCopy.cells.forEach((key, cell) {
      // Skip auto-generated fields (including __original_index__ which will be reassigned)
      if (_internalColumnFields.contains(key) || key == '__original_index__') {
        if (_internalColumnFields.contains(key)) {
          newCells[key] = TrinaCell(value: null);
        }
        return;
      }

      // Check if this field should reset to default on copy
      if (resetOnCopyFields.contains(key)) {
        final propertySchema = properties?[key] as Map<String, dynamic>?;
        final schemaDefault = propertySchema?['default'];
        final typeValue = propertySchema?['type'];
        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }
        newCells[key] = TrinaCell(value: schemaDefault ?? _getDefaultValue(type));
        return;
      }

      // Check if this field has autoIncrement enabled
      if (properties != null && properties.containsKey(key)) {
        final propertySchema = properties[key] as Map<String, dynamic>;
        final typeValue = propertySchema['type'];

        String? type;
        if (typeValue is String) {
          type = typeValue;
        } else if (typeValue is List) {
          type =
              typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
        }

        // Check for autoIncrement
        final tfm = propertySchema['\$tfm'] as Map<String, dynamic>?;
        final form = tfm?['form'] as Map<String, dynamic>?;
        final autoIncrement = form?['autoIncrement'] as bool? ?? false;

        if (autoIncrement && (type == 'integer' || type == 'number')) {
          // Auto-increment from full dataset (including hidden/deprecated rows).
          final nextValue = _computeNextAutoIncrementValue(key, propertySchema);

          newCells[key] = TrinaCell(value: nextValue);
        } else {
          // Normal field: copy the value
          newCells[key] = TrinaCell(value: cell.value);
        }
      } else {
        // No schema info, just copy
        newCells[key] = TrinaCell(value: cell.value);
      }
    });

    // Set original index for copied row (will be the current data length after adding)
    newCells['__original_index__'] = TrinaCell(value: widget.data?.length ?? 0);

    final newTrinaRow = TrinaRow(cells: newCells);

    if (_stateManager != null) {
      final insertIdx = _sortedInsertIndex(newTrinaRow);
      _stateManager!.insertRows(insertIdx, [newTrinaRow]);
      _rows = _stateManager!.rows;
      _notifyDataChanged();
      _scrollToRow(newTrinaRow);
    } else {
      _rows.add(newTrinaRow);
      _notifyDataChanged();
      setState(() {});
    }
  }

  /// Returns the index at which [newRow] should be inserted to maintain the
  /// current sort order. Falls back to appending at the end when no sort is active.
  int _sortedInsertIndex(TrinaRow newRow) {
    if (_stateManager == null || _columnSortStates.isEmpty) {
      return _stateManager?.rows.length ?? _rows.length;
    }
    final sortEntry = _columnSortStates.entries.firstWhere(
      (e) => e.value != 0,
      orElse: () => const MapEntry('', 0),
    );
    if (sortEntry.value == 0) return _stateManager!.rows.length;

    final sortField = sortEntry.key;
    final ascending = sortEntry.value == 1;
    final newValue = newRow.cells[sortField]?.value;

    // Use the column's own comparator so the insert position matches the
    // grid's sort order (e.g. numeric enum codes, formatted numbers).
    TrinaColumn? sortColumn;
    for (final col in _columns) {
      if (col.field == sortField) {
        sortColumn = col;
        break;
      }
    }

    final rows = _stateManager!.rows;
    for (int i = 0; i < rows.length; i++) {
      final existingValue = rows[i].cells[sortField]?.value;
      if (_compareRowValues(newValue, existingValue, ascending, sortColumn?.type) < 0) return i;
    }
    return rows.length;
  }

  int _compareRowValues(dynamic a, dynamic b, bool ascending, [TrinaColumnType? columnType]) {
    int result;
    if (columnType != null) {
      result = columnType.compare(a, b);
    } else if (a == null && b == null) {
      result = 0;
    } else if (a == null) {
      result = 1; // nulls sort last
    } else if (b == null) {
      result = -1;
    } else if (a is num && b is num) {
      result = a.compareTo(b);
    } else {
      result = a.toString().compareTo(b.toString());
    }
    return ascending ? result : -result;
  }

  /// Scrolls the grid to [newRow] and selects its first visible cell.
  void _scrollToRow(TrinaRow newRow) {
    if (_usesAutoHeight) {
      // In auto-height / non-scrollable mode, the grid should never keep an
      // internal vertical offset. Keeping it would create a blank band below
      // the last row and clip the same height at the top.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final vertical = _stateManager?.scroll.bodyRowsVertical;
        if (vertical != null && vertical.hasClients && vertical.offset != 0) {
          vertical.jumpTo(0);
        }
      });
      return;
    }

    // Two frames are needed: the first lets insertRows finish rebuilding the
    // grid, the second fires once the new row is actually laid out so that
    // setCurrentCell (which calls moveScrollByRow internally) can resolve the
    // correct pixel offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_stateManager == null || !mounted) return;
        final rowIdx = _stateManager!.rows.indexOf(newRow);
        if (rowIdx < 0) return;

        // Scroll the vertical axis directly to the row's pixel offset, then
        // select the cell so TrinaGrid also highlights it correctly.
        final rowHeight = _stateManager!.rowTotalHeight;
        final targetOffset = rowIdx * rowHeight;
        final verticalGroup = _stateManager!.scroll.vertical;
        if (verticalGroup != null) {
          try {
            verticalGroup.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          } catch (_) {
            // Group has no attached controllers yet; skip scroll.
          }
        }

        final visibleColumn = _stateManager!.columns.firstWhere(
          (c) => !c.hide,
          orElse: () => _stateManager!.columns.first,
        );
        final cell = newRow.cells[visibleColumn.field];
        if (cell != null) _stateManager!.setCurrentCell(cell, rowIdx);
      });
    });
  }

  void _applyFiltersToCurrentState() {
    if (_stateManager == null) return;

    bool changed = false;

    // 1. Check currently visible rows to see if any should be hidden
    final rowsToRemove = <TrinaRow>[];
    for (final row in _stateManager!.rows) {
      final originalIndex = row.cells['__original_index__']?.value as int?;
      if (originalIndex == null) continue;

      final rowData = <String, dynamic>{};
      row.cells.forEach((key, cell) {
        if (!key.startsWith('__')) {
          rowData[key] = cell.value;
        }
      });

      bool passesFilters = true;
      if (rowData['_deprecated'] == true) {
        passesFilters = false;
      } else if (_filters.isNotEmpty && _activeFilterIndices.isNotEmpty) {
        for (final filterIndex in _activeFilterIndices) {
          if (filterIndex >= _filters.length) continue;
          final filter = _filters[filterIndex];
          if (!filter.matches(rowData[filter.field])) {
            passesFilters = false;
            break;
          }
        }
      }

      if (!passesFilters) {
        rowsToRemove.add(row);
        _hiddenRowsByOriginalIndex[originalIndex] = rowData;
      }
    }

    if (rowsToRemove.isNotEmpty) {
      _stateManager!.removeRows(rowsToRemove);
      for (final row in rowsToRemove) {
        _rows.remove(row);
      }

      final currentCell = _stateManager!.currentCell;
      if (currentCell != null && rowsToRemove.any((r) => r.cells.values.contains(currentCell))) {
        _stateManager!.clearCurrentCell();
      }
      changed = true;
    }

    // 2. Check hidden rows to see if any should be shown
    final indicesToShow = <int>[];
    _hiddenRowsByOriginalIndex.forEach((index, hiddenData) {
      bool passesFilters = true;
      if (hiddenData['_deprecated'] == true) {
        passesFilters = false;
      } else if (_filters.isNotEmpty && _activeFilterIndices.isNotEmpty) {
        for (final filterIndex in _activeFilterIndices) {
          if (filterIndex >= _filters.length) continue;
          final filter = _filters[filterIndex];
          if (!filter.matches(hiddenData[filter.field])) {
            passesFilters = false;
            break;
          }
        }
      }

      if (passesFilters) {
        indicesToShow.add(index);
      }
    });

    if (indicesToShow.isNotEmpty) {
      final rowsToAdd = <TrinaRow>[];
      for (final index in indicesToShow) {
        final rowData = _hiddenRowsByOriginalIndex.remove(index)!;

        final cells = <String, TrinaCell>{};
        for (final column in _columns) {
          if (_internalColumnFields.contains(column.field)) {
            cells[column.field] = TrinaCell(value: null);
          } else {
            // Apply value or null
            cells[column.field] = TrinaCell(value: rowData[column.field]);
          }
        }

        rowData.forEach((key, value) {
          if (!cells.containsKey(key)) {
            cells[key] = TrinaCell(value: value);
          }
        });

        cells['__original_index__'] = TrinaCell(value: index);

        final newRow = TrinaRow(cells: cells);
        rowsToAdd.add(newRow);
        _rows.add(newRow);
      }

      for (final newRow in rowsToAdd) {
        final insertIdx = _sortedInsertIndex(newRow);
        _stateManager!.insertRows(insertIdx, [newRow]);
      }
      changed = true;
    }

    if (changed) {
      _stateManager!.notifyListeners();
    }
  }

  /// Called after the user drag-reorders rows (only possible when not
  /// sorted/filtered — see canRowDrag). The grid has already moved the rows, so
  /// the current display order IS the desired data order. We emit data in that
  /// order directly, bypassing the __original_index__ re-sort in
  /// [_notifyDataChanged] (which would otherwise undo the move). The parent then
  /// feeds the reordered data back and the grid rebuilds with fresh indices.
  void _onRowsMoved(TrinaGridOnRowsMovedEvent event) {
    final rows = _stateManager?.rows ?? _rows;
    _rows = rows;

    final data = <Map<String, dynamic>>[];
    for (final row in rows) {
      final rowData = <String, dynamic>{};
      row.cells.forEach((key, cell) {
        if (!_internalColumnFields.contains(key) && key != '__original_index__') {
          rowData[key] = cell.value;
        }
      });
      data.add(rowData);
    }

    // Keep any rows hidden from the UI (deprecated rows) in the payload,
    // appended in their original relative order. Filter-hidden rows can't occur
    // here because dragging is disabled while a filter is active.
    if (_hiddenRowsByOriginalIndex.isNotEmpty) {
      final hidden = _hiddenRowsByOriginalIndex.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in hidden) {
        data.add(Map<String, dynamic>.from(entry.value));
      }
    }

    if (_rowDragEnabled) {
      widget.onDataChanged?.call(data.isEmpty ? null : data);
    }
  }

  void _notifyDataChanged([bool forceData = false]) {
    _applyFiltersToCurrentState();

    // Sync _rows from state manager if available (source of truth)
    final rowsToUse = _stateManager?.rows ?? _rows;

    // Build row data entries paired with their original index so we can
    // restore the original data order. After sorting the grid, stateManager.rows
    // is in display (sorted) order, but validation errors reference indices in
    // the original data order. Sending data in sorted order would cause the
    // parent to re-validate and produce error indices that no longer match
    // the __original_index__ stored in each row.
    final rowDataEntries = <MapEntry<int, Map<String, dynamic>>>[];
    for (int i = 0; i < rowsToUse.length; i++) {
      final row = rowsToUse[i];
      final originalIndex = row.cells['__original_index__']?.value as int? ?? (i + 100000);
      final rowData = <String, dynamic>{};
      row.cells.forEach((key, cell) {
        // Skip auto-generated fields - they're not part of the data
        if (!_internalColumnFields.contains(key) && key != '__original_index__') {
          rowData[key] = cell.value;
        }
      });
      rowDataEntries.add(MapEntry(originalIndex, rowData));
    }

    // Keep rows hidden in the UI (deprecated and filter-hidden) in the payload.
    if (!forceData && _hiddenRowsByOriginalIndex.isNotEmpty) {
      final presentIndices = rowDataEntries.map((e) => e.key).toSet();
      _hiddenRowsByOriginalIndex.forEach((originalIndex, rowData) {
        if (!presentIndices.contains(originalIndex)) {
          rowDataEntries.add(MapEntry(originalIndex, Map<String, dynamic>.from(rowData)));
        }
      });
    }

    // Sort by original index to always send data in a stable order
    rowDataEntries.sort((a, b) => a.key.compareTo(b.key));
    final data = rowDataEntries.map((e) => e.value).toList();

    if (forceData) {
      widget.onDataChanged?.call(data);
      return;
    }

    // If last row is deleted, data should be null not empty array.
    if (data.isEmpty) {
      widget.onDataChanged?.call(null);
    } else {
      widget.onDataChanged?.call(data);
    }
  }

  @override
  void dispose() {
    // Remove listener from MapControllerProvider
    if (_mapControllerProvider != null) {
      _mapControllerProvider!.removeListener(_onMapControllerChanged);
    }
    GridDensityService.notifier.removeListener(_onDensityChanged);
    LookupService.versionNotifier.removeListener(_onLookupReloaded);
    // Flush any pending debounced save before tearing down.
    if (_widthSaveTimer?.isActive == true) {
      _widthSaveTimer!.cancel();
      _saveColumnWidths();
    }
    _widthSaveTimer?.cancel();
    _stateManager?.resizingChangeNotifier.removeListener(_onColumnWidthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    if (_columns.isEmpty) {
      return const Center(child: Text('No schema properties found'));
    }

    if (_rows.isEmpty) {
      final emptyState = Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.table_chart, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              //const Text('Kein Eintrag vorhanden', style: TextStyle(color: Colors.grey)),
              //const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _isArrayReadOnly ? null : addRow,
                      child: Text(AppLocalizations.of(context)!.gridAddRowForm),
                    ),
                    Container(width: 1, height: 24, color: Colors.white54),
                    IconButton(
                      onPressed: _isArrayReadOnly ? null : _addRowAsFormDialog,
                      icon: const Icon(Icons.playlist_add),
                      tooltip: AppLocalizations.of(context)!.gridAddRowFormTooltip,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (widget.data == null) // if data is null
                ElevatedButton(
                  onPressed: _setEmptyArray,
                  child: Text(AppLocalizations.of(context)!.gridNoEntryRequired),
                ),
            ],
          ),
        ),
      );
      // In auto-height mode the parent imposes no fixed height, so give the
      // empty state a bounded box; otherwise let it fill the parent as before.
      return _usesAutoHeight ? SizedBox(height: 180, child: emptyState) : emptyState;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Add row button bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D30) : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Filter button (if filters are configured)
              if (_filters.isNotEmpty) ...[
                Badge(
                  label: Text('${_activeFilterIndices.length}'),
                  isLabelVisible: _activeFilterIndices.isNotEmpty,
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      size: 20,
                      color: _activeFilterIndices.isNotEmpty
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    tooltip: 'Filter',
                    onPressed: _showFilterDialog,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                AppLocalizations.of(context)!.gridRowEntries(_rows.length),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12),
              ),
              Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  // card background color
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final maxRows = (widget.layoutOptions?['maxRows'] as num?)?.toInt();
                        final atMax = maxRows != null && _rows.length >= maxRows;
                        return TextButton(
                          onPressed: (_isArrayReadOnly || atMax) ? null : addRow,
                          child: Text(AppLocalizations.of(context)!.gridAddRow),
                        );
                      },
                    ),
                    Container(width: 1, height: 24, color: Colors.white54),
                    Builder(
                      builder: (context) {
                        final maxRows = (widget.layoutOptions?['maxRows'] as num?)?.toInt();
                        final atMax = maxRows != null && _rows.length >= maxRows;
                        return IconButton(
                          onPressed: atMax ? null : _addRowAsFormDialog,
                          icon: const Icon(Icons.playlist_add),
                          tooltip: AppLocalizations.of(context)!.gridAddRowFormTooltip,
                          color: Theme.of(context).colorScheme.primary,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Grid
        _gridBody(isDark),
      ],
    );
  }

  /// The TrinaGrid itself. In [autoHeight] mode it is wrapped in a [SizedBox]
  /// whose height is computed to fit all rows (header + group header + rows),
  /// so the grid grows as rows are added and never scrolls internally.
  /// Otherwise it expands to fill the parent.
  Widget _gridBody(bool isDark) {
    final grid = Selector<MapControllerProvider, bool>(
      selector: (_, provider) => provider.isSheetFullyExpanded,
      builder: (context, isExpanded, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Wait for the async column-width load to complete so the
            // grid is built exactly once with the correct col.width values.
            // SharedPreferences is fast (<5 ms), so the blank is invisible.
            if (!_savedWidthsLoaded) return const SizedBox.shrink();
            _adjustColumnsToFitWidth(constraints.maxWidth);
            return Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Handover scroll to sheet if at top and scrolling up (dragging down)
                    if (isExpanded && notification.metrics.pixels <= 0) {
                      if (notification is ScrollUpdateNotification &&
                          notification.scrollDelta != null) {
                        final delta = notification.scrollDelta!;
                        if (delta < 0) {
                          // Dragging down at top -> Collapse sheet
                          // Pass the delta to the sheet controller via provider
                          context.read<MapControllerProvider>().dragSheet(delta);
                        }
                      } else if (notification is OverscrollNotification &&
                          notification.overscroll < 0) {
                        // Handle overscroll (iOS bounce or Android stretch)
                        context.read<MapControllerProvider>().dragSheet(notification.overscroll);
                      }
                    }
                    return false;
                  },
                  child: TrinaGrid(
                    columns: _columns,
                    rows: _rows,
                    columnGroups: _columnGroups.isNotEmpty ? _columnGroups : null,
                    onLoaded: (TrinaGridOnLoadedEvent event) {
                      _stateManager = event.stateManager;
                      _rows = event.stateManager.rows;
                      // Seed baseline widths from live column objects.
                      for (final col in event.stateManager.columns) {
                        _lastKnownWidths[col.field] = col.width;
                      }
                      // resizingChangeNotifier is the notifier that
                      // resizeColumn() fires (via notifyResizingListeners).
                      // The main stateManager notifier is NOT called on
                      // column resize, so we must listen here instead.
                      event.stateManager.resizingChangeNotifier.addListener(_onColumnWidthChanged);
                    },
                    onChanged: (TrinaGridOnChangedEvent event) {
                      // Sync _rows from state manager
                      _rows = _stateManager?.rows ?? _rows;
                      _notifyDataChanged();
                    },
                    onRowsMoved: _onRowsMoved,
                    onSorted: (TrinaGridOnSortedEvent event) {
                      final column = event.column;

                      // Get current sort state for this column (default to 0 = none)
                      final currentState = _columnSortStates[column.field] ?? 0;
                      final nextState = (currentState + 1) % 3; // Cycle: 0 -> 1 -> 2 -> 0

                      // Clear all other column states
                      _columnSortStates.clear();
                      _columnSortStates[column.field] = nextState;

                      // Apply the sort based on next state
                      if (nextState == 1) {
                        // Ascending
                        _stateManager?.sortAscending(column);
                      } else if (nextState == 2) {
                        // Descending
                        _stateManager?.sortDescending(column);
                      } else {
                        // None - restore original order by rebuilding from source data
                        final originalRows = _buildRows();
                        _stateManager?.removeAllRows();
                        _stateManager?.appendRows(originalRows);
                        _rows = originalRows;
                        // Clear the sort indicator
                        column.sort = TrinaColumnSort.none;
                        return;
                      }

                      _rows = _stateManager?.rows ?? _rows;
                    },
                    configuration: TrinaGridConfiguration(
                      scrollbar: TrinaGridScrollbarConfig(
                        showVertical: false,
                        showHorizontal: false,
                        enableVerticalScroll: _isScrollable,
                      ),
                      columnSize: const TrinaGridColumnSizeConfig(
                        resizeMode: TrinaResizeMode.normal,
                      ),
                      enterKeyAction: TrinaGridEnterKeyAction.editingAndMoveDown,
                      enableMoveDownAfterSelecting: true,
                      enableMoveHorizontalInEditing: true,
                      tabKeyAction: TrinaGridTabKeyAction.moveToNextOnEdge,
                      style: TrinaGridStyleConfig(
                        rowHeight: GridDensityService.rowHeight,
                        columnHeight: GridDensityService.columnHeight,
                        iconSize: 18,
                        gridBorderRadius: BorderRadius.zero,
                        enableGridBorderShadow: false,
                        gridBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        rowColor: isDark ? const Color(0xFF252526) : Colors.white,
                        activatedColor: isDark
                            ? const Color.fromARGB(10, 0, 255, 0)
                            : const Color(0xFFDCF2FF),
                        cellTextStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                        columnTextStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        gridBorderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                        borderColor: isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300,
                        activatedBorderColor: isDark
                            ? const Color.fromARGB(100, 0, 255, 0)
                            : Colors.blue,
                        inactivatedBorderColor: isDark
                            ? const Color(0xFF3E3E42)
                            : Colors.grey.shade300,
                        iconColor: isDark ? Colors.white70 : Colors.black54,
                        disabledIconColor: isDark ? Colors.white24 : Colors.black26,
                        menuBackgroundColor: isDark ? const Color(0xFF252526) : Colors.white,
                        cellColorInEditState: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        cellColorInReadOnlyState: isDark
                            ? const Color(0xFF2D2D30)
                            : Colors.grey.shade100,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (_usesAutoHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final vertical = _stateManager?.scroll.bodyRowsVertical;
        if (vertical != null && vertical.hasClients && vertical.offset != 0) {
          vertical.jumpTo(0);
        }
      });
    }

    if (!_usesAutoHeight) {
      return Expanded(child: grid);
    }

    // Height = column header (+ group header if grouped) + one row per data row,
    // plus a small border allowance. Grows by one row-height per added row.
    final groupHeaderHeight = _columnGroups.isNotEmpty ? GridDensityService.columnHeight : 0.0;
    final gridHeight =
        GridDensityService.columnHeight +
        groupHeaderHeight +
        GridDensityService.rowHeight * _rows.length +
        2.0;
    return SizedBox(height: gridHeight, child: grid);
  }
}

/// Column type for enum columns: cell values are the raw codes, so sorting
/// compares them as numbers when both parse as numbers (2 before 10), and
/// alphabetically otherwise (e.g. Bundesland codes like "HB", "BY").
class EnumCodeColumnType extends TrinaColumnTypeText {
  const EnumCodeColumnType();

  @override
  int compare(dynamic a, dynamic b) {
    if (a == null || b == null) {
      return a == b
          ? 0
          : a == null
          ? -1
          : 1;
    }
    final numA = a is num ? a : num.tryParse(a.toString());
    final numB = b is num ? b : num.tryParse(b.toString());
    if (numA != null && numB != null) return numA.compareTo(numB);
    return a.toString().compareTo(b.toString());
  }
}
