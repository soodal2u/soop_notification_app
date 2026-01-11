# Implementation Plan - GitHub Actions 자동 릴리즈 워크플로우 구축

현재 Flutter 프로젝트에서 커밋 및 푸시가 발생했을 때 자동으로 APK를 빌드하고, `pubspec.yaml`의 버전에 맞춰 GitHub Release를 생성하여 APK를 업로드하는 자동화 프로세스를 구축합니다.

## 1. 개요
- **트리거**: `main` 브랜치에 푸시 발생 시 (또는 특정 태그 푸시 시)
- **작업 내용**:
  1. Flutter 환경 설정
  2. `pubspec.yaml`에서 현재 앱 버전 추출
  3. 버전명을 기반으로 릴리즈 태그 및 타이틀 생성
  4. Flutter APK 빌드 (Release 모드)
  5. GitHub Release 생성 및 APK 파일 업로드

## 2. 상세 작업 단계

### 2.1 워크플로우 파일 생성
- `.github/workflows/release.yml` 파일을 생성합니다.
- 빌드 환경은 `ubuntu-latest`를 사용합니다.

### 2.2 버전 자동 추출 로직
- `yq` 또는 커스텀 쉘 스크립트를 사용하여 `pubspec.yaml`에서 `version` 필드를 읽어옵니다.
- 예: `1.1.5+7` -> 태그 `v1.1.5+7` 또는 `v1.1.5`로 사용.

### 2.3 Flutter 빌드
- `subosito/flutter-action`을 사용하여 Flutter를 설치합니다.
- `flutter build apk --release` 명령어를 실행합니다.

### 2.4 릴리즈 생성 및 업로드
- `softprops/action-gh-release` 액션을 사용하여 릴리즈를 생성합니다.
- `assets/changelog.json`에서 최신 변경 사항을 읽어와서 릴리즈 노트에 포함시키는 옵션도 고려합니다.

## 3. Task List
- [ ] `.github/workflows/` 디렉토리 생성
- [ ] `release.yml` 파일 작성 (버전 추출 및 빌드 로직 포함)
- [ ] `assets/changelog.json` 기반 릴리즈 노트 자동 추출 스크립트 검토
- [ ] 워크플로우 작동 테스트 (테스트 푸시 필요)

## 4. 고려 사항
- **권한 설정**: 워크플로우에서 릴리즈를 생성할 수 있도록 `contents: write` 권한이 필요합니다.
- **중복 방지**: 이미 동일한 버전의 태그가 존재하는 경우 릴리즈 생성을 건너뛰거나 업데이트하도록 설정합니다.
- **서명(Signing)**: 현재는 기본적인 release APK를 빌드하며, 정식 마켓 업로드를 위한 서명이 필요한 경우 GitHub Secrets에 키스토어를 등록하는 과정을 추후 추가할 수 있습니다.
