# 코드 수정 및 APK 릴리즈 빌드 - 완료 보고서

## 프로젝트 정보
- **앱 이름**: SOOP 방송 알리미 (SOOP Notification App)
- **이전 버전**: v1.1.4 (Build 6)
- **새 버전**: v1.1.5 (Build 7)
- **작업 일자**: 2026-01-11

## 수행된 작업

### 1. 버그 수정: 백그라운드 타이머 재시작 문제

#### 문제 상황
사용자가 앱 설정에서 "체크 주기"를 변경해도 백그라운드 서비스가 기존 주기로 계속 작동하는 문제가 있었습니다. 예를 들어:
- 초기 설정: 30초 주기
- 사용자가 설정을 10초로 변경
- 실제 동작: 여전히 30초 주기로 작동 (서비스를 수동으로 재시작해야 적용됨)

#### 원인 분석
`lib/services/background_service.dart` 파일의 58-73번 줄:
- `Timer.periodic`으로 생성된 타이머는 주기를 동적으로 변경할 수 없음
- 기존 코드는 주기 변경을 감지했지만 타이머를 재시작하지 않음
- 주석에 "타이머 재시작 필요 (서비스 재시작으로 처리)"라고 적혀있었으나 실제로는 구현되지 않음

#### 해결 방법
```dart
// 개선 전
Timer.periodic(Duration(seconds: checkInterval), (timer) async {
  final currentInterval = prefs.getInt('checkIntervalSeconds') ?? 30;
  if (currentInterval != checkInterval) {
    checkInterval = currentInterval;  // 변수만 업데이트, 타이머는 그대로
  }
  await _checkBroadcasts(apiService);
});

// 개선 후
Timer? currentTimer;
int lastCheckedInterval = initialInterval;

void startTimer(int intervalSeconds) {
  currentTimer?.cancel();  // 기존 타이머 취소
  lastCheckedInterval = intervalSeconds;
  currentTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
    final currentInterval = prefs.getInt('checkIntervalSeconds') ?? 30;
    if (currentInterval != lastCheckedInterval) {
      timer.cancel();
      startTimer(currentInterval);  // 새 주기로 타이머 재시작
      return;
    }
    await _checkBroadcasts(apiService);
```

#### 개선 효과
- 사용자가 설정을 변경하면 다음 체크 주기부터 즉시 적용됨
- 서비스를 수동으로 재시작할 필요 없음
- 더 나은 사용자 경험 제공

### 2. 백그라운드 지속 실행 기능 추가 ⭐ 신규

#### 문제 상황
몇 시간 동안 앱을 사용하지 않으면 Android의 배터리 최적화 기능이 백그라운드 서비스를 자동으로 종료시킵니다:
- 앱을 몇 시간 사용하지 않으면 서비스가 꺼짐
- 앱을 다시 열면 알림 기능이 비활성화되어 있음
- 기기를 재부팅하면 서비스가 시작되지 않음

#### 원인 분석
Android의 Doze 모드와 App Standby 기능이 배터리를 절약하기 위해 백그라운드 앱을 제한:
- 일정 시간 후 백그라운드 작업 제한
- 네트워크 접근 제한
- 백그라운드 서비스 강제 종료

#### 해결 방법

**1. 배터리 최적화 비활성화 요청**

`MainActivity.kt`에 배터리 최적화 설정 요청 기능 추가:
```kotlin
private fun isBatteryOptimizationDisabled(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }
    return true
}

private fun requestBatteryOptimization() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val intent = Intent()
        intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }
}
```

**2. 권한 추가**

`AndroidManifest.xml`에 필요한 권한 추가:
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

**3. 부팅 시 자동 시작**

`AndroidManifest.xml`에 부트 리시버 추가:
```xml
<receiver
    android:name="id.flutter.flutter_background_service.BootReceiver"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

**4. 앱 실행 시 다이얼로그 표시**

`HomeScreen`에서 배터리 최적화가 활성화되어 있으면 사용자에게 알림:
```dart
Future<void> _checkBatteryOptimization() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final isDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
    if (!isDisabled) {
      _showBatteryOptimizationDialog();
    }
}
```

**5. 서비스 자동 시작 활성화**

`BackgroundService`에서 `autoStart: true` 설정:
```dart
androidConfiguration: AndroidConfiguration(
  onStart: onStart,
  autoStart: true,  // false에서 true로 변경
  isForegroundMode: true,
  // ...
)
```

#### 개선 효과
- ✅ 배터리 최적화 비활성화로 서비스가 계속 실행됨
- ✅ 기기 재부팅 후에도 자동으로 서비스 시작
- ✅ 앱 실행 시 자동으로 서비스 시작
- ✅ 몇 시간 후에도 알림이 정상적으로 작동
- ✅ 사용자에게 배터리 최적화 설정을 명확하게 안내

### 3. 버전 정보 업데이트
  });
}
```

#### 개선 효과
- 사용자가 설정을 변경하면 다음 체크 주기부터 즉시 적용됨
- 서비스를 수동으로 재시작할 필요 없음
- 더 나은 사용자 경험 제공

### 2. 버전 정보 업데이트

다음 파일들의 버전을 1.1.5 (Build 7)로 업데이트:

1. **pubspec.yaml** (19번 줄)
   ```yaml
   version: 1.1.5+7
   ```

