import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';
import 'package:oz_radio/models/paragraph.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
      ),
      home: const RadioModeScreen(),
    );
  }
}

class PlaybackState {
  final int paragraphIndex;
  final String lang;
  PlaybackState(this.paragraphIndex, this.lang);
}

class RadioModeScreen extends StatefulWidget {
  const RadioModeScreen({super.key});

  @override
  State<RadioModeScreen> createState() => _RadioModeScreenState();
}

class _RadioModeScreenState extends State<RadioModeScreen> {
  final FlutterTts _tts = FlutterTts();
  List<Paragraph> _paragraphs = [];
  bool _isPlaying = false;

  final ValueNotifier<PlaybackState?> _playbackNotifier = ValueNotifier(null);
  final ScrollController _scrollController = ScrollController();

  double _enSpeed = 0.45;
  double _koSpeed = 0.55;
  String _orderType = "KO_EN";
  bool _useLiteral = false;

  @override
  void initState() {
    super.initState();
    _setupAudioSession();
    _initTts();
    _loadChapterData();
  }

  @override
  void dispose() {
    _tts.stop();
    _playbackNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/book1/chapter1.json');
      final Map<String, dynamic> data = json.decode(response);
      if (!mounted) return;
      setState(() {
        _paragraphs = (data['paragraphs'] as List)
            .map((p) => Paragraph.fromJson(p))
            .toList();
      });
    } catch (e) {
      debugPrint("❌ Data load error: $e");
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

  // [핵심 로직] 문단 전환 시 스크롤 초기화 포함
  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) return;
    setState(() => _isPlaying = true);
    
    int currentIndex = _playbackNotifier.value?.paragraphIndex ?? 0;

    while (_isPlaying) {
      if (currentIndex >= _paragraphs.length) currentIndex = 0;
      
      final p = _paragraphs[currentIndex];
      final String koText = _useLiteral ? p.translationLiteral : p.translationLiterary;

      // 1. 문단 시작 시 상태 업데이트 (UI에서 리스트가 sublist로 잘림)
      _playbackNotifier.value = PlaybackState(currentIndex, _orderType.startsWith("KO") ? "KO" : "EN");
      
      // 2. [수정] 데이터가 잘린 후 스크롤 위치를 즉시 0(최상단)으로 강제 고정
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      if (_orderType == "KO_EN") {
        if (!_isPlaying) break;
        _playbackNotifier.value = PlaybackState(currentIndex, "KO");
        await _playTTS(koText, "ko-KR", _koSpeed);
        await Future.delayed(Duration(milliseconds: (p.midGap * 1000).toInt()));

        if (!_isPlaying) break;
        _playbackNotifier.value = PlaybackState(currentIndex, "EN");
        await _playTTS(p.original, "en-US", _enSpeed);
      } else {
        if (!_isPlaying) break;
        _playbackNotifier.value = PlaybackState(currentIndex, "EN");
        await _playTTS(p.original, "en-US", _enSpeed);
        await Future.delayed(Duration(milliseconds: (p.midGap * 1000).toInt()));

        if (!_isPlaying) break;
        _playbackNotifier.value = PlaybackState(currentIndex, "KO");
        await _playTTS(koText, "ko-KR", _koSpeed);
      }

      if (!_isPlaying) break;
      await Future.delayed(Duration(milliseconds: (p.postGap * 1000).toInt()));
      currentIndex++;
    }
  }

  Future<void> _playTTS(String text, String lang, double speed) async {
    if (text.isEmpty) return;
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(speed);
    await _tts.speak(text);
  }

  void _stopRadio() {
    setState(() => _isPlaying = false);
    _tts.stop();
  }

  Widget _buildSpeedSlider(String label, double value, Function(double) onChanged) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
              Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Colors.brown)),
            ],
          ),
        ),
        Slider(
          value: value,
          min: 0.1,
          max: 1.0,
          activeColor: Colors.brown,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OZ Radio", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          ChoiceChip(
            label: Text(_useLiteral ? "직역" : "의역"),
            selected: true,
            onSelected: (val) => setState(() => _useLiteral = !_useLiteral),
            selectedColor: Colors.brown[200],
          ),
          const SizedBox(width: 8),
          // [수정] 순서 버튼: 화살표 + 우선순위 언어 표시
          TextButton.icon(
            onPressed: () => setState(() => _orderType = (_orderType == "EN_KO") ? "KO_EN" : "EN_KO"),
            icon: const Icon(Icons.swap_vert, size: 20),
            label: Text(_orderType == "KO_EN" ? "한 ➔ 영" : "영 ➔ 한"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.brown[900],
              backgroundColor: Colors.brown.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ValueListenableBuilder<PlaybackState?>(
        valueListenable: _playbackNotifier,
        builder: (context, state, child) {
          if (_paragraphs.isEmpty) return const Center(child: CircularProgressIndicator());

          // 현재 인덱스 기준으로 이전 데이터 삭제
          int currentIndex = state?.paragraphIndex ?? 0;
          List<Paragraph> visibleParagraphs = _paragraphs.sublist(currentIndex);

          return ListView.builder(
            controller: _scrollController,
            // 🚨 physics를 NeverScrollableScrollPhysics로 설정하면 자동 모드 느낌이 강해지지만,
            // 사용자가 직접 볼 수 있게 BouncingScrollPhysics 정도를 추천합니다.
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            itemCount: visibleParagraphs.length,
            itemBuilder: (context, index) {
              final p = visibleParagraphs[index];
              bool isCurrent = index == 0; 
              bool isEnActive = isCurrent && state?.lang == "EN";
              bool isKoActive = isCurrent && state?.lang == "KO";

              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                margin: const EdgeInsets.only(bottom: 25),
                padding: const EdgeInsets.all(24), // 패딩을 늘려 현재 문단 강조
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isCurrent ? [
                    BoxShadow(
                      color: Colors.brown.withValues(alpha: 0.1), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10)
                    )
                  ] : [],
                  border: Border.all(
                    color: isCurrent ? Colors.brown.withValues(alpha: 0.4) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.original,
                      style: TextStyle(
                        fontSize: 21, // 원문 크기 상향
                        height: 1.6,
                        color: isEnActive ? Colors.brown[900] : Colors.black87.withValues(alpha: isCurrent ? 1.0 : 0.4),
                        fontWeight: isEnActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _useLiteral ? p.translationLiteral : p.translationLiterary,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: isKoActive ? Colors.brown[700] : Colors.grey[600]!.withValues(alpha: isCurrent ? 1.0 : 0.4),
                        fontWeight: isKoActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.only(bottom: 40, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeedSlider("ENGLISH SPEED", _enSpeed, (val) => setState(() => _enSpeed = val)),
            _buildSpeedSlider("KOREAN SPEED", _koSpeed, (val) => setState(() => _koSpeed = val)),
            const SizedBox(height: 15),
            FloatingActionButton.large(
              onPressed: _isPlaying ? _stopRadio : _startRadio,
              elevation: 2,
              backgroundColor: Colors.brown[100],
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.brown[900], size: 40),
            ),
          ],
        ),
      ),
    );
  }
}