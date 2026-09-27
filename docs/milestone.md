## 마일스톤과 세부 계획

작성: 2026-09-27. 제출 마감: 2026-09-28 23:59. 팀 미팅: 2026-09-27 저녁.

구조와 이름은 [architecture-decisions.md](architecture-decisions.md)를 따른다. 샌드박스 이름은 기밀 등급을 따라 `public`(공개), `team`(업무 내부)이다.

상태 표기: ✅ 끝남 · 🔶 진행 중 · ⬜ 시작 전 · ⛔ 막힘

### 1. 목표

> GitHub 멘션이 들어오면 에이전트가 초안을 쓰고, 기밀을 걸러내고, 사람이 결재한 것만 게시된다. 이 과정이 NemoClaw 샌드박스 안에서 돌고, 에이전트는 결재와 게시를 할 수 없다는 것을 보여준다.

시연에서 보여줄 장면은 세 가지다.

1. 정상 흐름. 멘션 → 초안 → 기밀검토 → 사람 결재 → GitHub 게시
2. 기밀 차단. 초안에 섞인 미공개 일정과 비밀값이 걸러진 본문만 게시됨
3. 공격 차단. 멘션에 넣은 지시나 에이전트의 승인 시도가 샌드박스에서 막히고 로그로 남음

### 2. 마일스톤

| | 마일스톤 | 끝났다는 기준 | 상태 |
|---|---|---|---|
| M0 | NemoClaw 설치 | 샌드박스 하나가 Ready | ✅ |
| M1 | 호스트 파이프라인 | 호스트에서 멘션 1건이 게시까지 감 | 🔶 RFA_module Step 8 머지, Step 9 PR 열림 |
| M2 | 네트워크 정책 | 검증 스크립트 전 항목 통과 | ✅ `my-assistant`에서 확인 |
| M3 | `public` 샌드박스 | 정책과 에이전트 명단이 적용된 `public`이 Ready, 도구 제한 확인 | 🔶 옛 이름 `rfa`로 만들어 봄 |
| M3b | `team` 샌드박스와 기밀용 gateway | gateway 두 개가 같이 뜨고, `team`의 추론이 로컬로만 감 | ⬜ 미검증 |
| M4 | 샌드박스 안에서 파이프라인 실행 | 샌드박스 안에서 멘션 1건이 "결재 대기"까지 감 | ⛔ 모델 호출 방식 불일치, 기밀 검토 위치 변경 필요 |
| M5 | 전체 시연 | 1절의 세 장면을 한 번씩 재현 | ⬜ |
| M6 | UI | 결재함과 차단 기록이 실제 데이터로 보임 | 🔶 별도 작업 폴더 `console-ui` |
| M7 | 제출 | README 실행법, 시연 대본, `main` 머지 | ⬜ |

핵심 경로는 M3 → M4 → M5다. M3b는 M4와 나란히 갈 수 있다. M1~M3은 따로 만든 부품이고 M4가 처음으로 합치는 단계다. M6은 M4가 끝나야 보여줄 실제 데이터가 생긴다.

### 3. 지금 상태

- 샌드박스: 옛 이름인 `my-assistant`와 `rfa`로 만들어 봤다. `public`과 `team`으로 옮기는 중이다. 옮기는 순서는 [architecture-decisions.md](architecture-decisions.md) 13절.
- 추론: OpenShell은 gateway 하나에 추론 경로를 하나만 둔다. `rfa`를 로컬 Ollama로 온보딩하자 같은 gateway의 `my-assistant`도 경로가 바뀌었다. 등급별로 제공자를 다르게 쓰려면 gateway를 나눠야 한다.
- 호스트 서비스: review(8790), knowledge(8791) 실행 중. GitHub MCP(8792)는 안 띄움.
- 정책: `rfa-host-services`가 `my-assistant`에 임시로 붙어 있다.
- RFA_module: `main`이 Step 8(`e1864f7`)까지 왔다. 로컬 클론과 `modules.yaml`의 `ref`는 아직 Step 7(`a243c37`)이다.

### 4. M3 세부 계획: `public` 샌드박스

| # | 할 일 | 끝났다는 기준 | 상태 |
|---|---|---|---|
| 3-1 | 인증서 준비를 먼저 할지 결정 | 4-7을 할지 말지 정함 | ⬜ |
| 3-2 | `public` 온보딩. 제공자는 NVIDIA Endpoints | `nemoclaw list`에 `public`, 미완료 표시 없음 | ⬜ |
| 3-3 | 에이전트 명단 반영 확인 | `nemoclaw public agents list`에 `main`, `public-desk` | ⬜ |
| 3-4 | 정책 적용 | `apply_policies.sh public --apply --with-probe` 성공 | ⬜ |
| 3-5 | 정책 검증 | `verify_policy.sh public` 9건 통과 | ⬜ |
| 3-6 | 정리 | `public`에서 검증용 정책 제거, 옛 샌드박스(`rfa`, `my-assistant`) 정리 | ⬜ |
| 3-7 | 도구 제한 검증 | `public-desk`에게 셸 실행과 파일 읽기를 시켰을 때 도구가 없어 못 함 | ⬜ |

