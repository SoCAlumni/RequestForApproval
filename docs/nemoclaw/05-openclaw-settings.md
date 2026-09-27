## 샌드박스별 설정값 기록

> 이 문서는 NemoClaw 온보딩이 OpenClaw와 OpenShell에 실제로 써 넣은 설정값을 적는다. 같은 구성을 다시 만들거나, 설정이 바뀌었는지 비교할 때 쓴다.

작성일: 2026-09-27. 값은 실행 중인 샌드박스에서 직접 읽었다. 토큰과 키는 가렸다. 이 값들을 왜 골랐는지는 [../architecture-decisions.md](../architecture-decisions.md)에 있다.

### 0. 사전 요구사항

- NemoClaw v0.0.129, OpenShell 0.0.116, OpenClaw v2026.9.1
- Docker Desktop(WSL 통합)이 켜져 있을 것
- 온보딩이 실행 중이 아닐 것. 실행 중이면 `nemoclaw` 명령이 잠금 대기로 멈춘다

### 1. 설정이 저장되는 곳

| 위치 | 내용 | 바꾸는 방법 |
|---|---|---|
| 샌드박스 `/sandbox/.openclaw/openclaw.json` | OpenClaw 설정. 모델, 도구, 플러그인, 채널 | 온보딩 또는 `nemoclaw <이름> inference set` |
| 샌드박스 `/sandbox/.nemoclaw/config.json` | NemoClaw가 기록한 제공자와 모델 | 온보딩 |
| 컨테이너 환경변수 `NEMOCLAW_*` | 이미지에 구워지는 값. context, 타임아웃, 웹 검색 | 샌드박스 재생성 |
| OpenShell 정책 | 파일시스템, 프로세스 계정, 네트워크 | 네트워크는 `policy add/remove`. 나머지는 재생성 |
| gateway | 제공자, API 키, 추론 경로 | 온보딩, `nemoclaw credentials reset` |
| 호스트 `~/.nemoclaw/sandboxes.json` | 샌드박스 목록과 각자의 제공자·모델 기록 | NemoClaw가 관리 |
| 레포 `agents/*.yaml` | 에이전트 명단과 도구 권한 | 파일 수정 후 샌드박스 재생성 |
| 레포 `policies/*.yaml` | 추가 네트워크 정책 | `scripts/apply_policies.sh` |

> 💡 샌드박스 안의 파일을 직접 고치지 않는다. 재생성하면 사라지고, NemoClaw의 기록과 어긋난다.

### 2. `my-assistant`: 온보딩 선택값

| 단계 | 선택 |
|---|---|
| 에이전트 | OpenClaw |
| 추론 제공자 | NVIDIA Endpoints (`nvidia-prod`) |
| 모델 | `nvidia/nemotron-3-super-120b-a12b` |
| 웹 검색 | 사용 안 함 |
| 메시징 채널 | 선택 안 함 |
| 리소스 프로필 | 없음 (OpenShell 기본값) |
| GPU passthrough | 끔 |
| 정책 tier | Balanced |
| 대시보드 | `http://127.0.0.1:18789/` |

다시 만드는 명령:

```bash
source ~/.secrets/nvidia.env
curl -fsSL https://www.nvidia.com/nemoclaw.sh | NEMOCLAW_INSTALL_TAG=v0.0.129 NEMOCLAW_SANDBOX_GPU=0 bash
```

### 3. `my-assistant`: OpenClaw 설정 (`openclaw.json`)

모델과 에이전트:

| 항목 | 값 | 뜻 |
|---|---|---|
| `agents.defaults.model.primary` | `inference/nvidia/nemotron-3-super-120b-a12b` | 기본 모델 |
| `agents.defaults.timeoutSeconds` | 600 | 에이전트 작업 제한 시간 |
| `agents.defaults.thinkingDefault` | `off` | 추론 과정 출력 끔 |
| `agents.defaults.skipBootstrap` | `true` | 첫 실행 안내 건너뜀 |
| `agents.entries` | `main` (기본) | 에이전트는 `main` 하나 |
| `models.providers.inference.baseUrl` | `https://inference.local/v1` | 샌드박스는 이 주소만 안다 |
| `models.providers.inference.api` | `openai-completions` | 호출 형식 |
| `models.providers.inference.apiKey` | 자리표시자 (6글자) | 실제 키가 아님. 키는 gateway에 있다 |
| `contextWindow` | 131072 | 모델이 한 번에 받는 토큰 수 |
| `maxTokens` | 4096 | 한 번에 내는 응답의 최대 길이 |
| `cost` | 모두 0 | 비용 기록용 단가 |

