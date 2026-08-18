import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/session/pi_session_projection.dart';
import 'package:pi_desktop/src/ui/transcript_pane.dart';

void main() {
  PiTranscriptItem message(Map<String, dynamic> data) =>
      PiTranscriptItem.message(data);

  test(
    'collapses Pi execution trace while retaining conversational replies',
    () {
      expect(
        isIntermediateTranscriptItem(
          message(<String, dynamic>{
            'role': 'assistant',
            'content': <Object>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': 'inspect files',
              },
              <String, dynamic>{'type': 'toolCall', 'name': 'read'},
            ],
          }),
        ),
        isTrue,
      );
      expect(
        isIntermediateTranscriptItem(
          message(<String, dynamic>{
            'role': 'assistant',
            'content': <Object>[
              <String, dynamic>{'type': 'text', 'text': 'Done.'},
            ],
          }),
        ),
        isFalse,
      );
      expect(
        isIntermediateTranscriptItem(
          message(<String, dynamic>{
            'role': 'user',
            'content': <Object>[
              <String, dynamic>{'type': 'text', 'text': 'Continue'},
            ],
          }),
        ),
        isFalse,
      );
    },
  );
}
