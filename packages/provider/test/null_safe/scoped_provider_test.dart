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
              Provide.value(const BaseUrl('https://api.com'), lazy: false),
              Provide.create<ApiInterface>(
                (i) => ApiImplementation(baseUrl: i.get<BaseUrl>()),
              ),
              Provide.notifier<UserNotifier>(
                (i) => UserNotifier(api: i()),
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
              Provide.create<String>((i) => i.get<int>().toString()),
              Provide.value(42),
            ],
            child: TextOf<String>(),
          ),
        ),
      );

      expect(tester.takeException(), isA<ProviderNotFoundException>());
    });

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

class UserNotifier extends ChangeNotifier {
  UserNotifier({required this.api});

  final ApiInterface api;

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
