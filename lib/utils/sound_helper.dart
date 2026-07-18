import 'package:flutter/services.dart';

class SoundHelper {
  static const MethodChannel _channel = MethodChannel('com.dhkin_mobiles.sound/play');

  /// Triggers a pleasant native success chime/sound.
  static Future<void> playSuccess() async {
    try {
      await _channel.invokeMethod('playSuccessSound');
    } catch (e) {
      // Fail silent to prevent UI crash in mock/unsupported environments
      // ignore: avoid_print
      print('Sound playback failed: $e');
    }
  }
}
