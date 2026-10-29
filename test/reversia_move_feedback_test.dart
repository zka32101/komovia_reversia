import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_reversia/utils/reversia_move_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int callCount;

  void setHandler() {
    callCount = 0;
    for (final channel in [SystemChannels.platform]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        callCount++;
        return null;
      });
    }
  }

  tearDown(() {
    reversiaFeedbackEnabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('plays feedback through the platform channel when enabled', () async {
    setHandler();
    reversiaFeedbackEnabled = true;

    playReversiaMovePlaceFeedback();
    playReversiaCaptureFeedback();
    playReversiaIllegalMoveFeedback();

    expect(callCount, greaterThan(0));
  });

  test('does nothing on the platform channel when disabled', () async {
    setHandler();
    reversiaFeedbackEnabled = false;

    playReversiaMovePlaceFeedback();
    playReversiaCaptureFeedback();
    playReversiaIllegalMoveFeedback();

    expect(callCount, 0);
  });
}
