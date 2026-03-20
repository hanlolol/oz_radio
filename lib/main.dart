import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';

// 주의: 실제 프로젝트 경로에 맞게 import를 활성화해주세요.
import 'package:oz_radio/models/chapter_models.dart'; 

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
  List<Paragraph> _paragraphs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;

  // 기획 반영: 번역 스타일 상태 변수 ('literary' 또는 'literal')
  String _translationStyle = 'literary';

  // Config 제어 변수
  double _enSpeed = 0.5;
  double _koSpeed = 0.7;
  int _pauseShort = 800; 
  int _pauseLong = 1100; 
  String _orderType = "KO_EN"; 

  @override
  void initState() {
    super.initState();
    _setupAudioSession(); 
    _initTts();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadConfig();     
    await _loadChapterData(); 
  }

  Future<void> _loadConfig() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/playback_config.json');
      final configData = json.decode(configString);
      setState(() {
        _enSpeed = (configData['en_speed'] ?? 0.5).toDouble();
        _koSpeed = (configData['ko_speed'] ?? 0.7).toDouble();
        _pauseShort = configData['pause_short_ms'] ?? 800;
        _pauseLong = configData['pause_long_ms'] ?? 1100;
        _orderType = configData['order_type'] ?? "KO_EN";
      });
    } catch (e) {
      debugPrint("Config load error: $e");
    }
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true); 
    if (!mounted) return;
    if (Theme.of(context).platform == TargetPlatform.android) {
      await _tts.setEngine("com.google.android.tts");
    }
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
      final chapter = Chapter.fromJson(data);
      setState(() { 
        _paragraphs = chapter.content; 
      });
    } catch (e) {
      debugPrint("Data load error: $e");
    }
  }

  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) return;
    setState(() => _isPlaying = true);
    
    while (_isPlaying) {
      final paragraph = _paragraphs[_currentIndex];
      
      // [핵심 로직] 문단이 시작될 때의 번역 모드를 캡처합니다.
      // 이렇게 하면 중간에 토글을 바꿔도 현재 문단은 끝까지 캡처된 모드로 재생되고, 
      // 다음 문단 루프가 시작될 때 새로운 모드가 반영됩니다.
      final String activeStyleForThisParagraph = _translationStyle;

      for (var s in paragraph.sentences) {
        if (!_isPlaying) break;

        // 캡처된 모드에 따라 읽어줄 텍스트 결정
        String targetTranslation = activeStyleForThisParagraph == 'literary' 
            ? s.translationLiterary 
            : s.translationLiteral;

        if (_orderType == "KO_EN") {
          await _playTranslation(targetTranslation);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playOriginal(s.original);
        } else {
          await _playOriginal(s.original);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));
          await _playTranslation(targetTranslation);
        }

        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseLong));
      }

      if (!_isPlaying) break;

      setState(() {
        _currentIndex = (_currentIndex + 1) % _paragraphs.length;
      });
    }
  }

  Future<void> _playOriginal(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_enSpeed); 
    await _tts.speak(text);
  }

  Future<void> _playTranslation(String text) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(_koSpeed); 
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
          TextButton.icon(
            onPressed: () => setState(() => _orderType = (_orderType == "EN_KO") ? "KO_EN" : "EN_KO"),
            icon: const Icon(Icons.swap_vert),
            label: Text(_orderType),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 30.0),
          child: Column(
            children: [
              const Text("The Wizard of Oz", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Chapter 1: The Cyclone", style: TextStyle(color: Colors.grey)),
              
              const SizedBox(height: 30),
              
              // [신규 UI] 문학형 / 직역형 실시간 토글 버튼
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'literary', label: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('문학형 (의역)'))),
                  ButtonSegment(value: 'literal', label: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('직역형 (끊어읽기)'))),
                ],
                selected: {_translationStyle},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _translationStyle = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: Colors.brown,
                ),
              ),

              const SizedBox(height: 30),
              
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
              
              const SizedBox(height: 40),
              FloatingActionButton.large(
                onPressed: _isPlaying ? _stopRadio : _startRadio,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              
              const SizedBox(height: 50),
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