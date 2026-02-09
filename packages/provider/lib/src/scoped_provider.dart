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
  static const _invalidTypeNames = {'dynamic', 'Object', 'Object?'};
  static const _inheritedProviderScopePrefix = '_InheritedProviderScope<';

  /// Exposes an existing [value].
  static SingleChildWidget value<T>(T value, {Object? key}) {
    assert(() {
      Provider.debugCheckInvalidValueType?.call<T>(value);
      return true;
    }());
    return InheritedProvider<T>.value(
      key: _toKey(key),
      value: value,
    );
  }

  /// Creates and exposes a dependency.
  static SingleChildWidget create<T>(
    Function constructor, {
    Object? key,
    bool? lazy,
  }) {
    _ensureValidGenericType<T>('create');
    return Provider<T>(
      key: _toKey(key),
      lazy: lazy,
      create: (context) => _invokeConstructor<T>(context, constructor),
    );
  }

  /// Creates and exposes a [ChangeNotifier] dependency.
  static SingleChildWidget notifier<T extends ChangeNotifier?>(
    Function constructor, {
    Object? key,
    bool? lazy,
  }) {
    _ensureValidGenericType<T>('notifier');
    return ChangeNotifierProvider<T>(
      key: _toKey(key),
      lazy: lazy,
      create: (context) => _invokeConstructor<T>(context, constructor),
    );
  }

  static T _invokeConstructor<T>(BuildContext context, Function constructor) {
    final constructorString = constructor.runtimeType.toString();
    final className = _resolveClassName<T>(constructorString);
    final params = _extractParams(constructorString);

    try {
      final resolvedParams = _resolveParams(context, params);

      final positionalParams =
          resolvedParams
              .whereType<_ScopedPositionalParam>()
              .map((param) => param.value)
              .toList();

      final namedParams = resolvedParams.whereType<_ScopedNamedParam>().fold(
        <Symbol, dynamic>{},
        (result, param) {
          result[param.named] = param.value;
          return result;
        },
      );

      final instance = Function.apply(
        constructor,
        positionalParams,
        namedParams,
      );

      if (instance is! T) {
        throw ArgumentError(
          'Provide constructor returned ${instance.runtimeType} '
          'but expected $T.',
        );
      }

      return instance;
    } on _ScopedDependencyResolutionException catch (exception) {
      throw exception.prepend(className);
    }
  }

  static List<_ScopedParam> _resolveParams(
    BuildContext context,
    List<_ScopedParam> params,
  ) {
    final hasLegacyDynamicReaderParam = _hasLegacyDynamicReaderParam(params);
    return params.map((param) {
      if (!param.injectableParam) {
        return param;
      }

      final normalizedParamType = _normalizeType(param.className);
      if (normalizedParamType == 'ScopedReader' ||
          (hasLegacyDynamicReaderParam && param is _ScopedPositionalParam)) {
        return param.setValue(_ScopedReader(context));
      }

      return param.setValue(_resolveDependencyByType(context, param));
    }).toList();
  }

  static dynamic _resolveDependencyByType(
    BuildContext context,
    _ScopedParam param,
  ) {
    final normalizedType = _normalizeType(param.className);
    Object? resolvedValue;
    var found = false;

    context.visitAncestorElements((ancestor) {
      final ancestorType = _ancestorExposedType(
        ancestor.widget.runtimeType.toString(),
      );
      if (ancestorType == null) {
        return true;
      }

      if (_normalizeType(ancestorType) != normalizedType) {
        return true;
      }

      if (ancestor is InheritedContext<Object?>) {
        final inheritedContext = ancestor as InheritedContext<Object?>;
        resolvedValue = inheritedContext.value;
      }
      found = true;
      return false;
    });

    if (!found) {
      throw _ScopedDependencyResolutionException([
        param.className,
      ], '${param.className} not registered.');
    }

    if (resolvedValue == null && !param.isNullable) {
      throw _ScopedDependencyResolutionException([
        param.className,
      ], '${param.className} resolved to null.');
    }

    return resolvedValue;
  }

  static List<_ScopedParam> _extractParams(String constructorString) {
    if (constructorString.startsWith('() => ')) {
      return const [];
    }

    if (!constructorString.startsWith('(')) {
      return const [];
    }

    final closeArgsIndex = constructorString.indexOf(') => ');
    if (closeArgsIndex == -1) {
      return const [];
    }

    var allArgs = constructorString.substring(1, closeArgsIndex).trim();
    if (allArgs.isEmpty) {
      return const [];
    }

    var namedArgs = '';
    final namedStart = allArgs.indexOf('{');
    if (namedStart != -1) {
      final namedEnd = _findMatchingIndex(allArgs, namedStart, '{', '}');
      if (namedEnd != -1) {
        namedArgs = allArgs.substring(namedStart + 1, namedEnd).trim();
        allArgs = [
          allArgs.substring(0, namedStart).trim(),
          allArgs.substring(namedEnd + 1).trim(),
        ].where((segment) => segment.isNotEmpty).join(', ');
      }
    }

    return [
      ..._extractPositionalParams(allArgs),
      ..._extractNamedParams(namedArgs),
    ];
  }

  static List<_ScopedPositionalParam> _extractPositionalParams(String allArgs) {
    if (allArgs.trim().isEmpty) {
      return const [];
    }

    var requiredArgs = allArgs.trim();
    var optionalArgs = '';
    final optionalStart = requiredArgs.indexOf('[');
    if (optionalStart != -1) {
      final optionalEnd = _findMatchingIndex(
        requiredArgs,
        optionalStart,
        '[',
        ']',
      );
      if (optionalEnd != -1) {
        optionalArgs =
            requiredArgs.substring(optionalStart + 1, optionalEnd).trim();
        requiredArgs = [
          requiredArgs.substring(0, optionalStart).trim(),
          requiredArgs.substring(optionalEnd + 1).trim(),
        ].where((segment) => segment.isNotEmpty).join(', ');
      }
    }

    return [
      ..._splitTopLevel(
        requiredArgs,
      ).map((param) => _toPositionalParam(param, isRequired: true)),
      ..._splitTopLevel(
        optionalArgs,
      ).map((param) => _toPositionalParam(param, isRequired: false)),
    ];
  }

  static List<_ScopedNamedParam> _extractNamedParams(String namedArgs) {
    if (namedArgs.trim().isEmpty) {
      return const [];
    }

    return _splitTopLevel(namedArgs).map((param) {
      final isRequired = param.startsWith('required ');
      final paramText =
          isRequired
              ? param.substring('required '.length).trim()
              : param.trim();

      final split = _splitTypeAndName(paramText);
      final type = split.key;
      final name = split.value;
      final isNullable = type.endsWith('?');

      return _ScopedNamedParam(
        className: _stripNullableSuffix(type),
        isNullable: isNullable,
        isRequired: isRequired,
        named: Symbol(name),
      );
    }).toList();
  }

  static _ScopedPositionalParam _toPositionalParam(
    String paramType, {
    required bool isRequired,
  }) {
    final type = paramType.trim();
    final isNullable = type.endsWith('?');
    return _ScopedPositionalParam(
      className: _stripNullableSuffix(type),
      isNullable: isNullable,
      isRequired: isRequired,
    );
  }

  static List<String> _splitTopLevel(String input) {
    if (input.trim().isEmpty) {
      return const [];
    }

    final parts = <String>[];
    final currentPart = StringBuffer();
    var angleBracketDepth = 0;
    var curlyBracketDepth = 0;
    var squareBracketDepth = 0;
    var parenthesisDepth = 0;

    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);

      if (char == ',' &&
          angleBracketDepth == 0 &&
          curlyBracketDepth == 0 &&
          squareBracketDepth == 0 &&
          parenthesisDepth == 0) {
        final trimmed = currentPart.toString().trim();
        if (trimmed.isNotEmpty) {
          parts.add(trimmed);
        }
        currentPart.clear();
        continue;
      }

      currentPart.write(char);

      switch (char) {
        case '<':
          angleBracketDepth++;
          break;
        case '>':
          angleBracketDepth--;
          break;
        case '{':
          curlyBracketDepth++;
          break;
        case '}':
          curlyBracketDepth--;
          break;
        case '[':
          squareBracketDepth++;
          break;
        case ']':
          squareBracketDepth--;
          break;
        case '(':
          parenthesisDepth++;
          break;
        case ')':
          parenthesisDepth--;
          break;
      }
    }

    final trimmed = currentPart.toString().trim();
    if (trimmed.isNotEmpty) {
      parts.add(trimmed);
    }

    return parts;
  }

  static MapEntry<String, String> _splitTypeAndName(String paramText) {
    var angleBracketDepth = 0;
    var splitIndex = -1;

    for (var i = 0; i < paramText.length; i++) {
      final char = paramText[i];
      if (char == '<') {
        angleBracketDepth++;
      } else if (char == '>') {
        angleBracketDepth--;
      } else if (char == ' ' && angleBracketDepth == 0) {
        splitIndex = i;
      }
    }

    if (splitIndex == -1) {
      return MapEntry(paramText.trim(), '');
    }

    final type = paramText.substring(0, splitIndex).trim();
    final name = paramText.substring(splitIndex + 1).trim();
    return MapEntry(type, name);
  }

  static int _findMatchingIndex(
    String value,
    int openIndex,
    String openChar,
    String closeChar,
  ) {
    var openCount = 0;
    for (var i = openIndex; i < value.length; i++) {
      final char = value[i];
      if (char == openChar) {
        openCount++;
      } else if (char == closeChar) {
        openCount--;
        if (openCount == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  static bool _hasLegacyDynamicReaderParam(List<_ScopedParam> params) {
    if (params.length != 1) {
      return false;
    }

    final onlyParam = params.single;
    if (onlyParam is! _ScopedPositionalParam || !onlyParam.isRequired) {
      return false;
    }

    final className = _normalizeType(onlyParam.className);
    return className == 'dynamic' || className == 'Object';
  }

  static String? _ancestorExposedType(String runtimeType) {
    if (!runtimeType.startsWith(_inheritedProviderScopePrefix) ||
        !runtimeType.endsWith('>')) {
      return null;
    }

    final className = runtimeType.substring(
      _inheritedProviderScopePrefix.length,
      runtimeType.length - 1,
    );
    return _stripNullableSuffix(className);
  }

  static String _normalizeType(String className) {
    final withoutSpaces = className.replaceAll(' ', '');
    return _stripNullableSuffix(withoutSpaces);
  }

  static String _stripNullableSuffix(String className) {
    if (!className.endsWith('?')) {
      return className;
    }
    return className.substring(0, className.length - 1);
  }

  static String _resolveClassName<T>(String constructorString) {
    final typeName = T.toString();
    if (!_invalidTypeNames.contains(typeName)) {
      return typeName;
    }

    return constructorString.split(' => ').last.trim();
  }

  static void _ensureValidGenericType<T>(String methodName) {
    final typeName = T.toString();
    if (_invalidTypeNames.contains(typeName)) {
      throw ArgumentError(
        'Provide.$methodName requires an explicit generic type.\n'
        'Try: Provide.$methodName<MyClass>(MyClass.new)',
      );
    }
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

abstract class _ScopedParam {
  const _ScopedParam({
    required this.className,
    required this.isNullable,
    required this.isRequired,
    this.value,
  });

  final String className;
  final bool isNullable;
  final bool isRequired;
  final Object? value;

  bool get injectableParam => !isNullable && isRequired;

  _ScopedParam setValue(Object? value);
}

class _ScopedPositionalParam extends _ScopedParam {
  const _ScopedPositionalParam({
    required super.className,
    required super.isNullable,
    required super.isRequired,
    super.value,
  });

  @override
  _ScopedPositionalParam setValue(Object? value) {
    return _ScopedPositionalParam(
      className: className,
      isNullable: isNullable,
      isRequired: isRequired,
      value: value,
    );
  }
}

class _ScopedNamedParam extends _ScopedParam {
  const _ScopedNamedParam({
    required super.className,
    required super.isNullable,
    required super.isRequired,
    required this.named,
    super.value,
  });

  final Symbol named;

  @override
  _ScopedNamedParam setValue(Object? value) {
    return _ScopedNamedParam(
      className: className,
      isNullable: isNullable,
      isRequired: isRequired,
      named: named,
      value: value,
    );
  }
}

class _ScopedDependencyResolutionException implements Exception {
  _ScopedDependencyResolutionException(this.classNames, this.message);

  final List<String> classNames;
  final String message;

  _ScopedDependencyResolutionException prepend(String className) {
    return _ScopedDependencyResolutionException([
      className,
      ...classNames,
    ], message);
  }

  @override
  String toString() {
    if (classNames.length <= 1) {
      return message;
    }
    return '$message\nTrace: ${classNames.join('->')}';
  }
}
