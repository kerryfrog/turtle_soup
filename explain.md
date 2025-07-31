### 프로젝트 개요 및 핵심 로직 설명 (v1.4)

이 문서는 `turtle_soup` Flutter 애플리케이션의 전반적인 구조, 주요 기능, 데이터 흐름 및 핵심 로직을 설명하여, 프로젝트를 빠르게 이해하고 파악할 수 있도록 돕습니다.

#### 1. 아키텍처 및 기술 스택

*   **프론트엔드**: Flutter (Dart) - 크로스 플랫폼 UI 개발
*   **백엔드/데이터베이스**: Firebase (Authentication, Firestore) - 사용자 인증, 실시간 데이터베이스
*   **상태 관리**:
    *   주로 `StatefulWidget`의 `setState`를 사용하여 로컬 UI 상태 관리.
    *   Firestore의 `StreamBuilder`를 통해 실시간 데이터 동기화 및 UI 업데이트.
    *   `SharedPreferences`를 사용하여 로컬 영구 데이터 (로그인 상태, 크래시 복구 정보 등) 저장.
    *   Riverpod 라이브러리가 임포트되어 있으나, 현재 제공된 코드 스니펫에서는 핵심적인 전역 상태 관리보다는 특정 Provider 패턴에 활용될 가능성이 있습니다.
*   **라우팅**: Flutter의 내장 `Navigator`를 사용한 이름 기반 라우팅 (`/login`, `/game_room`, `/admin` 등).

#### 2. 주요 Firestore 컬렉션 및 역할

애플리케이션의 데이터는 Firebase Firestore에 다음과 같은 주요 컬렉션으로 저장됩니다.

*   **`users`**:
    *   사용자별 프로필 정보 (닉네임, 프로필 URL).
    *   현재 참여 중인 방 ID (`currentRoomId`).
    *   활성 게임 참여 여부 (`inActiveGame`).
*   **`rooms`**:
    *   채팅방 및 게임방의 기본 정보 (방 이름 `name`, 공개 여부 `isPublic`, 방장 UID `roomOwnerUid`, 생성 시간 `createdAt`).
    *   현재 방에 참여 중인 사용자 UID 목록 (`participants`).
    *   방의 최대 수용 인원 (`maxParticipants`, 기본값 10).
    *   방에서 게임이 활성화되어 있는지 여부 (`isGameActive`).
    *   현재 진행 중인 게임의 ID (`currentGameId`).
*   **`rooms/{roomId}/messages`**:
    *   특정 방의 일반 채팅 메시지 (게임이 활성화되지 않았을 때 사용).
    *   메시지 내용 `text`, 발신자 `sender`, 발신자 UID `uid`, 프로필 URL `profileUrl`, 타임스탬프 `timestamp`.
*   **`rooms/{roomId}/games`**:
    *   특정 방 내에서 진행되는 게임 인스턴스.
    *   게임 문제 정보 (`problemTitle`, `problemQuestion`, `problemAnswer`).
    *   현재 게임의 출제자 UID (`quizHostUid`).
    *   출제자 위임 관련 플래그 (`quizHostTransferPending`, `previousQuizHostUid`, `quizHostCandidates`).
*   **`rooms/{roomId}/games/{gameId}/messages`**:
    *   특정 게임 인스턴스 내의 채팅 메시지 (게임이 활성화되었을 때 사용).
*   **`problems`**:
    *   게임에 사용될 수 있도록 **승인된** 문제 목록.
    *   문제 제목 `title`, 문제 내용 `question`, 정답 `answer`.
*   **`problem_reports`**:
    *   사용자가 제보한 문제 중 **아직 승인되지 않은** 문제 목록.
    *   문제 제목 `title`, 문제 내용 `question`, 정답 `answer`, 제보자 UID `reporterUid`, 제보 시간 `reportedAt`.

#### 3. 핵심 사용자 흐름 및 기능

1.  **인증 및 초기 진입**:
    *   `lib/screens/login_page.dart`: 사용자 로그인 (이메일/비밀번호, Google, Apple).
    *   `lib/screens/register_page.dart`: 신규 사용자 회원가입.
    *   `lib/main.dart`: `SharedPreferences`의 `isLoggedIn` 상태와 Firebase Auth 상태를 기반으로 `LoginPage` 또는 `HomeScreenPage`로 초기 화면을 결정합니다.
    *   `lib/screens/home_screen_page.dart`: 로그인 후 첫 진입 화면. 사용자가 이전에 활성 게임에 참여 중이었다면 재접속 여부를 묻는 다이얼로그를 표시합니다.

