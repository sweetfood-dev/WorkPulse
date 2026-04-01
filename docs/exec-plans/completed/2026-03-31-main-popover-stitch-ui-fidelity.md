# 2026-03-31-main-popover-stitch-ui-fidelity.md

## 상태

- active

## owner

- codex

## 변경 요약

기존 기능은 유지한 채 `MainPopoverViewController`의 레이아웃과 스타일을 Stitch 메인 화면에 가깝게 재구성한다.

## 목표와 범위

- 헤더에 아이콘/날짜/체크인 요약 구조 반영
- 현재 세션 영역에 시각적 중심, 진행 bar, 보조 캡션 반영
- 오늘 시간 영역을 배경 section + row 기반 레이아웃으로 변경
- 하단 집계 영역을 Stitch식 2열 summary로 정리

## 비목표

- 계산 규칙 변경
- 새 데이터 필드 추가
- 별도 창/설정 화면 추가

## 관련 문서

- [main-popover-stitch-ui-fidelity.md](../../product-specs/main-popover-stitch-ui-fidelity.md)
- [menu-bar-main-popover-overview.md](../../product-specs/menu-bar-main-popover-overview.md)
- [macos-architecture.md](../../macos-architecture.md)

## 행동 변경 (Behavioral Changes - TDD)

- [x] 기본 placeholder/read-only 값은 새 레이아웃에서도 유지된다
- [x] 시작/종료 시간 row 탭으로 진입하는 edit mode는 유지된다
- [x] 현재 세션 실시간 갱신과 재개 동작은 새 UI에서도 유지된다

## 구조 변경 (Structural Changes - Tidy First)

- [x] popover root를 section 기반 container view 구조로 재구성한다
- [x] 헤더/현재세션/오늘시간/집계 영역용 최소 helper view 생성 함수를 정리한다
- [x] 읽기 전용 row와 edit row가 같은 자리에서 교체되는 레이아웃을 단순화한다

## 테스트 케이스 및 시나리오

- placeholder 상태에서도 핵심 라벨과 값이 보인다
- 새 레이아웃에서도 edit mode 진입/취소/적용이 유지된다
- 현재 세션 타이머 start/stop/reopen 동작이 유지된다

## 진행 상태

- [x] spec 고정
- [x] section 레이아웃 재구성
- [x] 편집 row 스타일 정리
- [x] summary 영역 정리
- [x] regression verification
