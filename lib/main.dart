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
        scaffoldBackgroundColor: const Color(0xFFF9F6F0),
      ),
      home: const RadioModeScreen(),
    );
  }
}

class PlaybackState {
  final int paragraphIndex;
  final int sentenceIndex;
  final String lang;
  
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

  final ValueNotifier<PlaybackState?> _playbackNotifier = ValueNotifier(null);
  final ScrollController _scrollController = ScrollController();

  double _enSpeed = 0.5;
  double _koSpeed = 0.7;
  int _pauseShort = 800;
  int _pauseLong = 1100;
  String _orderType = "KO_EN";
  
  // [추가됨] 번역 모드 상태 변수 (false: 의역, true: 직역)
  bool _useLiteral = false; 

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
      final Map<String, dynamic> data = json.decode(response);
      
      setState(() { 
        if (data.containsKey('paragraphs') && data['paragraphs'] != null) {
          _paragraphs = List<dynamic>.from(data['paragraphs']);
        } else {
          _paragraphs = []; 
        }
      });
    } catch (e) {
      debugPrint("Data load error: $e");
      setState(() => _paragraphs = []);
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

  // [추가됨] 현재 모드에 맞는 번역 텍스트를 반환하는 헬퍼 함수
  String _getCurrentTranslation(dynamic sentenceData) {
    if (_useLiteral && sentenceData['translation_literal'] != null) {
      return sentenceData['translation_literal'];
    }
    return sentenceData['translation_literary'] ?? '';
  }

  Future<void> _startRadio() async {
    if (_paragraphs.isEmpty) return;
    setState(() => _isPlaying = true);
    
    int currentPIndex = _playbackNotifier.value?.paragraphIndex ?? 0;
    
    while (_isPlaying) {
      if (currentPIndex >= _paragraphs.length) {
        currentPIndex = 0;
      }

      _scrollToActiveParagraph(currentPIndex);

      final paragraph = _paragraphs[currentPIndex];
      final List<dynamic> sentences = paragraph['sentences'];

      for (int sIndex = 0; sIndex < sentences.length; sIndex++) {
        var s = sentences[sIndex];
        if (!_isPlaying) break;
        
        // 현재 설정된 모드(의역/직역)에 따른 텍스트 가져오기
        final currentKoText = _getCurrentTranslation(s);

        if (_orderType == "KO_EN") {
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "KO");
          await _playTranslation(currentKoText); // 동적 텍스트 재생
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));

          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "EN");
          await _playOriginal(s['original_text']);
        } else {
          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "EN");
          await _playOriginal(s['original_text']);
          if (!_isPlaying) break;
          await Future.delayed(Duration(milliseconds: _pauseShort));

          _playbackNotifier.value = PlaybackState(currentPIndex, sIndex, "KO");
          await _playTranslation(currentKoText); // 동적 텍스트 재생
        }

        if (!_isPlaying) break;
        await Future.delayed(Duration(milliseconds: _pauseLong));
      }

      if (!_isPlaying) break;
      currentPIndex++; 
    }
  }

  void _scrollToActiveParagraph(int index) {
    if (!_scrollController.hasClients) return;
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
          // [추가됨] 의역/직역 전환 토글 버튼
          TextButton.icon(
            onPressed: () {
              setState(() {
                _useLiteral = !_useLiteral;
              });
            },
            icon: Icon(_useLiteral ? Icons.translate : Icons.auto_stories),
            label: Text(_useLiteral ? "직역" : "의역"),
            style: TextButton.styleFrom(foregroundColor: Colors.brown[800]),
          ),
          // 기존 재생 순서 토글 버튼
          TextButton.icon(
            onPressed: () => setState(() => _orderType = (_orderType == "EN_KO") ? "KO_EN" : "EN_KO"),
            icon: const Icon(Icons.swap_vert),
            label: Text(_orderType),
            style: TextButton.styleFrom(foregroundColor: Colors.brown[800]),
          )
        ],
      ),
      body: Column(
        children: [
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

                    return ValueListenableBuilder<PlaybackState?>(
                      valueListenable: _playbackNotifier,
                      builder: (context, playState, child) {
                        final isActiveParagraph = (playState?.paragraphIndex == pIndex);

                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 500),
                          opacity: isActiveParagraph ? 1.0 : 0.4, 
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 30),
                            padding: const EdgeInsets.only(left: 15),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: isActiveParagraph ? Colors.brown : Colors.transparent, 
                                  width: 4 
                                )
                              )
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: sentences.asMap().entries.map((entry) {
                                int sIndex = entry.key;
                                var s = entry.value;
                                
                                bool isPlayingEN = isActiveParagraph && playState?.sentenceIndex == sIndex && playState?.lang == "EN";
                                bool isPlayingKO = isActiveParagraph && playState?.sentenceIndex == sIndex && playState?.lang == "KO";

                                // [핵심] 현재 선택된 모드(의역/직역)에 맞춰 화면의 한국어 텍스트도 변경
                                final displayKoText = _getCurrentTranslation(s);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 15.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['original_text'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: isPlayingEN ? FontWeight.bold : FontWeight.normal,
                                          color: isPlayingEN ? Colors.brown[900] : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displayKoText, // 동적으로 직역/의역 텍스트 출력
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
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), 
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