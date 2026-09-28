# RequestForApproval
우리는 결재만 한다. Powered by NemoClaw

## 아키텍처 결정

| 결정 | 내용 |
|---|---|
| 기밀 권한은 샌드박스 단위로 관리 | 기밀 등급이 다른 업무는 샌드박스를 나눈다. 한 샌드박스 안의 에이전트 구분은 역할 구분이고 보안 경계가 아니다 |
| 추론 제공자는 기밀 등급에 따라 선택 | 목표 구조. 기밀은 로컬 Ollama, 비기밀은 NVIDIA Endpoints 또는 다른 공개 서비스 |
| 해커톤 시연에서는 모두 외부 API | 모든 샌드박스가 NVIDIA Endpoints를 쓴다. 합성 자료만 넣는다 |
| 기밀 검토는 등급 경계를 넘기 전에 | 외부 대응 샌드박스에는 기밀이 들어오지 않는다 |
| 샌드박스끼리는 호스트 서비스 API로만 통신 | 어느 경로를 열지는 네트워크 정책이 정한다 |
| 사람 결재 경로는 에이전트가 호출 불가 | 승인, 거절, 재게시, 기준 변경은 정책에서 명시적으로 막는다 |
| 네트워크 정책은 Restricted에서 시작 | 필요한 경로만 추가한다 |

| 등급 | 독자 | 샌드박스 | 추론 제공자 (목표) | 추론 제공자 (시연) | 첫 구현 |
|---|---|---|---|---|---|
| 공개 | 인터넷 | `public` | NVIDIA Endpoints | NVIDIA Endpoints | 만듦 |
| 회사 내 | 회사 구성원 | `company` | Ollama (로컬) | — | 구조만 |
| 사업부 내 | 사업부 구성원 | `division` | Ollama (로컬) | — | 구조만 |
| 업무 내부 | 업무 담당자 | `team` | Ollama (로컬) | NVIDIA Endpoints | 만듦 |

샌드박스 이름은 기밀 등급을 따른다. 이름만 보고 그 샌드박스에 무엇을 넣어도 되는지 알 수 있다.

기밀 검토는 데이터가 등급 경계를 넘기 전에 한다. 낮은 등급의 샌드박스는 검토를 통과한 내용만 받는다.

현재 상태 (2026-09-27): 옛 이름인 `my-assistant`와 `rfa`로 만들어 봤고, `public`과 `team`으로 옮기는 중이다. OpenShell은 gateway 하나에 추론 경로를 하나만 두므로, 등급별로 제공자를 다르게 쓰려면 gateway를 나눠야 한다. 해커톤 시연에서는 gateway 하나에 제공자 하나로 간다.

이유, 측정값, 검증 상태는 [docs/architecture-decisions.md](docs/architecture-decisions.md)에 있다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/architecture-decisions.md](docs/architecture-decisions.md) | 아키텍처 결정과 이유 |
| [docs/nemoclaw/](docs/nemoclaw/README.md) | NemoClaw 설치, 정책 검증, 샌드박스 설정 |
| [docs/ports.md](docs/ports.md) | 포트 정리 |
| [docs/demo-scenario.md](docs/demo-scenario.md) | 시연 시나리오. 영상은 [docs/demo/demo.mp4](docs/demo/demo.mp4) |
| [policies/README.md](policies/README.md) | 네트워크 정책 설명 |
