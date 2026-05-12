import 'package:flutter/foundation.dart';

class GlobalAudioPlayer {
  GlobalAudioPlayer._internal();

  static final GlobalAudioPlayer _instance = GlobalAudioPlayer._internal();

  factory GlobalAudioPlayer() => _instance;

  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);

  ValueListenable<bool> get isPlayingListenable => _isPlaying;

  void init() {}

  Future<bool> toggle() async => false;
}
