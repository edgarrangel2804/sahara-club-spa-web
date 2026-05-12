import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../config/web_media_paths.dart';

class GlobalAudioPlayer {
  GlobalAudioPlayer._internal();

  static final GlobalAudioPlayer _instance = GlobalAudioPlayer._internal();

  factory GlobalAudioPlayer() => _instance;

  html.AudioElement? _audio;
  bool _initialized = false;
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  bool _autoBindRegistered = false;

  ValueListenable<bool> get isPlayingListenable => _isPlaying;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _audio = html.AudioElement()
      ..src = kBackgroundMusicWebUrl
      ..loop = true
      ..autoplay = false
      ..preload = 'auto'
      ..volume = 0.25;

    _audio?.onPlay.listen((_) => _isPlaying.value = true);
    _audio?.onPause.listen((_) => _isPlaying.value = false);
    _audio?.onEnded.listen((_) => _isPlaying.value = false);
    _audio?.onError.listen((_) {
      html.window.console.error(
        'Error cargando audio: ${_audio?.error?.code ?? 'unknown'}',
      );
      _isPlaying.value = false;
    });

    _bindAutoplayUnlock();
  }

  Future<bool> toggle() async {
    if (_audio == null) return false;
    try {
      if (_audio!.paused ?? true) {
        await _audio!.play();
        _isPlaying.value = true;
      } else {
        _audio!.pause();
        _isPlaying.value = false;
      }
      return true;
    } catch (err) {
      html.window.console.warn('No se pudo reproducir audio: $err');
      _isPlaying.value = false;
      return false;
    }
  }

  void _bindAutoplayUnlock() {
    if (_autoBindRegistered) return;
    _autoBindRegistered = true;

    late void Function(html.Event) unlockAndPlay;
    unlockAndPlay = (html.Event _) {
      if (_audio == null || !(_audio!.paused ?? true)) {
        _removeUnlockListeners(unlockAndPlay);
        return;
      }

      _audio!.play().then((_) {
        _isPlaying.value = true;
        _removeUnlockListeners(unlockAndPlay);
      }).catchError((err) {
        html.window.console.warn('Autoplay de audio bloqueado: $err');
      });
    };

    html.window.addEventListener('click', unlockAndPlay);
    html.window.addEventListener('touchstart', unlockAndPlay);
    html.window.addEventListener('keydown', unlockAndPlay);
    html.window.addEventListener('scroll', unlockAndPlay);
  }

  void _removeUnlockListeners(void Function(html.Event) listener) {
    html.window.removeEventListener('click', listener);
    html.window.removeEventListener('touchstart', listener);
    html.window.removeEventListener('keydown', listener);
    html.window.removeEventListener('scroll', listener);
  }
}