대화 압축(`agents.defaults.compaction`):

| 항목 | 값 |
|---|---|
| `mode` | `safeguard` |
| `timeoutSeconds` | 120 |
| `recentTurnsPreserve` | 1 |
| `qualityGuard.enabled` / `maxRetries` | `true` / 0 |
| `notifyUser` | `true` |

도구(`tools`):

| 항목 | 값 | 뜻 |
|---|---|---|
| `toolSearch` | `false` | 도구 검색 기능 끔 |
| `alsoAllow` | `bundle-mcp` | MCP 묶음 도구 허용 |
| `web.fetch.enabled` | `true` | 웹 페이지 가져오기 도구는 켜져 있음 |
| `web.fetch.useTrustedEnvProxy` | `true` | 샌드박스 프록시를 거침 |
| `web.search.enabled` | `false` | 웹 검색 끔 |

> 💡 `web.fetch`가 켜져 있어도 아무 곳에나 갈 수 있는 것은 아니다. 요청은 프록시를 지나고, 네트워크 정책이 허용한 주소만 통과한다.

`main` 에이전트에는 도구 제한을 걸지 않았다. 기본값은 셸 실행까지 허용이다.

플러그인과 채널:

| 항목 | 상태 |
|---|---|
| `plugins.entries.nemoclaw` | 켜짐 |
| `bonjour`, `diagnostics-otel`, `brave` | 꺼짐 |
| 채널 `telegram`, `discord`, `openclaw-weixin`, `slack`, `whatsapp`, `msteams`, `googlechat`, `a2a`, `reef` | 모두 꺼짐 |

OpenClaw 내부 gateway와 프록시:

| 항목 | 값 |
|---|---|
| `gateway.mode` | `local` |
| `gateway.port` | 18789 |
| `gateway.controlUi.allowedOrigins` | `http://127.0.0.1:18789` |
| `gateway.trustedProxies` | `127.0.0.1`, `::1` |
| `gateway.auth.token` | 가림 (43글자) |
| `gateway.reload.mode` | `off` |
| `proxy.enabled` | `true` |
| `proxy.proxyUrl` | `http://10.200.0.1:3128` |
| `proxy.loopbackMode` | `gateway-only` |

> 💡 여기의 `gateway`는 샌드박스 안에서 도는 OpenClaw의 gateway다. 호스트의 OpenShell gateway(포트 8080)와는 다른 것이다.

### 4. `my-assistant`: 컨테이너 환경변수

| 변수 | 값 |
|---|---|
| `NEMOCLAW_MODEL` | `nvidia/nemotron-3-super-120b-a12b` |
| `NEMOCLAW_INFERENCE_BASE_URL` | `https://inference.local/v1` |
| `NEMOCLAW_INFERENCE_API` | `openai-completions` |
| `NEMOCLAW_CONTEXT_WINDOW` | 131072 |
| `NEMOCLAW_MAX_TOKENS` | 4096 |
| `NEMOCLAW_AGENT_TIMEOUT` | 600 |
| `NEMOCLAW_REASONING` | `false` |
| `NEMOCLAW_TOOL_DISCLOSURE` | `progressive` |
| `NEMOCLAW_WEB_SEARCH_ENABLED` | 0 |
| `NEMOCLAW_DISABLE_DEVICE_AUTH` | 0 |
| `NEMOCLAW_OPENCLAW_OTEL` | 0 |
| `CHAT_UI_URL` | `http://127.0.0.1:18789` |
| `OPENSHELL_SANDBOX` | `my-assistant` |