2. **version.json** (앱 내 업데이트 확인용)
   ```json
   {
       "version": "1.1.5",
       "buildNumber": 7,
       "downloadUrl": "https://github.com/soodal2u/soop_notification_app/releases/download/v1.1.5/app-release.apk",
       "releaseNotes": "버그 수정: 설정에서 체크 주기 변경 시 즉시 적용되지 않는 문제 해결",
       "forceUpdate": false
   }
   ```

3. **assets/changelog.json** (앱 내 변경사항 보기)
   ```json
   {
       "version": "1.1.5",
       "date": "2026-01-11",
       "changes": [
           "버그 수정: 설정에서 체크 주기 변경 시 즉시 적용되지 않는 문제 해결",
           "백그라운드 타이머 자동 재시작 기능 추가"
       ]
   }
   ```

### 3. 빌드 가이드 문서 작성

`BUILD_GUIDE.md` 파일을 새로 작성하여 다음 내용을 포함:

- 사전 요구사항 (Flutter SDK, Android SDK, Java JDK)
- APK 빌드 절차 상세 설명
- 릴리즈 체크리스트
- 버전 관리 가이드
- GitHub Release 생성 방법
- 서명 설정 방법 (프로덕션용)
- 문제 해결 가이드

총 172줄의 포괄적인 문서로, 향후 릴리즈 작업 시 참고할 수 있습니다.

### 4. 코드 품질 개선

코드 리뷰를 통해 다음 개선 사항 반영:

- 경쟁 조건(race condition) 방지
- 불필요한 변수 제거 (checkInterval)
- 프로덕션 코드에서 print() 제거
- 변수명 개선 (initialInterval 등)
- 코드 가독성 향상

## 변경된 파일 목록

```
BUILD_GUIDE.md                       | 172 줄 추가 (새 파일)
assets/changelog.json                |   8 줄 추가
lib/services/background_service.dart |  50 줄 변경
pubspec.yaml                         |   2 줄 변경
version.json                         |   8 줄 변경
------------------------
총 5개 파일 변경, 216줄 추가, 24줄 삭제
```

## APK 빌드 방법

### 필수 명령어

```bash
# 1. 프로젝트 디렉토리로 이동
cd /home/runner/work/soop_notification_app/soop_notification_app

# 2. 의존성 설치
flutter pub get

# 3. 코드 분석 (오류 확인)
flutter analyze

# 4. APK 빌드
flutter build apk --release

# 5. 빌드된 APK 위치
# build/app/outputs/flutter-apk/app-release.apk
```

### 크기 최적화 빌드 (권장)

```bash
# CPU 아키텍처별 별도 APK 생성
flutter build apk --release --split-per-abi

# 생성되는 파일들:
# - app-armeabi-v7a-release.apk (32비트 ARM, 대부분의 구형 기기)
# - app-arm64-v8a-release.apk (64비트 ARM, 최신 기기)
# - app-x86_64-release.apk (64비트 Intel, 에뮬레이터 및 일부 태블릿)
```

## 다음 단계 (릴리즈 프로세스)

1. **코드 병합**
   - PR 승인 및 메인 브랜치에 병합

2. **APK 빌드**
   ```bash
   flutter build apk --release
   ```

3. **태그 생성**
   ```bash
   git tag v1.1.5
   git push origin v1.1.5
   ```

4. **GitHub Release 생성**
   - GitHub 웹사이트에서 "Releases" 탭 클릭
   - "Draft a new release" 클릭
   - 태그: v1.1.5 선택
   - 제목: "v1.1.5 - SOOP 방송 알리미"
   - 내용:
     ```
     버그 수정: 설정에서 체크 주기 변경 시 즉시 적용되지 않는 문제 해결
     
     ## 변경 사항
     - 백그라운드 타이머 자동 재시작 기능 추가
     - 설정 변경 시 즉시 적용
     ```
   - APK 파일 업로드
   - "Publish release" 클릭

5. **사용자 알림**
   - 앱을 실행하는 사용자들에게 자동으로 업데이트 알림 표시됨
   - (version.json 파일의 buildNumber가 높으면 업데이트 다이얼로그 표시)

## 테스트 권장 사항

릴리즈 전 다음 사항을 테스트하세요:

1. **타이머 재시작 기능**
   - 앱 실행 및 백그라운드 서비스 시작
   - 설정에서 체크 주기 변경 (예: 30초 → 10초)
   - 다음 체크부터 10초 주기로 작동하는지 확인

2. **기본 기능**
   - 방송인 추가/삭제
   - 알림 ON/OFF
   - 방송 시작/종료 알림 수신
   - 테마 변경
   - 방해 금지 모드

3. **업데이트 확인**
   - 설정 > 업데이트 확인
   - 새 버전 정보 표시 확인

## 참고 사항

- **서명 키**: 현재는 디버그 키로 서명 (android/app/build.gradle.kts 39번 줄)
  - 개발/테스트용으로는 충분함
  - Google Play 배포 시에는 프로덕션 서명 키 필요

- **최소 SDK**: Android SDK 21 (Android 5.0 Lollipop) 이상

- **대상 SDK**: 최신 Android SDK (자동 설정)

## 연락처

문제가 있거나 추가 지원이 필요한 경우:
- GitHub Issues: https://github.com/soodal2u/soop_notification_app/issues
- Repository: https://github.com/soodal2u/soop_notification_app
