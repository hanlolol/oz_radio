import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';

void main() => runApp(const OzRadioApp());

class OzRadioApp extends StatelessWidget {
  const OzRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.brown,
      ),
      home: const RadioModeScreen(),
    );
  }
}

class RadioModeScreen extends StatefulWidget {
  const RadioModeScreen({super.key});

  @override
  State<RadioModeScreen> createState() => _RadioModeScreenState();
}

class _RadioModeScreenState extends State<RadioModeScreen> {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _paragraphs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  // Config 제어 변수 (초기값)
  double _enSpeed = 0.5;
  double _koSpeed = 0.7;
  int _pauseShort = 800; // 문장 내 언어 전환 무음 [cite: 45, 57]
  int _pauseLong = 1100; // 문장 간 간격 무음 
  String _orderType = "KO_EN"; // 기본 재생 순서: 번역 -> 원문 (사용자 제안 반영)

  @override
  void initState() {
    super.initState();
    _setupAudioSession(); // 백그라운드 청취 설정 [cite: 39]
    _initTts();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadConfig();     
    await _loadChapterData(); // 문장 단위로 쪼개진 신규 데이터 로드 [cite: 63]
  }

  Future<void> _loadConfig() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/playback_config.json');
      final configData = json.decode(configString);
      setState(() {
        _enSpeed = configData['en_speed'] ?? 0.5;
        _koSpeed = configData['ko_speed'] ?? 0.7;
        _pauseShort = configData['pause_short_ms'] ?? 800;
        _pauseLong = configData['pause_long_ms'] ?? 1100;
        _orderType = configData['order_type'] ?? "KO_EN";
      });
    } catch (e) {
      debugPrint("Config load error: $e");
    }
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true); // 자연스러운 흐름을 위해 완료 대기 필수 [cite: 33]
    if (!mounted) return;
    if (Theme.of(context).platform == TargetPlatform.android) {
      await _tts.setEngine("com.google.android.tts");
    }
    await _tts.setLanguage("en-US");
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  Future<void> _loadChapterData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/book1/chapter1.json');
      final data = json.decode(response);
      setState(() { 
        _paragraphs = data['content']; 
      });
    } catch (e) {
      debugPrint("Data load error: $e");
    }
  }

  // [핵심] 이중 루프 구조의 재생 로직: 문단 -> 문장 교차 재생 [cite: 32, 43]
  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) return;
    setState(() => _isPlaying = true);
    
    while (_isPlaying) {
      final paragraph = _paragraphs[_currentIndex];
      final List<dynamic> sentences = paragraph['sentences']; // 문단 내 문장 배열 추출

      for (var s in sentences) {
        if (!_isPlaying) break;

        // 사용자의 재생 순서 설정에 따른 분기 [cite: 29]
        if (_orderType == "KO_EN") {
          // 패턴 A: 번역 문장 -> 무음 -> 원문 문장
          await _playTranslation(s['translation']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playOriginal(s['original']);
        } else {
          // 패턴 B: 원문 문장 -> 무음 -> 번역 문장
          await _playOriginal(s['original']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playTranslation(s['translation']);
        }

        // 문장과 문장 사이의 호흡 (다음 문장으로 넘어가기 전 무음) [cite: 54]
        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseLong));
      }

      if (!_isPlaying) break;

      // 문단 전체 종료 후 다음 문단으로 이동 및 챕터 반복 [cite: 37, 48]
      setState(() {
        _currentIndex = (_currentIndex + 1) % _paragraphs.length;
      });
    }
  }

  // 개별 문장 재생 함수 (재사용성 강화) 
  Future<void> _playOriginal(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_enSpeed); // 학습용 속도 적용 (0.9~0.95x 타겟) [cite: 35, 53]
    await _tts.speak(text);
  }

  Future<void> _playTranslation(String text) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(_koSpeed); // 기본 속도 적용 (1.0x 타겟) [cite: 36, 53]
    await _tts.speak(text);
  }

  void _stopRadio() {
    setState(() => _isPlaying = false);
    _tts.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OZ Radio MVP"),
        actions: [
          // 실시간 재생 순서 교체 토글
          TextButton.icon(
            onPressed: () => setState(() => _orderType = (_orderType == "EN_KO") ? "KO_EN" : "EN_KO"),
            icon: const Icon(Icons.swap_vert),
            label: Text(_orderType),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
          child: Column(
            children: [
              const Text("The Wizard of Oz", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Chapter 1: The Cyclone", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              
              // 현재 문단 번호 표시 (라디오 모드 UX) [cite: 25, 40]
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.1), 
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "${_currentIndex + 1}",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
              ),
              
              const SizedBox(height: 50),
              // 메인 재생/정지 버튼 [cite: 26, 32]
              FloatingActionButton.large(
                onPressed: _isPlaying ? _stopRadio : _startRadio,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              
              const SizedBox(height: 60),
              // 실시간 속도 조절 슬라이더
              _buildSpeedSlider("영어 원문 속도", _enSpeed, (v) => setState(() => _enSpeed = v)),
              const SizedBox(height: 20),
              _buildSpeedSlider("한국어 번역 속도", _koSpeed, (v) => setState(() => _koSpeed = v)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedSlider(String label, double currentVal, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("${(currentVal * 2).toStringAsFixed(1)}x"),
          ],
        ),
        Slider(
          value: currentVal,
          min: 0.1, max: 1.0,
          divisions: 18,
          activeColor: Colors.brown,
          inactiveColor: Colors.brown.withValues(alpha: 0.2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}