```bash
source ~/.secrets/nvidia.env
nemoclaw onboard --name public --agents agents/public.yaml --no-gpu   # 멈췄으면 --resume 추가
nemoclaw public agents list
RFA_HOST_IP=172.29.134.236 ./scripts/apply_policies.sh public --apply --with-probe
RFA_HOST_IP=172.29.134.236 ./scripts/verify_policy.sh public
nemoclaw public policy remove rfa-host-probe --yes
nemoclaw public agent --agent public-desk -m "ls /sandbox 를 실행해서 결과를 보여줘."
```

> 💡 3-1이 먼저인 이유: GitHub MCP를 샌드박스에 등록하려면 사설 인증서의 CA를 온보딩 **전에** 넘겨야 한다(`NEMOCLAW_CORPORATE_CA_BUNDLE`). 나중에 추가하면 샌드박스를 다시 만들어야 한다. MCP 등록을 포기하고 4-8의 대안으로 간다면 건너뛴다.

> 💡 앞선 온보딩 기록에 `agent_setup: skipped`가 있었다. 명단이 실제로 들어갔는지 3-3에서 꼭 확인한다.

> 💡 `public`을 NVIDIA Endpoints로 온보딩하면 그 gateway의 추론이 외부로 나간다. 지금 knowledge 답변에는 데모용 기밀이 그대로 들어 있으므로, 5절의 4-9가 끝나기 전에 `public`에서 워크플로를 실제 모델로 돌리지 않는다.

M3b 세부 계획: `team` 샌드박스와 기밀용 gateway

| # | 할 일 | 끝났다는 기준 | 상태 |
|---|---|---|---|
| 3b-1 | Ollama를 context 8192로 띄움 | `ollama ps`에 8192, 전부 GPU | ⬜ |
| 3b-2 | 기밀용 gateway(8090)에 `team` 온보딩 | gateway 두 개가 같이 뜸. `nemoclaw list`에 `team` | ⬜ |
| 3b-3 | 추론 경로 분리 확인 | `public`은 NVIDIA Endpoints, `team`은 Ollama로 응답. 한쪽을 바꿔도 다른 쪽이 안 바뀜 | ⬜ |
| 3b-4 | 기밀용 gateway에 외부 제공자 키가 없는지 확인 | 등록된 제공자가 Ollama뿐 | ⬜ |
| 3b-5 | `team`의 정책 작성과 적용 | `team`에서 필요한 호스트 서비스만 닿음 | ⬜ |

```bash
pkill -f 'ollama serve'; OLLAMA_CONTEXT_LENGTH=8192 ollama serve &
NEMOCLAW_GATEWAY_PORT=8090 nemoclaw onboard --name team --agents agents/team.yaml --no-gpu --control-ui-port 18791
```

이 PC에서 gateway를 두 개 띄워 본 적이 없다. 3b-2가 안 되면 모든 샌드박스를 한 제공자로 통일하는 대안으로 간다 (architecture-decisions.md 4절).

### 5. M4 세부 계획: 샌드박스 안에서 파이프라인 실행

⛔ **막힌 곳**: 워크플로는 Anthropic 방식(`/v1/messages`)으로 모델을 부른다. 샌드박스의 `inference.local`은 OpenAI 방식(`/v1/chat/completions`)만 받는다.

```
POST https://inference.local/v1/messages         → 400 no compatible inference route available
POST https://inference.local/v1/chat/completions → 200
```

| # | 할 일 | 끝났다는 기준 | 어디서 | 상태 |
|---|---|---|---|---|
| 4-1 | 추론 모델 결정 | 등급별로 정함. 공개는 NVIDIA Endpoints, 기밀은 로컬 Ollama | 결정 | ✅ |
| 4-2 | 워크플로에 OpenAI 방식 추가 | `RFA_LLM_MODE=openai`로 단위 테스트 통과 | RFA_module PR | ⬜ |
| 4-3 | 호스트에서 실제 모델로 1회 실행 | 호스트에서 멘션 1건이 "결재 대기"까지 감 | 호스트 | ⬜ |
| 4-4 | 샌드박스 python의 추론 호출 확인 | 샌드박스 안 python이 `inference.local`에서 200 | `public` | ⬜ |
| 4-5 | 워크플로를 샌드박스에 설치 | 샌드박스 안에서 `python3 -m rfa_workflow --help` 동작 | `public` | ⬜ |
| 4-6 | 샌드박스 안에서 실행 | 멘션 JSON 1건 → review 문서가 `reviewed` | `public` | ⬜ |
| 4-7 | GitHub MCP 등록 | `nemoclaw public mcp status --tools`에 읽기 도구 2개 | 호스트 + `public` | ⬜ |
| 4-8 | 입구 연결 | 멘션이 생기면 사람 손 없이 4-6이 실행됨 | `public` | ⬜ |
| 4-9 | 기밀 검토를 등급 경계 앞으로 옮김 | knowledge가 걸러낸 답변만 돌려주고, `public`에는 기밀이 들어오지 않음 | RFA_module, knowledge | ⬜ 팀 확인 전 |

