import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-row-form-dialog.dart';

/// A validator whose completion the test controls, so the async-validation
/// race can be reproduced deterministically instead of by timing luck.
///
/// Every call is recorded with a *snapshot* of the data it was given (the
/// dialog passes its live `_formData` by reference, so we must copy it to know
/// which input each in-flight validation belongs to).
class _ControllableValidator {
  final List<_ValidationCall> calls = [];

  Future<ValidationResult> validate(
    Map<String, dynamic> schema,
    Map<String, dynamic> data,
  ) {
    final call = _ValidationCall(Map<String, dynamic>.from(data));
    calls.add(call);
    return call.completer.future;
  }

  /// The most recent call whose input `note` equals [note] and is still pending.
  _ValidationCall callForNote(String? note) => calls.firstWhere(
        (c) => c.input['note'] == note && !c.completer.isCompleted,
      );
}

class _ValidationCall {
  _ValidationCall(this.input);
  final Map<String, dynamic> input;
  final Completer<ValidationResult> completer = Completer<ValidationResult>();

  void completeValid() =>
      completer.complete(ValidationResult(isValid: true, errors: const []));

  void completeWithError(String message) => completer.complete(
        ValidationResult(
          isValid: false,
          errors: [ValidationError(instancePath: '/note', message: message)],
        ),
      );
}

Widget _host(Widget child) => ChangeNotifierProvider<Language>.value(
      value: Language(const Locale('de')),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: child),
      ),
    );

void main() {
  // A minimal single-field schema so the dialog renders exactly one TextField
  // via the legacy (non-grouped) GenericForm path.
  final schema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'note': {'type': 'string'},
    },
    'required': ['note'],
  };

  testWidgets(
    'a validation result for older input never overwrites newer input',
    (tester) async {
      final validator = _ControllableValidator();
      final applied = <ValidationResult>[];

      await tester.pumpWidget(
        _host(
          ArrayRowFormDialog(
            itemSchema: schema,
            validateOverride: validator.validate,
            onValidationApplied: applied.add,
          ),
        ),
      );

      // 1. initState schedules an initial validation. Fire the debounce and
      //    settle that first call so it doesn't interfere with the race below.
      await tester.pump(const Duration(milliseconds: 400));
      validator.callForNote(null).completeValid();
      await tester.pump();

      final field = find.byType(TextField);
      expect(field, findsOneWidget);

      // 2. User types "A"; let the debounce fire so validation for "A" starts
      //    and is now in-flight (awaiting the controllable completer).
      await tester.enterText(field, 'A');
      await tester.pump(const Duration(milliseconds: 400));
      final callA = validator.callForNote('A');
      expect(callA.completer.isCompleted, isFalse);

      // 3. User keeps typing -> "AB"; its validation starts too. Now two runs
      //    are in flight, with "AB" being the newest.
      await tester.enterText(field, 'AB');
      await tester.pump(const Duration(milliseconds: 400));
      final callAB = validator.callForNote('AB');

      // 4. The OLDER validation (for "A") resolves late, with an error. Without
      //    the generation guard this stale result would be applied to the form.
      callA.completeWithError('stale-A-error');
      await tester.pump();

      // The stale result must have been discarded, not applied.
      expect(
        applied.any((r) => r.errors.any((e) => e.message == 'stale-A-error')),
        isFalse,
        reason: 'stale validation result for input "A" was applied over "AB"',
      );

      // 5. The NEWEST validation (for "AB") resolves and IS applied.
      callAB.completeValid();
      await tester.pump();

      expect(applied.isNotEmpty, isTrue);
      expect(applied.last.isValid, isTrue);
      expect(applied.last.errors, isEmpty);
    },
  );

  testWidgets(
    'out-of-order completion still applies only the latest run',
    (tester) async {
      final validator = _ControllableValidator();
      final applied = <ValidationResult>[];

      await tester.pumpWidget(
        _host(
          ArrayRowFormDialog(
            itemSchema: schema,
            validateOverride: validator.validate,
            onValidationApplied: applied.add,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      validator.callForNote(null).completeValid();
      await tester.pump();

      final field = find.byType(TextField);

      await tester.enterText(field, 'A');
      await tester.pump(const Duration(milliseconds: 400));
      final callA = validator.callForNote('A');

      await tester.enterText(field, 'AB');
      await tester.pump(const Duration(milliseconds: 400));
      final callAB = validator.callForNote('AB');

      // Complete the NEWEST first, then the older one arrives afterwards.
      callAB.completeWithError('current-AB-error');
      await tester.pump();
      callA.completeValid();
      await tester.pump();

      // The last *applied* result must be the newest run's (AB), even though
      // the older run (A) completed after it.
      expect(applied.last.errors.map((e) => e.message), contains('current-AB-error'));
    },
  );
}
