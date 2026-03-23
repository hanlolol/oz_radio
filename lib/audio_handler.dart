import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:oz_radio/models/paragraph.dart'; // 경로 확인 필수

class OzAudioHandler extends BaseAudioHandler {
  final FlutterTts _tts = FlutterTts();
  
  List<Paragraph> _paragraphs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  final double koSpeed = 0.7;
  bool useLiteral = false; 

  final ValueNotifier<String> orderTypeNotifier = ValueNotifier<String>("KO_EN");
  
  final StreamController<Map<String, dynamic>> _playbackStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackStatusStream => _playbackStatusController.stream;

  OzAudioHandler() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setEngine("com.google.android.tts");
  }

  void setParagraphs(List<Paragraph> paragraphs) {
    _paragraphs = paragraphs;
  }

  void updateTranslationMode(bool literal) {
    useLiteral = literal;
  }

  void toggleOrderType() {
    orderTypeNotifier.value = (orderTypeNotifier.value == "EN_KO") ? "KO_EN" : "EN_KO";
  }

  @override
  Future<void> play() async {
    if (_paragraphs.isEmpty) return;
    _isPlaying = true;
    
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [MediaControl.pause, MediaControl.stop],
    ));

    _runSpeechLoop(); 
  }

  Future<void> _runSpeechLoop() async {
    while (_isPlaying) {
      if (_currentIndex >= _paragraphs.length) {
        _currentIndex = 0;
      }

      final p = _paragraphs[_currentIndex];
      final String koText = useLiteral ? p.translationLiteral : p.translationLiterary;

      if (orderTypeNotifier.value == "KO_EN") {
        if (!_isPlaying) break;
        _notifyUI(_currentIndex, "KO");
        await _playTTS(koText, "ko-KR", koSpeed);
        await Future.delayed(Duration(milliseconds: (p.midGap * 1000).toInt()));

        if (!_isPlaying) break;
        _notifyUI(_currentIndex, "EN");
        await _playTTS(p.original, "en-US", p.originalSpeed);
      } else {
        if (!_isPlaying) break;
        _notifyUI(_currentIndex, "EN");
        await _playTTS(p.original, "en-US", p.originalSpeed);
        await Future.delayed(Duration(milliseconds: (p.midGap * 1000).toInt()));

        if (!_isPlaying) break;
        _notifyUI(_currentIndex, "KO");
        await _playTTS(koText, "ko-KR", koSpeed);
      }

      if (!_isPlaying) break;
      await Future.delayed(Duration(milliseconds: (p.postGap * 1000).toInt()));
      _currentIndex++;
    }
  }

  void _notifyUI(int index, String lang) {
    _playbackStatusController.add({"index": index, "lang": lang});
  }

  Future<void> _playTTS(String text, String lang, double speed) async {
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(speed);
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
    _currentIndex = 0;
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    return super.stop();
  }
}