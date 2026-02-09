import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'common.dart';

void main() {
  group('ScopedProvider', () {
    testWidgets('injects binds and supports read/watch/select', (tester) async {
      final textKey = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScopedProvider(
            provides: [
              Provide.value(const BaseUrl('https://api.com')),
              Provide.create<ApiInterface>(ApiImplementation.new),
              Provide.notifier<UserNotifier>(
                UserNotifier.new,
                key: 'user_notifier',
              ),
            ],
            child: Builder(
              builder: (context) {
                final baseUrl = context.read<BaseUrl>().value;
                final apiUrl = context.watch<ApiInterface>().baseUrl;
                final counter = context.select((UserNotifier vm) => vm.counter);
                return Text(
                  '$baseUrl|$apiUrl|$counter',
                  key: textKey,
                  textDirection: TextDirection.ltr,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('https://api.com|https://api.com|0'), findsOneWidget);

      textKey.currentContext!.read<UserNotifier>().increment();
      await tester.pump();

      expect(find.text('https://api.com|https://api.com|1'), findsOneWidget);
    });

    testWidgets('converts object key to ValueKey', (tester) async {
      final childKey = GlobalKey();

      await tester.pumpWidget(
        ScopedProvider(
          provides: [Provide.value(42, key: 'answer')],
          child: Container(key: childKey),
        ),
      );

      expect(find.byKey(const ValueKey<Object?>('answer')), findsOneWidget);
      expect(childKey.currentContext!.read<int>(), 42);
    });

    testWidgets('Bind.value keeps Provider invalid type checks', (
      tester,
    ) async {
      expect(
        () => ScopedProvider(
          provides: [Provide.value(MyListenable())],
          child: Container(),
        ),
        throwsFlutterError,
      );
    });

    testWidgets('binds can only read previous binds', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScopedProvider(
            provides: [
              Provide.create<String>(
                (ScopedReader i) => i.get<int>().toString(),
              ),
              Provide.value(42),
            ],
            child: TextOf<String>(),
          ),
        ),
      );

      expect(tester.takeException(), isA<ProviderNotFoundException>());
    });

    testWidgets(
      'Provide.create resolves required positional dependencies with .new',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ScopedProvider(
              provides: [
                Provide.value(const BaseUrl('https://api.com')),
                Provide.create<ApiInterface>(PositionalApiImplementation.new),
              ],
              child: Builder(
                builder: (context) {
                  final api = context.read<ApiInterface>();
                  return Text(api.baseUrl, textDirection: TextDirection.ltr);
                },
              ),
            ),
          ),
        );

        expect(find.text('https://api.com'), findsOneWidget);
      },
    );

    testWidgets('Provide.notifier resolves no-arg constructors with .new', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScopedProvider(
            provides: [Provide.notifier<SimpleNotifier>(SimpleNotifier.new)],
            child: Builder(
              builder: (context) {
                final counter = context.watch<SimpleNotifier>().counter;
                return Text('$counter', textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      final notifier = tester.element(find.text('0')).read<SimpleNotifier>();
      notifier.increment();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Provide.create keeps ScopedReader callback compatibility', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScopedProvider(
            provides: [
              Provide.value(const BaseUrl('https://api.com')),
              Provide.create<ApiInterface>(_legacyReaderApiFactory),
            ],
            child: Builder(
              builder: (context) {
                final api = context.read<ApiInterface>();
                return Text(api.baseUrl, textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );

      expect(find.text('https://api.com'), findsOneWidget);
    });

    testWidgets('Provide.create supports legacy dynamic reader callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ScopedProvider(
            provides: [
              Provide.value(const BaseUrl('https://api.com')),
              Provide.create<ApiInterface>(_legacyDynamicApiFactory),
            ],
            child: Builder(
              builder: (context) {
                final api = context.read<ApiInterface>();
                return Text(api.baseUrl, textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );

      expect(find.text('https://api.com'), findsOneWidget);
    });

    testWidgets(
      'Provide.create throws with dependency trace on resolution failure',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ScopedProvider(
              provides: [
                Provide.create<MissingDependencyChild>(
                  MissingDependencyChild.new,
                ),
                Provide.create<MissingDependencyRoot>(
                  MissingDependencyRoot.new,
                ),
              ],
              child: TextOf<MissingDependencyRoot>(),
            ),
          ),
        );

        final exception = tester.takeException();
        expect(exception, isNotNull);
        final message = exception.toString();
        expect(message, contains('MissingDependencyLeaf not registered.'));
        expect(
          message,
          contains(
            'Trace: MissingDependencyRoot->MissingDependencyChild->MissingDependencyLeaf',
          ),
        );
      },
    );

    testWidgets('Bind.notifier disposes created notifier on unmount', (
      tester,
    ) async {
      late DisposableNotifier notifier;

      await tester.pumpWidget(
        ScopedProvider(
          provides: [
            Provide.notifier<DisposableNotifier>((_) {
              return notifier = DisposableNotifier();
            }, lazy: false),
          ],
          child: Container(),
        ),
      );

      expect(notifier.disposed, isFalse);

      await tester.pumpWidget(Container());

      expect(notifier.disposed, isTrue);
    });
  });
}

class BaseUrl {
  const BaseUrl(this.value);

  final String value;
}

abstract class ApiInterface {
  String get baseUrl;
}

class ApiImplementation implements ApiInterface {
  ApiImplementation({required BaseUrl baseUrl}) : _baseUrl = baseUrl.value;

  final String _baseUrl;

  @override
  String get baseUrl => _baseUrl;
}

class PositionalApiImplementation implements ApiInterface {
  PositionalApiImplementation(BaseUrl baseUrl) : _baseUrl = baseUrl.value;

  final String _baseUrl;

  @override
  String get baseUrl => _baseUrl;
}

class UserNotifier extends ChangeNotifier {
  UserNotifier({required this.api});

  final ApiInterface api;

  int counter = 0;

  void increment() {
    counter++;
    notifyListeners();
  }
}

class SimpleNotifier extends ChangeNotifier {
  int counter = 0;

  void increment() {
    counter++;
    notifyListeners();
  }
}

class DisposableNotifier extends ChangeNotifier {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

ApiInterface _legacyReaderApiFactory(ScopedReader reader) {
  return ApiImplementation(baseUrl: reader());
}

ApiInterface _legacyDynamicApiFactory(dynamic reader) {
  return ApiImplementation(baseUrl: (reader as ScopedReader).get<BaseUrl>());
}

class MissingDependencyRoot {
  MissingDependencyRoot({required this.child});

  final MissingDependencyChild child;
}

class MissingDependencyChild {
  MissingDependencyChild({required this.leaf});

  final MissingDependencyLeaf leaf;
}

class MissingDependencyLeaf {}
