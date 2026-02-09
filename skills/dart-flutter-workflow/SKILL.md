---
name: dart-flutter-workflow
description: Operational workflow for Dart and Flutter projects with a focus on safe execution via LLMs, mandatory use of FVM when available, validation with analyzer/format/fix, and a before/after testing strategy. Use when Codex needs to implement, review, or validate changes in Dart/Flutter projects.
---

# Dart/Flutter Workflow

## Identify project type

1. Detect whether the project uses Flutter (e.g., presence of `flutter` in `pubspec.yaml`, `android/`, `ios/`, `web/` folders, or `lib/main.dart` with a Flutter app).
2. Treat pure Dart projects (CLI/script/package) as executable by the LLM.
3. Avoid `flutter run` and `flutter build` in Flutter projects; leave interactive execution and runtime log inspection to the user.

## Detect and apply FVM

1. Check whether the project uses FVM (e.g., `.fvm/`, `fvm_config.json`, or documented FVM usage in the repository).
2. If FVM exists, prefix commands with `fvm` to avoid version conflicts:
   - `fvm flutter pub get`
   - `fvm dart run <target>`
   - `fvm dart analyze`
   - `fvm dart format <files>`
3. If FVM does not exist, use standard `dart`/`flutter` commands.

## Run Dart commands

1. Run Dart binaries using `dart run` or `fvm dart run`.
2. For `build_runner`, run `dart run build_runner build` (or `fvm dart run build_runner build` when using FVM).

## Validate quality before concluding

1. Run `dart fix --apply` (or `fvm dart fix --apply`) to automatically fix as much as possible.
2. Run `dart format` (or `fvm dart format`) on all modified files.
3. Run `dart analyze` (or `fvm dart analyze`) at the end.
4. Fix errors and warnings related to the performed changes; do not conclude the task with introduced errors.

## Testing strategy

1. If a `test/` folder exists, run tests before starting the implementation to establish a baseline.
2. Run the tests again after finishing.
3. Inform the user which tests broke after the change.
4. Offer to fix the broken tests, but do not start fixing them without explicit request.

## Final delivery

1. Provide a short and objective report of what was done.
2. Do not list files in the report by default; focus on the changed behavior.
3. If there are test failures, include the list of failing tests.
