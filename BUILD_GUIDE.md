# APK 릴리즈 빌드 가이드 (APK Release Build Guide)

이 문서는 SOOP 방송 알리미 앱의 APK 릴리즈 빌드 절차를 설명합니다.

## 사전 요구사항 (Prerequisites)

1. Flutter SDK 설치 (Flutter SDK 3.10.4 이상)
2. Android SDK 설치
3. Java JDK 17 설치

## 빌드 절차 (Build Steps)

### 1. 의존성 설치 (Install Dependencies)

```bash
flutter pub get
```

### 2. 코드 분석 (Analyze Code)

빌드 전 코드에 문제가 없는지 확인합니다:

```bash
flutter analyze
```

### 3. APK 빌드 (Build APK)

#### 릴리즈 APK 빌드 (Release APK)

```bash
flutter build apk --release
```

빌드된 APK 파일 위치:
- `build/app/outputs/flutter-apk/app-release.apk`

#### 빌드 크기 최적화 (Build with Size Optimization)

```bash
flutter build apk --release --split-per-abi
```

이 옵션을 사용하면 각 CPU 아키텍처별로 별도의 APK가 생성됩니다:
- `app-armeabi-v7a-release.apk` (32비트 ARM)
- `app-arm64-v8a-release.apk` (64비트 ARM)
- `app-x86_64-release.apk` (64비트 Intel)

### 4. APK 테스트 (Test APK)

빌드된 APK를 실제 Android 기기에 설치하여 테스트합니다:

```bash
flutter install --release
```

또는 adb를 직접 사용:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 릴리즈 체크리스트 (Release Checklist)

- [ ] pubspec.yaml에서 버전 번호 업데이트
- [ ] version.json 파일 업데이트
- [ ] assets/changelog.json 파일 업데이트
- [ ] 코드 분석 통과 (`flutter analyze`)
- [ ] APK 빌드 성공
- [ ] 실제 기기에서 테스트 완료
- [ ] GitHub에 태그 생성 (예: v1.1.5)
- [ ] GitHub Release 생성
- [ ] APK 파일 업로드

## 버전 관리 (Version Management)

### 버전 번호 형식

`major.minor.patch+buildNumber`

예: `1.1.5+7`
- major: 1 (주요 변경)
- minor: 1 (기능 추가)
- patch: 5 (버그 수정)
- buildNumber: 7 (빌드 번호)

### 업데이트해야 할 파일들

1. **pubspec.yaml**
   ```yaml
   version: 1.1.5+7
   ```

2. **version.json**
   ```json
   {
       "version": "1.1.5",
       "buildNumber": 7,
       "downloadUrl": "https://github.com/soodal2u/soop_notification_app/releases/download/v1.1.5/app-release.apk",
       "releaseNotes": "버그 수정 내용...",
       "forceUpdate": false
   }
   ```

3. **assets/changelog.json**
   ```json
   [
       {
           "version": "1.1.5",
           "date": "2026-01-11",
           "changes": [
               "변경 사항 1",
               "변경 사항 2"
           ]
       },
       ...
   ]
   ```

## GitHub Release 생성 (Creating GitHub Release)

1. GitHub 웹사이트에서 저장소로 이동
2. "Releases" 탭 클릭
3. "Draft a new release" 클릭
4. 태그 생성 (예: v1.1.5)
5. 릴리즈 제목 입력 (예: "v1.1.5 - SOOP 방송 알리미")
6. 릴리즈 노트 작성
7. APK 파일 업로드 (`app-release.apk`)
8. "Publish release" 클릭

## 서명 설정 (Signing Configuration)

현재 빌드는 디버그 키로 서명되어 있습니다. 프로덕션 릴리즈를 위해서는 별도의 서명 키를 생성하고 설정해야 합니다.

### 프로덕션 서명 키 생성 (선택사항)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

서명 설정 방법은 [Flutter 공식 문서](https://docs.flutter.dev/deployment/android#signing-the-app)를 참고하세요.

## 문제 해결 (Troubleshooting)

### 빌드 실패 시

1. Flutter 버전 확인:
   ```bash
   flutter --version
   ```

2. 캐시 클리어:
   ```bash
   flutter clean
   flutter pub get
   ```

3. Android 도구 업데이트:
   ```bash
   flutter doctor
   ```

### APK 설치 실패 시

- 이전 버전의 앱이 설치되어 있다면 삭제 후 재설치
- 서명 키가 다른 경우 앱을 삭제해야 합니다
- "알 수 없는 소스" 설치 허용 필요 (Android 설정)

## 참고 자료 (References)

- [Flutter 빌드 및 릴리즈 가이드](https://docs.flutter.dev/deployment/android)
- [Android 앱 서명](https://developer.android.com/studio/publish/app-signing)
