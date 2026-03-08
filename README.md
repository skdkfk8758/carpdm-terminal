# CarpdmTerminal

CarpdmTerminal은 프로젝트 중심 태스크 오케스트레이션, Obsidian 기반 메모리, 터미널 중심 에이전트 실행을 결합한 macOS 네이티브 AI 코딩 워크스페이스다.

## 기술 스택

- SwiftUI + AppKit
- XcodeGen (`project.yml`)
- Swift Package Manager
- GRDB
- Yams
- SwiftTerm

## 개발 환경 요구사항

- macOS 14 이상
- 전체 Xcode 설치
- Xcode 라이선스 수락
- `xcodegen` 설치

Xcode 설치 후 먼저 아래 명령을 실행해야 한다.

```bash
sudo xcodebuild -license accept
```

그 다음 `xcodegen`을 설치한다.

```bash
brew install xcodegen
```

## 로컬 개발

테스트 실행:

```bash
swift test
```

터미널에서 바로 앱 실행:

```bash
swift run CarpdmTerminalApp
```

Xcode 프로젝트 생성:

```bash
xcodegen generate
```

생성된 프로젝트 열기:

```bash
open CarpdmTerminal.xcodeproj
```

## DMG 배포

이 저장소는 `.dmg` 배포를 위한 기본 릴리스 파이프라인을 이미 포함하고 있다.

- `.github/workflows/release.yml`: 서명, notarization, GitHub Release 업로드, Sparkle appcast 생성
- `scripts/release/`: archive, DMG 생성, notarize, appcast 생성 스크립트
- `Config/Secrets.example.xcconfig`: 로컬 릴리스 설정 템플릿

배포 가능한 notarized `.dmg`를 만들려면 아래 조건이 필요하다.

- Xcode 라이선스 수락 완료
- `xcodegen` 설치
- Apple Developer ID 인증서
- Apple notarization 자격증명
- Sparkle feed URL 및 키 설정
- GitHub `production-release` environment secrets 설정

즉, 구조는 이미 준비되어 있고 위 조건만 채우면 GitHub Actions 또는 로컬 Xcode archive 경로로 `.dmg` 배포가 가능하다.

## GitHub CI / 릴리스

- CI: `.github/workflows/ci.yml`
- 릴리스: `.github/workflows/release.yml`
- 배포 설정 템플릿: `Config/`
- 릴리스 스크립트: `scripts/release/`
- private repo 배포 가이드: `docs/distribution/github-private-distribution.md`
- public repo 하드닝 가이드: `docs/distribution/github-public-distribution.md`
- GitHub 설정 체크리스트: `docs/distribution/github-setup-checklist.md`
- 보안 정책: `SECURITY.md`

Signed release는 GitHub environment `production-release` 승인이 필요하다.

## 저장 위치

앱 전역 메타데이터:

`~/Library/Application Support/CarpdmTerminal/app.sqlite`

프로젝트별 메모리 저장소:

`<project>/.carpdm/vault`
