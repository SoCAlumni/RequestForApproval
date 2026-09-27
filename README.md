# RequestForApproval
우리는 결재만 한다. Powered by NemoClaw

## 구조

```
채널             공개 영역               호스트            기밀 영역 (샌드박스 team)
GitHub ─┐                                                ┌───────┬──────────┬────────┐
Slack  ─┼─▶ 대응 에이전트 (하나) ─▶ API ─────────────▶   │ head  │ 실무 ×3  │ 검열×2 │
그 밖  ─┘   LangGraph 모듈             ◀─ 승인된 지식 ─   │ agent │          │        │
            샌드박스 없음                   ▲            └───────┴──────────┴────────┘
                                     기밀 검사 (사람) ◀── 원문, 걸러낸 안, 사유
```

| 결정 | 내용 |
|---|---|
| 샌드박스는 기밀 영역에만 | 기밀을 읽는 에이전트(head agent, 실무, 검열)는 샌드박스 `team` 안에서 돈다. 공개 쪽의 대응 에이전트는 샌드박스 없이 호스트에서 돈다 |
| 기밀 판단은 경계를 넘기 전에 | 검열 에이전트가 거른 것을 사람이 꼼꼼히 검사한다. 승인한 지식만 기밀 영역을 떠난다 |
| 대응 에이전트는 하나 | 모든 채널과 업무를 맡는다. LangGraph로 묶은 모듈이고 받은 글을 다듬기만 한다 |
| 두 영역은 호스트 API로만 통신 | 어느 경로를 열지는 네트워크 정책이 정한다 |
| 승인과 게시는 에이전트가 호출 불가 | 기밀 영역에서는 네트워크 정책이 막는다. 공개 영역에서는 승인용 토큰이 막아야 한다 (아직 없음) |
| 기밀 권한은 샌드박스 단위로 관리 | 한 샌드박스 안의 에이전트 구분은 역할 구분이고 보안 경계가 아니다 |
| 해커톤 시연에서는 외부 API로 추론 | `team`도 대응 에이전트도 NVIDIA Endpoints를 쓴다. **합성 자료만 넣는다** |
| 목표 구조에서는 기밀 영역을 로컬 추론으로 | 기밀용 gateway를 따로 두고 Ollama만 등록한다 |

| 등급 | 독자 | 샌드박스 | 첫 구현 |
|---|---|---|---|
| 공개 | 인터넷 | 없음. 대응 에이전트가 호스트에서 돈다 | 만듦 |
| 회사 내 | 회사 구성원 | `company` | 구조만 |
| 사업부 내 | 사업부 구성원 | `division` | 구조만 |
| 업무 내부 | 업무 담당자 | `team` | 만듦 |

현재 상태 (2026-09-27): 구조를 정했고 구현은 앞에 있다. 샌드박스 `team`, 검열 에이전트, 기밀 검사 화면, 승인용 토큰은 아직 없다. 공개 쪽 흐름은 RFA_module에서 호스트 실행까지 확인됐다. 계획은 [docs/milestone.md](docs/milestone.md)에 있다.

이유, 측정값, 검증 상태는 [docs/architecture-decisions.md](docs/architecture-decisions.md)에 있다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/architecture-decisions.md](docs/architecture-decisions.md) | 아키텍처 결정과 이유. 지금 구조는 15절 |
| [docs/milestone.md](docs/milestone.md) | 마일스톤, 단계별 계획, 시간표 |
| [docs/review-methodology.md](docs/review-methodology.md) | 기밀 검토 방법론. 경로, 내용, 결재와 허용·차단 목록 |
| [docs/agent-zones.html](docs/agent-zones.html) | 에이전트 배치와 질문 한 건의 흐름 (그림) |
| [docs/review-pipeline.html](docs/review-pipeline.html) | 기밀 검토 흐름 (그림) |
| [docs/sandbox-layout.html](docs/sandbox-layout.html) | 샌드박스와 호스트 서비스 배치 (그림) |
| [docs/nemoclaw/](docs/nemoclaw/README.md) | NemoClaw 설치, 정책 검증, 샌드박스 설정 기록 |
| [docs/ports.md](docs/ports.md) | 포트 정리 |
| [policies/README.md](policies/README.md) | 네트워크 정책 설명 |