`NEMOCLAW_WEB_SEARCH_PROVIDER`는 `brave`로 들어 있지만 `NEMOCLAW_WEB_SEARCH_ENABLED`가 0이라 쓰이지 않는다.

### 5. `my-assistant`: OpenShell 정책

파일시스템과 프로세스:

| 항목 | 값 |
|---|---|
| 읽기 전용 | `/usr`, `/lib`, `/proc`, `/dev/urandom`, `/app`, `/etc`, `/var/log`, `/var/lib/dpkg` |
| 읽기·쓰기 | `/tmp`, `/dev/null`, `/dev/pts`, `/sandbox/.openclaw`, `/sandbox/.nemoclaw`, `/home/linuxbrew` |
| 작업 폴더 포함 | `include_workdir: true` |
| Landlock | `best_effort` |
| 실행 계정 | `sandbox` 사용자와 그룹 |

네트워크 정책 (13개):

| 정책 | 출처 |
|---|---|
| `managed_inference`, `nvidia`, `clawhub`, `openclaw_api`, `openclaw_docs`, `npm_registry` | 기본 정책 |
| `npm_yarn`, `pypi`, `huggingface`, `brew`, `openclaw-pricing` | Balanced tier |
| `rfa-host-services`의 `rfa_review`, `rfa_knowledge` | 직접 추가. 검증용으로 임시로 붙임 |

`managed_inference`는 `inference.local:443`을 `openclaw`, `node`, `curl`, `python3`에 허용한다.

### 6. gateway (공유)

| 항목 | 값 |
|---|---|
| 포트 | `127.0.0.1:8080` |
| 드라이버 | docker |
| 네트워크 이름 | `openshell-docker` |
| TLS, 클라이언트 인증 | 켜짐 |
| 인증 없는 접근 | 허용 안 함 |
| 상태 폴더 | `~/.local/state/nemoclaw/openshell-docker-gateway/` |

등록된 제공자:

| 이름 | 종류 | 용도 |
|---|---|---|
| `nvidia-prod` | nvidia | NVIDIA Endpoints |
| `ollama-local` | openai 호환 | 호스트의 Ollama |

🔴 **추론 경로는 gateway에 하나뿐이다.** 같은 gateway의 샌드박스는 모두 같은 경로를 쓴다. 2026-09-27 확인 시점의 경로는 `ollama-local` / `qwen3.5:9b`였고, 이때 `my-assistant`의 추론은 `inference service unavailable`로 실패했다.

🟢 **`my-assistant`의 경로를 되돌리는 방법**:

```bash
nemoclaw my-assistant connect      # 기록된 제공자와 모델로 경로를 다시 맞춘다
```

> 💡 `openshell inference set`을 직접 쓰지 않는다. NemoClaw의 호환성 검사를 건너뛴다.

### 7. `rfa`: 실제 설정값

2026-09-27 10:48에 만들어졌다. 아래는 그 시점의 값이다.

이 샌드박스는 `public`이라는 이름으로 다시 만들 예정이다([../architecture-decisions.md](../architecture-decisions.md) D12). 등급은 공개이고 제공자는 NVIDIA Endpoints로 바뀐다. 에이전트 명단 파일은 `agents/public.yaml`로 이름을 바꿨고 내용은 같다.

온보딩 선택값:

| 단계 | 선택 |
|---|---|
| 에이전트 | OpenClaw |
| 에이전트 명단 | `agents/rfa.yaml` (지금의 `agents/public.yaml`) |
| 추론 제공자 | Local Ollama (`ollama-local`). **바꿀 예정** |
| 모델 | `qwen3.5:9b` |
| 웹 검색 | 사용 안 함 |
| 메시징 채널 | 선택 안 함 |
| 리소스 프로필 | 없음 |
| GPU passthrough | 끔 |
| 정책 tier | Restricted |
| 프리셋 | `local-inference` |
| 대시보드 | `http://127.0.0.1:18790/` |
| gateway | 8080 (`my-assistant`와 같음) |

```bash
nemoclaw onboard --name rfa --agents agents/rfa.yaml --no-gpu      # 만들 때 쓴 명령. 파일은 이후 agents/public.yaml 로 바뀜
```

