import 'package:example/main.dart' as example;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpExample(WidgetTester tester) async {
  await tester.pumpWidget(example.buildScopedProviderMasterDetailsApp());
  await tester.pumpAndSettle();
}

String _textByKey(WidgetTester tester, String key) {
  final text = tester.widget<Text>(find.byKey(Key(key)));
  return text.data ?? '';
}

void main() {
  testWidgets('loads master/details and toggles favorite', (tester) async {
    await _pumpExample(tester);

    expect(find.text('ScopedProvider Master/Details'), findsOneWidget);
    expect(find.byKey(const Key('master_item-01')), findsOneWidget);
    expect(find.byKey(const Key('detail_title')), findsOneWidget);
    expect(_textByKey(tester, 'detail_title'), 'Build ScopedProvider sample');
    expect(_textByKey(tester, 'detail_favorite_state'), 'Favorite: No');

    await tester.tap(find.byKey(const Key('toggle_favorite_button')));
    await tester.pumpAndSettle();

    expect(_textByKey(tester, 'detail_favorite_state'), 'Favorite: Yes');
    expect(
      find.descendant(
        of: find.byKey(const Key('master_item-01')),
        matching: find.byIcon(Icons.star),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selects a different master item and shows details', (
    tester,
  ) async {
    await _pumpExample(tester);

    await tester.tap(find.byKey(const Key('master_item-03')));
    await tester.pumpAndSettle();

    expect(_textByKey(tester, 'detail_title'), 'Investigate flaky tests');
    expect(
      _textByKey(tester, 'detail_description'),
      contains('intermittent logs'),
    );
    expect(_textByKey(tester, 'detail_status'), 'Status: Investigating');
  });

  test('test coverage', () {
    const example.ScopedProviderMasterDetailsApp();
    const example.WorkItemsPage();
  });
}
