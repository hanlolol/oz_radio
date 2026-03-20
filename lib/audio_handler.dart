import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OzAudioHandler extends BaseAudioHandler {
  final FlutterTts _tts = FlutterTts();
  
  // 데이터 및 상태 변수
  List<dynamic> _paragraphs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  // 설정값 (main.dart의 슬라이더와 연동)
  double enSpeed = 0.5;
  double koSpeed = 0.7;
  int _pauseShort = 800;
  int _pauseLong = 1100;

  // [핵심] UI와 통신하기 위한 Notifier 및 Stream
  final ValueNotifier<String> orderTypeNotifier = ValueNotifier<String>("KO_EN");
  final StreamController<int> _currentIndexController = StreamController<int>.broadcast();
  Stream<int> get currentIndexStream => _currentIndexController.stream;

  OzAudioHandler() {
    _initTts();
  }

  void _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("en-US");
  }

  // [수정] main.dart에서 호출하는 데이터 설정 메서드
  void setParagraphs(List<dynamic> paragraphs) {
    _paragraphs = paragraphs;
  }

  // [수정] main.dart에서 호출하는 설정 업데이트 메서드
  void updateConfig(Map<String, dynamic> config) {
    enSpeed = config['en_speed'] ?? 0.5;
    koSpeed = config['ko_speed'] ?? 0.7;
    _pauseShort = config['pause_short_ms'] ?? 800;
    _pauseLong = config['pause_long_ms'] ?? 1100;
    orderTypeNotifier.value = config['order_type'] ?? "KO_EN";
  }

  // [수정] 재생 순서 변경 메서드
  void toggleOrderType() {
    orderTypeNotifier.value = (orderTypeNotifier.value == "EN_KO") ? "KO_EN" : "EN_KO";
  }

  @override
  Future<void> play() async {
    if (_paragraphs.isEmpty) return;
    _isPlaying = true;
    
    // 시스템 알림창 상태 업데이트
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause, MediaControl.stop],
    ));

    _runSpeechLoop(); // 백그라운드 재생 루프 시작
  }

  // [기존 main.dart의 로직이 이쪽으로 이관되었습니다]
  Future<void> _runSpeechLoop() async {
    while (_isPlaying) {
      final paragraph = _paragraphs[_currentIndex];
      final List<dynamic> sentences = paragraph['sentences'];

      // 현재 문단 번호를 UI로 전송
      _currentIndexController.add(_currentIndex);

      for (var s in sentences) {
        if (!_isPlaying) break;

        if (orderTypeNotifier.value == "KO_EN") {
          await _playTranslation(s['translation']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playOriginal(s['original']);
        } else {
          await _playOriginal(s['original']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playTranslation(s['translation']);
        }

        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseLong));
      }

      if (!_isPlaying) break;
      _currentIndex = (_currentIndex + 1) % _paragraphs.length;
    }
  }

  Future<void> _playOriginal(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(enSpeed);
    await _tts.speak(text);
  }

  Future<void> _playTranslation(String text) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(koSpeed);
    await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    await _tts.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play, MediaControl.stop],
    ));
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    await _tts.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    return super.stop();
  }
}