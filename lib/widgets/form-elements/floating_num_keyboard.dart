import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onscreen_num_keyboard/onscreen_num_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefKey = 'floating_num_keyboard_enabled';

/// Returns true when the floating numeric keyboard should be used:
/// - platform is Android, iOS, or Windows  AND
/// - the user hasn't opted out in Settings.
bool get shouldUseFloatingNumKeyboard {
  if (kIsWeb) return false;
  try {
    final platformSupported = Platform.isAndroid || Platform.isIOS || Platform.isWindows;
    return platformSupported && FloatingNumKeyboard.userEnabled;
  } catch (_) {
    return false;
  }
}

/// Floating, draggable on-screen numeric keyboard overlay.
///
/// Usage:
/// ```dart
/// FloatingNumKeyboard.show(
///   context: context,
///   textController: _controller,
///   onChanged: (v) => widget.onChanged?.call(v),
///   isDecimal: false,
/// );
/// ```
/// Call [FloatingNumKeyboard.hide] or tap outside to dismiss.
class FloatingNumKeyboard {
  FloatingNumKeyboard._();

  static OverlayEntry? _entry;
  static TextEditingController? _activeController;

  /// Whether the user has enabled the floating keyboard (default: false).
  static bool _userEnabled = false;

  /// Current user preference (read-only from outside).
  static bool get userEnabled => _userEnabled;

  /// Load the saved preference from SharedPreferences.
  /// Call once at app startup (e.g. in main()).
  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _userEnabled = prefs.getBool(_kPrefKey) ?? false;
  }

  /// Persist and apply the user's preference.
  static Future<void> setEnabled(bool value) async {
    _userEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, value);
    // If disabled while keyboard is visible, dismiss it immediately.
    if (!value) hide();
  }

  /// When true, focus-triggered auto-show is suppressed (e.g. while a dialog is open).
  /// Set via [setAutoShowSuppressed]; read via [autoShowSuppressed].
  static bool _suppressAutoShow = false;
  static bool get autoShowSuppressed => _suppressAutoShow;

  /// Enable/disable focus-triggered keyboard auto-show.
  /// Call with `true` before opening a modal dialog and `false` after it closes
  /// to prevent the floating keyboard from appearing when focus is restored.
  static void setAutoShowSuppressed(bool value) => _suppressAutoShow = value;

  /// The last position the user dragged the keyboard to.
  /// Persists between show() calls so the keyboard stays where users put it.
  static Offset _lastPosition = const Offset(20, 300);

  /// Show the keyboard connected to [textController].
  /// If the keyboard is already visible for the same controller, this is a no-op.
  ///
  /// [onConfirm] is called when the user taps the confirm (✓) button. Use this
  /// to perform additional cleanup, e.g. clearing Trina Grid's current cell
  /// selection so the cell exits edit mode before a validation rebuild can
  /// remount the cell widget and re-trigger autofocus.
  static void show({
    required BuildContext context,
    required TextEditingController textController,
    required void Function(dynamic) onChanged,
    bool isDecimal = false,
    VoidCallback? onConfirm,
  }) {
    // Already showing for this exact controller – do nothing.
    if (_activeController == textController && _entry != null) return;

    // Remove any previously visible keyboard.
    _entry?.remove();
    _entry = null;

    _activeController = textController;

    _entry = OverlayEntry(
      builder: (_) => _FloatingKeyboardPanel(
        textController: textController,
        onChanged: onChanged,
        isDecimal: isDecimal,
        initialPosition: _lastPosition,
        onPositionChanged: (pos) => _lastPosition = pos,
        onDismiss: hide,
        onConfirm: onConfirm,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  /// Hide the keyboard unconditionally.
  static void hide() {
    _entry?.remove();
    _entry = null;
    _activeController = null;
  }

  /// Hide the keyboard only if it is currently connected to [controller].
  /// Call this from a field's [dispose] to avoid orphaned overlays.
  static void hideIfOwner(TextEditingController controller) {
    if (_activeController == controller) hide();
  }

  static bool get isVisible => _entry != null;
}

// ─────────────────────────────────────────────────────────────────────────────

class _FloatingKeyboardPanel extends StatefulWidget {
  final TextEditingController textController;
  final void Function(dynamic) onChanged;
  final bool isDecimal;
  final Offset initialPosition;
  final void Function(Offset) onPositionChanged;
  final VoidCallback onDismiss;
  final VoidCallback? onConfirm;

  const _FloatingKeyboardPanel({
    required this.textController,
    required this.onChanged,
    required this.isDecimal,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onDismiss,
    this.onConfirm,
  });

  @override
  State<_FloatingKeyboardPanel> createState() => _FloatingKeyboardPanelState();
}

class _FloatingKeyboardPanelState extends State<_FloatingKeyboardPanel> {
  late Offset _position;
  static const double _panelWidth = 264.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  // ── Input helpers ──────────────────────────────────────────────────────────

  void _onDigit(String digit) => _push(widget.textController.text + digit);

  void _onDecimalTap() {
    final current = widget.textController.text;
    if (current.contains('.')) return;
    _push(current.isEmpty ? '0.' : '$current.');
  }

  void _onBackspace() {
    final current = widget.textController.text;
    if (current.isEmpty) {
      widget.onChanged(null);
      return;
    }
    _push(current.substring(0, current.length - 1));
  }

  void _onClearAll() => _push('');

  void _push(String text) {
    widget.textController.text = text;
    widget.textController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    if (text.isEmpty) {
      widget.onChanged(null);
    } else if (widget.isDecimal) {
      widget.onChanged(double.tryParse(text));
    } else {
      widget.onChanged(int.tryParse(text));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade200;
    final panelColor = isDark ? const Color(0xFF262626) : Colors.white;
    final iconColor = isDark ? Colors.white70 : Colors.black54;

    return Stack(
      children: [
        // ── Transparent barrier: tap outside to dismiss ──────────────────
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: widget.onDismiss),
        ),

        // ── Draggable keyboard panel ─────────────────────────────────────
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Material(
            elevation: 12,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            color: panelColor,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _panelWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Drag handle ───────────────────────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) {
                        setState(() => _position += d.delta);
                        widget.onPositionChanged(_position);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        color: handleColor,
                        child: Row(
                          children: [
                            Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              widget.isDecimal ? 'Decimal input' : 'Numeric input',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onDismiss,
                              child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── NumericKeyboard ───────────────────────────────────
                    NumericKeyboard(
                      onKeyboardTap: _onDigit,
                      textStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      rightButtonFn: _onBackspace,
                      rightButtonLongPressFn: _onClearAll,
                      rightIcon: Icon(Icons.backspace_outlined, color: iconColor),
                      // Integer: left button = confirm/close  |  Decimal: left button = '.'
                      leftButtonFn: widget.isDecimal
                          ? _onDecimalTap
                          : () {
                              // onConfirm runs first (e.g. clearCurrentCell in
                              // Trina Grid) so the cell exits edit mode BEFORE
                              // the focus loss triggers a Trina rebuild that
                              // would otherwise remount the autofocus widget.
                              widget.onConfirm?.call();
                              FocusManager.instance.primaryFocus?.unfocus();
                              widget.onDismiss();
                            },
                      leftIcon: widget.isDecimal
                          ? Text(
                              '.',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            )
                          : Icon(Icons.check, color: iconColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
