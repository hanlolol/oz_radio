import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'audio_handler.dart'; // 3단계에서 생성할 핸들러 파일

// 전역 오디오 핸들러 인스턴스
late OzAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [수정] 오디오 서비스 초기화 (Line 7 대응)
  _audioHandler = await AudioService.init(
    builder: () => OzAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.oz_radio.channel.audio',
      androidNotificationChannelName: '오즈 라디오 재생',
      androidStopForegroundOnPause: true,
      notificationColor: Colors.brown,
    ),
  );

  runApp(const OzRadioApp());
}

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
  // [수정] 기존 _tts, _isPlaying 변수 제거 (Line 42, 45 대응)
  // 재생 로직은 핸들러가 담당하며 UI는 핸들러의 상태를 구독합니다.

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // 설정값과 데이터를 로드하여 핸들러에 전달
    await _loadConfig();
    await _loadChapterData();
  }

  Future<void> _loadConfig() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/playback_config.json');
      final configData = json.decode(configString);
      
      // 핸들러의 설정값 업데이트
      _audioHandler.updateConfig(configData);
      setState(() {}); 
    } catch (e) {
      debugPrint("Config load error: $e");
    }
  }

  Future<void> _loadChapterData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/book1/chapter1.json');
      final data = json.decode(response);
      
      // 핸들러에 재생할 문단 데이터 전달
      _audioHandler.setParagraphs(data['content']);
    } catch (e) {
      debugPrint("Data load error: $e");
    }
  }

  // [수정] 재생/정지 제어 함수 (Line 101~151 로직 이관)
  void _handlePlayback() {
    final bool playing = _audioHandler.playbackState.value.playing;
    if (playing) {
      _audioHandler.pause();
      WakelockPlus.disable(); // 정지 시 화면 꺼짐 방지 해제
    } else {
      _audioHandler.play();
      WakelockPlus.enable();  // 재생 시 CPU/화면 유지 (Doze 모드 대응)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OZ Radio MVP"),
        actions: [
          // 재생 순서 토글
          ValueListenableBuilder<String>(
            valueListenable: _audioHandler.orderTypeNotifier,
            builder: (context, orderType, _) {
              return TextButton.icon(
                onPressed: () => _audioHandler.toggleOrderType(),
                icon: const Icon(Icons.swap_vert),
                label: Text(orderType),
              );
            },
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
              
              // [수정] 현재 문단 번호 표시 (핸들러의 커스텀 상태 구독)
              StreamBuilder<int>(
                stream: _audioHandler.currentIndexStream,
                builder: (context, snapshot) {
                  final index = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.brown.withValues(alpha: 0.1), 
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                  );
                }
              ),
              
              const SizedBox(height: 50),
              
              // [수정] 메인 재생/정지 버튼 (StreamBuilder 적용)
              StreamBuilder<PlaybackState>(
                stream: _audioHandler.playbackState,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return FloatingActionButton.large(
                    onPressed: _handlePlayback,
                    child: Icon(playing ? Icons.pause : Icons.play_arrow),
                  );
                },
              ),
              
              const SizedBox(height: 60),
              // 속도 조절 슬라이더 (핸들러의 설정값 변경)
              _buildSpeedSlider("영어 원문 속도", _audioHandler.enSpeed, (v) {
                setState(() => _audioHandler.enSpeed = v);
              }),
              const SizedBox(height: 20),
              _buildSpeedSlider("한국어 번역 속도", _audioHandler.koSpeed, (v) {
                setState(() => _audioHandler.koSpeed = v);
              }),
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