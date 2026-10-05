import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('unit_system');
  });

  test('without a saved choice, follows the region default', () {
    expect(WeightUnitProvider().isMetric, WeightUnitProvider.localeDefaultIsMetric());
  });

  test('a saved choice wins over the region default', () async {
    await StorageService().put('unit_system', 'imperial');
    expect(WeightUnitProvider().isMetric, isFalse);
    await StorageService().put('unit_system', 'metric');
    expect(WeightUnitProvider().isMetric, isTrue);
  });

  test('setMetric saves the choice and notifies once per change', () {
    final units = WeightUnitProvider()..setMetric(true);
    var notified = 0;
    units.addListener(() => notified++);

    units.setMetric(false);
    expect(units.isMetric, isFalse);
    expect(StorageService().get('unit_system'), 'imperial');
    expect(notified, 1);

    units.setMetric(false); // no change
    expect(notified, 1);

    units.toggleUnit();
    expect(units.isMetric, isTrue);
    expect(StorageService().get('unit_system'), 'metric');
    expect(notified, 2);

    // The next launch starts from the saved choice.
    expect(WeightUnitProvider().isMetric, isTrue);
  });

  test('metric shows kg and grams, unchanged', () {
    final units = WeightUnitProvider()..setMetric(true);
    expect(units.unitLabel, 'kg');
    expect(units.foodUnit, 'g');
    expect(units.isKg, isTrue);
    expect(units.convertFromKg(80), 80);
    expect(units.convertToKg(80), 80);
  });

  test('imperial shows lbs and ounces, converting from kg', () {
    final units = WeightUnitProvider()..setMetric(false);
    expect(units.unitLabel, 'lbs');
    expect(units.foodUnit, 'oz');
    expect(units.isKg, isFalse);
    expect(units.convertFromKg(100), closeTo(220.462, 0.001));
    expect(units.convertToKg(220.462), closeTo(100, 0.001));
    expect(units.convertToKg(units.convertFromKg(72.5)), closeTo(72.5, 1e-9));
  });
}
