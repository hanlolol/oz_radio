import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';

// 주의: 실제 경로에 맞게 맞춰주세요.
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

  String _translationStyle = 'literary'; // literary(문학형) or literal(직역형)

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
    // 기기(갤럭시 등) 기본 TTS를 사용하도록 구글 엔진 강제 코드를 제거했습니다.
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
        _paragraphs = chapter.paragraphs; 
      });
      debugPrint("✅ JSON 로드 성공! 총 문단 수: ${_paragraphs.length}");
    } catch (e) {
      debugPrint("🚨 데이터 로드 에러: $e");
    }
  }

  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('데이터를 불러오지 못했습니다. 에셋 설정을 확인해주세요.')),
      );
      return;
    }
    
    setState(() => _isPlaying = true);
    
    while (_isPlaying) {
      final paragraph = _paragraphs[_currentIndex];
      
      // 기획 반영: 문단이 시작될 때의 번역 모드를 캡처합니다.
      final String activeStyle = _translationStyle;
      String targetTranslation = activeStyle == 'literary' 
          ? paragraph.translationLiterary 
          : paragraph.translationLiteral;

      if (_orderType == "KO_EN") {
        await _playTranslation(targetTranslation);
        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseShort));
        await _playOriginal(paragraph.originalText);
      } else {
        await _playOriginal(paragraph.originalText);
        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseShort));
        await _playTranslation(targetTranslation);
      }

      if (!_isPlaying) break;
      await Future.delayed(Duration(milliseconds: _pauseLong));

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
              
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'literary', label: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('문학형'))),
                  ButtonSegment(value: 'literal', label: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('직역형'))),
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