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
        scaffoldBackgroundColor: const Color(0xFFF9F6F0), // 라디오 느낌의 따뜻한 배경색
      ),
      home: const RadioModeScreen(),
    );
  }
}

// --- 현재 재생 상태를 추적하는 데이터 모델 ---
class PlaybackState {
  final int paragraphIndex;
  final int sentenceIndex;
  final String lang; // "EN" or "KO"
  
  PlaybackState(this.paragraphIndex, this.sentenceIndex, this.lang);
}

class RadioModeScreen extends StatefulWidget {
  const RadioModeScreen({super.key});

  @override
  State<RadioModeScreen> createState() => _RadioModeScreenState();
}

class _RadioModeScreenState extends State<RadioModeScreen> {
  final FlutterTts _tts = FlutterTts();
  List<dynamic> _paragraphs = [];
  bool _isPlaying = false;

  // 상태 관리: 재생 중인 위치 정보 (ValueNotifier로 국소 리빌드 최적화)
  final ValueNotifier<PlaybackState?> _playbackNotifier = ValueNotifier(null);
  
  // 스크롤 제어: 자동 스크롤을 위한 컨트롤러
  final ScrollController _scrollController = ScrollController();

  // Config 제어 변수 (초기값)
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

  @override
  void dispose() {
    _tts.stop();
    _playbackNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 데이터 로드 로직
  Future<void> _loadAllData() async {
    await _loadConfig();     
    await _loadChapterData();
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

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
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

  // [핵심] 재생 로직 및 상태 업데이트 동기화
  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) return;
    setState(() => _isPlaying = true);
    
    // 이전에 멈춘 문단이 있다면 그곳부터, 없으면 0부터 시작
    int currentPIndex = _playbackNotifier.value?.paragraphIndex ?? 0;
    
    while (_isPlaying) {
      if (currentPIndex >= _paragraphs.length) {
        currentPIndex = 0; // 챕터 루프
      }

      // 1. 재생 시작 시 해당 문단으로 자동 스크롤 애니메이션
      _scrollToActiveParagraph(currentPIndex);

      final paragraph = _paragraphs[currentPIndex];
      final List<dynamic> sentences = paragraph['sentences'];

      for (int sIndex = 0; sIndex < sentences.length; sIndex++) {
        var s = sentences[sIndex];
        if (!_isPlaying) break;

        if (_orderType == "KO_EN") {
          // 상태 업데이트: 한국어 번역문 재생
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "KO");
          await _playTranslation(s['translation']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));

          // 상태 업데이트: 영어 원문 재생
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "EN");
          await _playOriginal(s['original']);
        } else {
          // 상태 업데이트: 영어 원문 재생
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "EN");
          await _playOriginal(s['original']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));

          // 상태 업데이트: 한국어 번역문 재생
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "KO");
          await _playTranslation(s['translation']);
        }

        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseLong));
      }

      if (!_isPlaying) break;
      currentPIndex++; // 다음 문단으로 이동
    }
  }

  // 자동 스크롤 함수
  void _scrollToActiveParagraph(int index) {
    if (!_scrollController.hasClients) return;
    // 대략적인 문단 높이(200.0)를 기준으로 스크롤
    final double targetOffset = index * 200.0; 
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
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
        title: const Text("OZ Radio", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _orderType = (_orderType == "EN_KO") ? "KO_EN" : "EN_KO"),
            icon: const Icon(Icons.swap_vert),
            label: Text(_orderType),
          )
        ],
      ),
      body: Column(
        children: [
          // 본문 영역 (ListView)
          Expanded(
            child: _paragraphs.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  itemCount: _paragraphs.length,
                  itemBuilder: (context, pIndex) {
                    final paragraph = _paragraphs[pIndex];
                    final List<dynamic> sentences = paragraph['sentences'];

                    // [핵심] ValueListenableBuilder를 통한 국소 렌더링
                    return ValueListenableBuilder<PlaybackState?>(
                      valueListenable: _playbackNotifier,
                      builder: (context, playState, child) {
                        final isActiveParagraph = (playState?.paragraphIndex == pIndex);

                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 500),
                          opacity: isActiveParagraph ? 1.0 : 0.4, // 비활성 문단 Dim 처리
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 30),
                            padding: const EdgeInsets.only(left: 15),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isActiveParagraph ? Colors.brown : Colors.transparent, 
                                  width: 4 // 활성 문단 좌측 인디케이터 바
                                )
                              )
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: sentences.asMap().entries.map((entry) {
                                int sIndex = entry.key;
                                var s = entry.value;
                                
                                // 활성 문단 내에서 현재 재생 중인 문장/언어 추적
                                bool isPlayingEN = isActiveParagraph && playState?.sentenceIndex == sIndex && playState?.lang == "EN";
                                bool isPlayingKO = isActiveParagraph && playState?.sentenceIndex == sIndex && playState?.lang == "KO";

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 15.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['original'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: isPlayingEN ? FontWeight.bold : FontWeight.normal,
                                          color: isPlayingEN ? Colors.brown[900] : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s['translation'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isPlayingKO ? FontWeight.bold : FontWeight.normal,
                                          color: isPlayingKO ? Colors.brown[600] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
          
          // 하단 컨트롤러 영역 (고정)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), // 최신 버전에 맞게 수정된 부분
                  blurRadius: 10, 
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: _isPlaying ? _stopRadio : _startRadio,
                  elevation: 0,
                  child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}