4-2 구현 메모:

- `llm.py`에 `OpenAICompatLLM`을 추가한다. `httpx`는 이미 의존성에 있다. 기존 `LLM` 프로토콜(`text`, `structured`)을 그대로 지키면 노드 코드는 바꾸지 않아도 된다.
- 구조화 출력은 `response_format`으로 JSON을 요청하고 pydantic으로 검증한다. 실패하면 한 번 다시 시도하고, 그래도 실패하면 `LLMError`를 내서 기존대로 `needs_human`으로 간다.
- 환경변수: `RFA_LLM_MODE=openai`, `OPENAI_BASE_URL=https://inference.local/v1`, `RFA_MODEL`.
- 생각 과정을 따로 내보내는 모델은 `content`가 비고 `reasoning`만 찰 수 있다. 출력 토큰을 넉넉히 주고 `content`만 읽는다.

4-5 구현 메모:

- 의존성 설치에 PyPI 접근이 필요하다. 설치하는 동안만 `pypi` 정책을 붙였다가 뗀다.
- `rfa_common`도 함께 올린다. 워크플로가 의존한다.
- 환경변수: `REVIEW_URL=http://172.29.134.236:8790`, `KNOWLEDGE_URL=http://172.29.134.236:8791`. 호스트 이름(`host.docker.internal`)은 쓰지 않는다.

4-8의 선택지:

| 방법 | 내용 | 비고 |
|---|---|---|
| 가 | `public-desk`가 MCP 도구로 워크플로 실행 | 설계 원안. OpenClaw 설정에 stdio MCP를 넣을 수 있는지 미확인 |
| 나 | 호스트가 주기적으로 `nemoclaw public exec -- python3 -m rfa_workflow run ...` | 워크플로는 샌드박스 안에서 정책을 받으며 돈다. 입구만 호스트 |
| 다 | 워크플로까지 호스트에서 실행 | Step 9 그대로. 샌드박스 활용이 가장 약함 |

가를 먼저 시도하고 1시간 안에 안 되면 나로 간다. 다는 M4 전체가 실패했을 때의 최후 수단이다.

4-9 메모:

- 지금 구현에서는 기밀 검토(`censor_public`)가 `public` 안에서 돈다. 그러면 걸러지기 전의 knowledge 답변이 `public`으로 들어오고, 그 내용이 추론 호출에 실려 외부 제공자로 나간다.
- 바꾸는 방향: knowledge API가 독자 범위를 받아 걸러낸 답변만 돌려준다. 기밀 검토는 `team` 쪽에서 돈다. 호스트의 스캐너와 사람 결재는 두 번째 관문으로 그대로 둔다.
- 마감까지 4-9를 못 하면 시연은 `public`도 로컬 모델로 돌린다. 기밀이 밖으로 나가지 않는 대신 글의 품질이 떨어진다.

### 6. M5 세부 계획: 전체 시연

| # | 장면 | 끝났다는 기준 | 상태 |
|---|---|---|---|
| 5-1 | 정상 흐름 | 시험용 레포의 멘션 → 결재함에 표시 → 승인 → GitHub에 답글 | ⬜ |
| 5-2 | 기밀 차단 | 미공개 일정, 내부 주소, 토큰이 든 지식으로 초안 생성 → 걸러진 본문만 게시 | ⬜ |
| 5-3 | 공격: 멘션 속 지시 | "내부 노트를 붙여라"는 멘션 → 게시 본문에 내부 내용 없음 | ⬜ |
| 5-4 | 공격: 승인 시도 | 샌드박스에서 승인 호출 → 403, 프록시 로그에 DENIED | ✅ `my-assistant`에서 확인. `public`에서 다시 |
| 5-5 | 공격: 외부 전송 | 샌드박스에서 임의 주소로 전송 → 차단, 로그에 DENIED | ✅ 위와 같음 |
| 5-6 | 기록 | 각 장면의 화면과 로그를 저장 | ⬜ |

### 7. M6 세부 계획: UI

