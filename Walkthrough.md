# Walkthrough - GitHub Actions 자동 릴리즈

이 워크플로우는 코드를 푸시할 때 자동으로 앱을 빌드하고 릴리즈를 생성하는 과정을 자동화합니다.

## 작동 방식

1. **커밋 및 푸시**: 개발자가 `main` 브랜치에 코드를 푸시합니다.
2. **버전 감지**: 워크플로우가 `pubspec.yaml`을 읽어 현재 버전(예: `1.1.5+7`)을 확인합니다.
3. **Flutter 빌드**: GitHub 서버에서 Flutter 빌드 환경을 구성하고 `flutter build apk --release`를 실행합니다.
4. **릴리즈 노트 추출**: `assets/changelog.json`에서 최신 변경 사항을 읽어와서 릴리즈 설명글로 구성합니다.
5. **GitHub Release 생성**: 확인된 버전을 태그명(예: `v1.1.5+7`)으로 하여 새로운 릴리즈를 생성합니다.
6. **APK 업로드**: 빌드된 `app-release.apk` 파일을 해당 릴리즈의 자산(Assets)으로 업로드합니다.

## 사용 방법

- `pubspec.yaml`의 `version` 값을 수정하고 커밋한 뒤 `main` 브랜치에 푸시하면 자동으로 해당 버전의 릴리즈가 생성됩니다.
- 만약 특정 시점에 직접 태그를 붙여 푸시하고 싶다면 `git tag v1.1.5+7` 후 `git push origin v1.1.5+7`을 수행하면 됩니다.

## 주의 사항

- **권한**: GitHub 리포지토리 설정에서 `Actions` > `General` > `Workflow permissions`가 `Read and write permissions`로 설정되어 있어야 합니다.
- **중복 태그**: 동일한 버전으로 여러 번 푸시할 경우 이미 존재하는 태그에 릴리즈가 업데이트되거나 오류가 발생할 수 있으므로, 버전을 올린 후 푸시하는 것을 권장합니다.