2.  **방 목록 및 생성**:
    *   `lib/screens/room_list_page.dart`:
        *   현재 생성된 채팅/게임방 목록을 표시합니다.
        *   각 방의 현재 참여 인원과 최대 인원 (`X / Y`)을 보여줍니다.
        *   방이 가득 찼을 경우 (`participants.length >= maxParticipants`) 해당 방의 입장을 비활성화합니다.
        *   이전에 비정상 종료된 게임이 있다면 재입장 다이얼로그를 통해 복구를 시도합니다.
        *   `lib/screens/create_room_page.dart`로 이동하여 새로운 방을 생성할 수 있습니다.
    *   `lib/screens/create_room_page.dart`: 새로운 채팅방을 생성하며, `maxParticipants` 필드를 10으로 설정합니다.

3.  **채팅방 및 게임 플레이**:
    *   `lib/screens/chat_room_page.dart`:
        *   선택된 방의 채팅 인터페이스를 제공합니다.
        *   방 입장 시 `participants` 배열에 사용자 UID를 추가하고, `maxParticipants` 제한을 확인합니다.
        *   일반 채팅 메시지를 표시하고 전송합니다.
        *   방장(roomOwnerUid)은 게임 시작 버튼을 통해 `lib/screens/game_room_page.dart`로 게임을 시작할 수 있습니다.
        *   `dispose` 메서드에서 `_isGameActive` 플래그를 사용하여 일반적인 방 퇴장과 게임 종료 후 복귀를 구분하여 불필요한 로직(방장 위임 등)이 실행되지 않도록 합니다.
    *   `lib/screens/game_room_page.dart`:
        *   게임이 진행되는 동안의 전용 화면입니다.
        *   현재 게임 문제(질문)를 표시합니다.
        *   게임 내 채팅 메시지를 처리합니다.
        *   출제자는 정답을 확인하고, 정답자를 선택하여 게임을 종료할 수 있습니다.
        *   출제자가 게임을 나갈 경우, 다른 참가자에게 출제자 권한을 위임하는 로직이 포함되어 있습니다.
        *   게임 종료 시, 일정 시간 후 게임 관련 Firestore 문서를 정리하고 `ChatRoomPage`로 복귀합니다.

4.  **사용자 프로필 및 문제 제보**:
    *   `lib/screens/my_page.dart`:
        *   사용자의 닉네임, 이메일, 프로필 사진을 표시하고 수정할 수 있습니다.
        *   "문제 제보하기" 버튼을 통해 `lib/screens/report_problem_page.dart`로 이동합니다.
    *   `lib/screens/report_problem_page.dart`:
        *   사용자가 새로운 게임 문제를 제보할 수 있는 폼을 제공합니다.
        *   제보된 문제는 Firestore의 `problem_reports` 컬렉션에 저장되어 관리자의 승인을 기다립니다.

5.  **관리자 패널**:
    *   `lib/screens/admin_page.dart`:
        *   `/admin` URL 경로를 통해 접근할 수 있는 관리자 전용 페이지입니다.
        *   접근 시 비밀번호(`admin1234` - **주의: 실제 운영에서는 더 안전한 방법을 사용해야 합니다**)를 입력하여 인증을 거쳐야 합니다.
        *   인증 성공 시, `problem_reports` 컬렉션에 저장된 제보된 문제 목록을 표시합니다.
        *   관리자는 각 제보에 대해 "승인" (문제를 `problems` 컬렉션으로 이동 후 `problem_reports`에서 삭제) 또는 "거부" (`problem_reports`에서 즉시 삭제) 작업을 수행할 수 있습니다.

#### 4. 주요 상태 관리 및 데이터 흐름 요약

*   **사용자 인증 상태**: `FirebaseAuth.instance.authStateChanges()` 스트림을 통해 앱 전반에 걸쳐 사용자 로그인 상태를 감지하고 UI를 업데이트합니다.
*   **방 및 게임 상태**: `rooms` 컬렉션 및 그 하위 컬렉션(`games`, `messages`)에 대한 `StreamBuilder`를 사용하여 실시간으로 방 목록, 참여자, 게임 진행 상황, 채팅 메시지 등을 UI에 반영합니다.
*   **사용자 프로필 상태**: `users` 컬렉션의 특정 사용자 문서에 대한 `StreamBuilder`를 통해 닉네임, 프로필 사진 등의 변경 사항을 실시간으로 반영합니다.
*   **문제 제보 및 관리**: `problem_reports` 컬렉션에 데이터를 추가하고, 관리자 패널에서 이 컬렉션의 스트림을 구독하여 실시간으로 제보 목록을 업데이트하고 관리합니다.

이 문서는 `turtle_soup` 프로젝트의 핵심적인 기능과 구조를 이해하는 데 도움이 될 것입니다. 각 파일의 상세 구현은 해당 파일의 코드를 직접 참조하십시오.