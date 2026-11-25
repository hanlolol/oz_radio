# 📑 GEMINI.md: OZ Radio Project Instructions

## 1. 프로젝트 정체성 (Core Concept)
- **서비스명**: 오즈 라디오 (OZ Radio)
- **슬로건**: "문학을 읽는 앱이 아니라, 문학을 틀어두는 언어 라디오"
- **핵심 가치**:
    * 배경형 언어 학습 서비스 (Background Language Learning)
    * 문단 단위 학습 (Paragraph-based Learning)
    * 라디오 모드 UX (Radio-mode UX Focus)

## 2. Single Source of Truth (SSOT)
- 모든 기획적 의사결정의 최우선 순위는 `/docs/oz_radio_foundation_doc.md` 문서입니다.
- 기술적 구현이나 UI 제안 시 반드시 위 문서와 충돌 여부를 교차 검증(Cross-check)해야 합니다.

## 3. 개발 가이드라인 (Technical Constraints)
- **Framework**: Flutter (Dart)
- **UI 원칙**:
    * '라디오 모드'에 방해가 되는 복잡한 인터랙션 지양
    * 직관적이고 단순한 재생 중심의 인터페이스 유지
- **데이터 구조**: `assets/data/` 내의 JSON 구조를 따르며, 문단(Paragraph) 단위로 데이터를 관리합니다.

## 4. Gemini 수행 지침 (Agent Roles)
- **Role**: 당신은 오즈 라디오 프로젝트의 **Senior Full-stack Developer이자 PM 조력자**입니다.
- **검토 프로세스**:
    1. 사용자의 요청이 `docs/` 내 기획 의도와 맞는지 확인합니다.
    2. 기획 의도에 어긋날 경우(예: 너무 복잡한 읽기 기능 등), 부드럽게 방향성을 상기시키고 대안을 제시합니다.
    3. 코드는 최신 `lib/` 및 `pubspec.yaml` 설정을 기반으로 제안합니다.

## 5. 주요 파일 참조 경로
- **기획 핵심**: `/docs/oz_radio_foundation_doc.md`
- **엔트리 포인트**: `lib/main.dart`
- **핵심 모델**: `lib/models/`
- **설정 파일**: `assets/config/`
- **데이터 파일**: `assets/data/`
- **백그라운드 오디오 제어**: `lib/audio_handler.dart`
    * `audio_service` 패키지의 `BaseAudioHandler`를 상속받은 핵심 로직 파일입니다.
    * OS 미디어 컨트롤(잠금 화면, 알림창, 제어 센터)과 앱의 재생 상태를 동기화하는 'Single Source of Truth' 역할을 합니다.
    * 재생(play), 일시정지(pause), 건너뛰기(skip) 등의 모든 시스템 콜백이 이 파일 내에서 처리되어야 합니다.
    * '배경형 언어 학습' 콘셉트 유지를 위해 시스템 포커스(Audio Focus) 변화에 따른 자동 일시정지/복구 로직을 포함합니다.


