# 바거슾 온라인  
node version 24.0.0

## 기획 
채팅 룸 
chat_room_page : 게임 시작전 채팅 룸 
  역할 : 방장, 참여자 
게임 룸
game_room_page : 게임 시작 후 게임 룸 -> 각 게임마다 재생성
  역할 : 출제자 , 게임 참여자 

이탈 
플레이어 이탈 시 게임방, 채팅방 상관 없이 System message로 ... 님이 퇴장했습니다를 띄움 

game_room_page 이탈 

game_room_page를 이탈하여 1명의 인원이 남을 시, game_room_page를 닫고 chat_room_page로 이전한다.
game_room_page 에서 방장이 이탈하는 경우 chat_room_page.dart 에 있는 사람중 한명이 랜덤으로 방장이 되도록 해

1. 자의적 이탈
  1-1. 진짜로 이탈하는지 확인 모달을 띄운다 
    1-1-1 : 출제자 이탈 
       
    1-1-2 : 참가자 이탈 
       시스템 메시지를 띄운 후 계속 진행 
    1-1-2 : 방장 이탈  
2. 오류로 인한 이탈 
    
게임 종료 
방장이 정답 이라고 외친다.
방장에게 진짜 정답인지 확인 모달이 뜬다.
방장이 정답 확인을 누르면 -> game_room에 있는 참가자들 리스트를 보여주며 정답을 맞춘 사람을 고른다.

이후 시스템이 00 님이 정답을 맞췄습니다 라고 선포한다.
시스템이 정답을 공개한다.

시스템이 정답을 공개한 뒤 30초뒤 게임을 종료하고 다시 chat_room_page로 돌아간다.

## 실행 명령어 (Execution Commands)

### 개발 환경 (Development Environment)

개발
flutter run -t lib/main_prod.dart --flavor dev

flutter run -t lib/main_prod.dart --flavor dev -d chrome 

운영
flutter run -t lib/main_prod.dart --flavor prod

빌드 
flutter build ios --release --flavor Runner -t lib/main_prod.dart

기존 Firebase 설정을 개발 환경으로 사용합니다.



*   **Android:**
    ```bash
    flutter run -t lib/main_dev.dart --flavor dev
    ```
*   **iOS:**
    ```bash
    flutter run -t lib/main_dev.dart
    ```
    (Xcode에서 `Debug` 스키마에 `GoogleService-Info-dev.plist`를 사용하도록 설정했거나, Xcode에서 수동으로 스키마를 선택해야 합니다.)

### 프로덕션 환경 (Production Environment)

새로운 Firebase 설정이 필요합니다.

1.  **`prod` Firebase 구성 파일 제공:**
    *   **Android:** 프로덕션 Firebase 프로젝트용 새 `google-services.json`을 생성하여 `android/app/src/prod/google-services.json`에 배치합니다. (필요시 `android/app/src/prod` 디렉토리를 다시 생성해야 합니다.)
    *   **iOS:** 프로덕션 Firebase 프로젝트용 새 `GoogleService-Info.plist`를 생성하여 `ios/config/GoogleService-Info-prod.plist`에 배치합니다.

2.  **Flutter용 `prod` Firebase 옵션 생성:**
    ```bash
    flutterfire configure --project=<your-prod-project-id> --out=lib/firebase_options_prod.dart --ios-bundle-id=<your-prod-ios-bundle-id> --android-app-id=<your-prod-android-app-id>
    ```
    (플레이스홀더를 실제 프로덕션 프로젝트 세부 정보로 대체하세요.)

3.  **앱 실행:**
    *   **Android:**
        ```bash
        flutter run -t lib/main_prod.dart --flavor prod
        ```
    *   **iOS:**
        ```bash
        flutter run -t lib/main_prod.dart
        ```
        (Xcode에서 `Release` 스키마에 `GoogleService-Info-prod.plist`를 사용하도록 설정했거나, Xcode에서 수동으로 스키마를 선택해야 합니다.)