OpenClaw 설정 (`openclaw.json`):

| 항목 | 값 |
|---|---|
| `agents.defaults.model.primary` | `inference/qwen3.5:9b` |
| `agents.defaults.subagents.maxSpawnDepth` | 1 |
| `models.providers.inference.baseUrl` | `https://inference.local/v1` |
| `contextWindow` | 16384 |
| `maxTokens` | 4096 |
| `reasoning` | `false` |
| `tools.toolSearch` | `mode: tools`, 기본 8개, 최대 20개 |
| `tools.web.fetch.enabled` | `true` |
| `tools.web.search.enabled` | `false` |
| `gateway.port` | 18790 |

에이전트 (명단 파일이 이미지에 구워진 결과):

| 에이전트 | 허용 | 거부 |
|---|---|---|
| `main` (기본) | 없음 (`profile: minimal`) | `group:runtime`, `group:fs`, `group:web`, `group:ui`, `group:sessions`, `group:messaging`, `group:automation`, `group:plugins` |
| `public-desk` | `github__list_mentions`, `github__get_thread`, `workflow__run` | `group:runtime`, `group:fs`, `group:web`, `group:ui`, `group:sessions`, `group:messaging`, `group:automation` |

`public-desk`의 작업 폴더는 `/sandbox/.openclaw/workspace-public-desk`, 에이전트 폴더는 `/sandbox/.openclaw/agents/public-desk`다.

네트워크 정책 (7개):

| 정책 | 출처 |
|---|---|
| `managed_inference`, `nvidia`, `clawhub`, `openclaw_api`, `openclaw_docs`, `npm_registry` | 기본 정책 |
| `local_inference` | 직접 켠 프리셋 |

`rfa-host-services`는 아직 붙이지 않았다.

> 💡 `contextWindow`가 16384로 기록됐다. 8192로 맞추려던 계획과 다르다. 같은 시각 `ollama ps`는 모델을 context 4096으로 올려 두고 있었다. OpenClaw가 아는 값과 Ollama가 실제로 쓰는 값이 다르면 긴 프롬프트의 앞부분이 잘릴 수 있다. 제공자를 NVIDIA Endpoints로 바꾸면 이 문제는 `rfa`에서 사라진다.

> 💡 정책 선택 화면에서 `Ctrl+C`나 `Esc`로 나가면 샌드박스가 잠긴 채 남는다. 잘못 골랐더라도 `Enter`로 끝낸 뒤 `policy add/remove`로 고친다.

### 8. 검증

설정값을 다시 읽는 방법이다. 모두 읽기 전용이다.

```bash
nemoclaw list
nemoclaw my-assistant status                     # 기록된 경로와 실제 경로가 다르면 경고가 나온다
nemoclaw my-assistant policy list
nemoclaw config export my-assistant --output -   # 자격증명을 뺀 설정
openshell sandbox get my-assistant               # 적용된 정책 전체
openshell provider list
openshell inference get                          # gateway의 현재 추론 경로
```

OpenClaw 설정 파일을 직접 볼 때:

```bash
C=$(docker ps --filter name=openshell-default--my-assistant --format '{{.ID}}')
docker exec "$C" cat /sandbox/.openclaw/openclaw.json
```

> 💡 이 출력에는 `gateway.auth.token`이 들어 있다. 그대로 붙여 넣어 공유하지 않는다.

### 9. 참고 사항

- `rfa`의 환경변수와 파일시스템 정책은 따로 읽지 않았다. `my-assistant`와 같은 이미지와 기본 정책을 쓴다.
- `my-assistant`에 붙어 있는 `rfa-host-services` 정책은 `rfa`로 옮긴 뒤 제거한다.
- `nemoclaw config export`는 온보딩이 실행 중이어서 이번에는 돌리지 못했다. 이 문서의 값은 컨테이너와 `openshell` 명령에서 읽었다.
- 호스트 IP는 WSL을 재시작하면 바뀔 수 있다. `ip -4 addr show eth0`으로 확인한다.
