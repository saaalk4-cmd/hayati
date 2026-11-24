import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/widgets/graphics.dart';

void main() {
  test('شكل السما حسب الوقت', () {
    final d = DateTime(2026, 11, 24);
    SkyPhase at(int h, [int m = 0]) => skyPhaseFor(
      DateTime(2026, 11, 24, h, m),
      fajr: d.add(const Duration(hours: 4, minutes: 50)),
      sunrise: d.add(const Duration(hours: 6, minutes: 20)),
      asr: d.add(const Duration(hours: 14, minutes: 40)),
      maghrib: d.add(const Duration(hours: 16, minutes: 57)),
    );
    expect(at(3), SkyPhase.night);
    expect(at(5), SkyPhase.dawn);
    expect(at(10), SkyPhase.day);
    expect(at(16), SkyPhase.sunset);
    expect(at(17, 10), SkyPhase.sunset);
    expect(at(20), SkyPhase.night);
  });
}
