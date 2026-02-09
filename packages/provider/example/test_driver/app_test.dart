import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('master/details app', () {
    FlutterDriver? _driver;

    final appBarText = find.text('ScopedProvider Master/Details');
    final detailTitle = find.byValueKey('detail_title');
    final toggleFavoriteButton = find.byValueKey('toggle_favorite_button');
    final favoriteState = find.byValueKey('detail_favorite_state');

    /// connect to [FlutterDriver]
    setUpAll(() async {
      _driver = await FlutterDriver.connect();
    });

    /// close the driver
    tearDownAll(() async {
      await _driver?.close();
    });

    test('AppBar renders expected title', () async {
      expect(
        await _driver!.getText(appBarText),
        'ScopedProvider Master/Details',
      );
    });

    test('first details item is selected by default', () async {
      expect(
        await _driver!.getText(detailTitle),
        'Build ScopedProvider sample',
      );
      expect(await _driver!.getText(favoriteState), 'Favorite: No');
    });

    test('toggle favorite updates details state', () async {
      await _driver!.tap(toggleFavoriteButton);
      expect(await _driver!.getText(favoriteState), 'Favorite: Yes');
    });
  });
}