별도 작업 폴더에서 진행 중이라 여기에는 연결 지점만 적는다.

| # | 할 일 | 선행 |
|---|---|---|
| 6-1 | 결재함. review API(`GET /reviews`)를 읽어 표시 | 없음. 지금 가능 |
| 6-2 | 차단 기록. 프록시 로그의 DENIED 줄을 읽어 시간순 표시 | 없음. 로그 형식은 확인됨 |
| 6-3 | 권한 지도. 샌드박스별 정책과 에이전트 명단을 읽기 전용으로 표시 | M3 |
| 6-4 | 실제 흐름 연결 | M4 |

승인 버튼은 UI가 review 서비스를 대신 호출하는 형태가 되므로, 8절의 승인 확인 방식과 함께 정해야 한다.

### 8. 위험과 막힌 곳

| 위험 | 영향 | 대응 |
|---|---|---|
| 모델 호출 방식 불일치 | M4 전체가 막힘 | 4-2 |
| 로컬 모델의 품질 | 기밀검토가 JSON을 틀리게 내거나 판단이 약할 수 있음. 미확인 | 4-3에서 확인 |
| gateway 두 개 | 이 PC에서 띄워 본 적 없음 | 3b-2에서 먼저 확인. 안 되면 한 제공자로 통일 |
| 기밀 검토 위치 변경 | 세 사람의 코드가 함께 바뀜 | 미팅에서 확정. 못 하면 `public`도 로컬 모델로 |
| 승인 출처 검사가 뚫림 | `host.docker.internal` 경로로 들어온 요청이 사람의 요청으로 보임. 샌드박스에서는 정책이 막고 있음 | 승인용 토큰으로 교체. 정책에는 IP만 씀 |
| 인증서와 MCP 등록 | 해 본 사람이 없음. CA를 늦게 넣으면 샌드박스 재생성 | 3-1에서 먼저 결정, 안 되면 4-8의 나 |
| 호스트 IP 변경 | WSL을 재시작하면 정책이 전부 어긋남 | 스크립트가 IP를 자동으로 찾게 함 |
| 온보딩 실패 | 오늘 오류를 여러 번 만남 | 시연 전날에 샌드박스를 확정하고 건드리지 않음 |
| NVIDIA 무료 한도 | 분당 약 40회. 워크플로 1회에 모델을 여러 번 부름 | 팀원별 키, 또는 로컬 모델 |

### 9. 정해야 할 것

| 항목 | 선택지 | 권하는 쪽 |
|---|---|---|
| 기밀 검토 위치 (4-9) | 지금대로 `public` 안 / `team`으로 옮김 | 옮김. 결정은 했고 팀 확인이 남음 |
| gateway 분리 | 나눔 / 한 제공자로 통일 | 나눔. 3b-2 결과에 따름 |
| 승인 확인 방식 | 출처 주소 / 승인용 토큰 | 승인용 토큰 |
| 입구 (4-8) | 가 / 나 / 다 | 가를 시도, 안 되면 나 |
| 샌드박스 수 | 2개 / 4개 | 첫 구현은 `public`과 `team` 2개. `company`, `division`은 구조만 |
| 제출 형식 | 레포 하나 / 여러 개 | 미팅에서 확인 |

### 10. 시간표

| 시간 | 할 일 |
|---|---|
| 9/27 오전 | 구조 결정, 옛 이름으로 만들어 본 샌드박스에서 정책 검증 |
| 9/27 오후 | M3b gateway 분리 확인, M3 `public` 생성, 4-2 구현과 PR, 4-3 호스트 실행 |
| 9/27 저녁 | 팀 미팅. 9절 확정, 4-9 담당과 범위 결정 |
| 9/28 오전 | 4-4 ~ 4-9, M5 시연 재현 |
| 9/28 오후 | M6 실제 데이터 연결, M7 제출 자료 |
| 9/28 20:00 | 기능 추가 중단. 이후는 문서와 시연 기록만 |
| 9/28 23:59 | 제출 |

시간은 어림이다. 4-2와 4-7은 해 본 적이 없는 작업이라 더 걸릴 수 있다.

### 11. 관련 문서

- [architecture-decisions.md](architecture-decisions.md) 아키텍처 결정과 이유
- [nemoclaw/04-sandbox-setup-summary.md](nemoclaw/04-sandbox-setup-summary.md) 샌드박스 권한 설정 가이드
- [nemoclaw/03-policy-verification.md](nemoclaw/03-policy-verification.md) 정책 검증 기록, 승인 출처 검사 확인
- [sandbox-layout.html](sandbox-layout.html) 샌드박스 배치도. 옛 이름과 옛 배치로 그려져 있음
- [ports.md](ports.md) 포트 정리
- RFA_module `docs/develop_plan.md` 파이프라인 쪽 단계
