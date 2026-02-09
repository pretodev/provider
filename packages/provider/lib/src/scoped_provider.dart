import 'package:flutter/widgets.dart';
import 'package:nested/nested.dart';

import 'change_notifier_provider.dart';
import 'provider.dart';

// ignore_for_file: avoid_classes_with_only_static_members

/// A convenience variation of [MultiProvider] that accepts [Provide] entries.
class ScopedProvider extends MultiProvider {
  /// Builds a scoped set of providers from [provides].
  ScopedProvider({
    Key? key,
    required List<SingleChildWidget> provides,
    Widget? child,
    TransitionBuilder? builder,
  }) : super(key: key, providers: provides, child: child, builder: builder);
}

/// Reader passed to [Provide.create] and [Provide.notifier].
abstract class ScopedReader {
  /// Reads a dependency by type.
  T get<T>();

  /// Alias for [get], allowing `reader()` syntax.
  T call<T>();
}

class _ScopedReader implements ScopedReader {
  const _ScopedReader(this._context);

  final BuildContext _context;

  @override
  T get<T>() {
    return _context.read<T>();
  }

  @override
  T call<T>() {
    return get<T>();
  }
}

/// Factory helpers used by [ScopedProvider].
abstract final class Provide {
  /// Exposes an existing [value].
  ///
  /// Unlike [Provider.value], this supports `lazy`.
  static SingleChildWidget value<T>(T value, {Object? key}) {
    assert(() {
      Provider.debugCheckInvalidValueType?.call<T>(value);
      return true;
    }());
    return InheritedProvider<T>.value(
      key: _toKey(key),
      value: value,
      lazy: false,
    );
  }

  /// Creates and exposes a dependency.
  static SingleChildWidget create<T>(
    T Function(ScopedReader i) create, {
    Object? key,
    bool? lazy,
  }) {
    return Provider<T>(
      key: _toKey(key),
      lazy: lazy,
      create: (context) => create(_ScopedReader(context)),
    );
  }

  /// Creates and exposes a [ChangeNotifier] dependency.
  static SingleChildWidget notifier<T extends ChangeNotifier?>(
    T Function(ScopedReader i) create, {
    Object? key,
    bool? lazy,
  }) {
    return ChangeNotifierProvider<T>(
      key: _toKey(key),
      lazy: lazy,
      create: (context) => create(_ScopedReader(context)),
    );
  }

  static Key? _toKey(Object? key) {
    if (key == null) {
      return null;
    }
    if (key is Key) {
      return key;
    }
    return ValueKey<Object?>(key);
  }
}
