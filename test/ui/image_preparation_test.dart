import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/prompt_bar.dart';

void main() {
  test('bounds image attachments by their longest edge', () {
    expect(imageScaleForMaxDimension(2000, 1000, maxDimension: 1600), 0.8);
    expect(imageScaleForMaxDimension(1000, 2400, maxDimension: 1600), 2 / 3);
    expect(imageScaleForMaxDimension(800, 600, maxDimension: 1600), 2);
  });
}
