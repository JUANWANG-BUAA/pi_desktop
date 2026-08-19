import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/ui/pi_tokens.dart';

void main() {
  test('reading fonts resolve to distinct installed families', () {
    final sans = PiTokens.dark(PiDensity.standard);
    final serif = PiTokens.dark(
      PiDensity.standard,
      readingFont: PiReadingFont.serif,
    );
    final rounded = PiTokens.dark(
      PiDensity.standard,
      readingFont: PiReadingFont.rounded,
    );
    final mono = PiTokens.dark(
      PiDensity.standard,
      readingFont: PiReadingFont.mono,
    );

    expect(sans.reading.fontFamily, isNot(equals(serif.reading.fontFamily)));
    expect(serif.reading.fontFamily, isNot(equals(rounded.reading.fontFamily)));
    expect(sans.control.fontFamily, sans.reading.fontFamily);
    expect(serif.display.fontFamily, serif.reading.fontFamily);
    expect(mono.evidence.fontFamily, mono.reading.fontFamily);
    expect(PiReadingFont.parse('rounded'), PiReadingFont.rounded);
    expect(PiReadingFont.parse('unknown'), PiReadingFont.sans);
  });

  test('token font sizes are not pre-multiplied by textScale', () {
    final tokens = PiTokens.dark(PiDensity.standard, textScale: 1.4);
    expect(tokens.readingSize, 15.5);
    expect(tokens.controlSize, 13.5);
  });
}
