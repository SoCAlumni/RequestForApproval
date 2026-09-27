## NemoClaw 로컬 설치 Troubleshooting 및 문답 (WSL2)

작성일: 2026-09-27. WSL2에 NemoClaw를 설치하면서 만난 오류 4개의 원인과 해결, 온보딩에서 고른 값과 이유, 그 과정에서 나온 문답을 정리했다. 개념 설명은 [01-nemoclaw-brev-basics.md](01-nemoclaw-brev-basics.md) 참고.

최종 결과: **온보딩 완료.** 샌드박스 `my-assistant`가 `Ready` 상태이고 대시보드는 `http://127.0.0.1:18789/`.

### 1. 환경 정보

- OS / 플랫폼: Windows + WSL2, Ubuntu 22.04.3 LTS (kernel 6.18, systemd 아님. PID 1 = `init`)
- NemoClaw: v0.0.124(설치 기본값)에서 실패 → **v0.0.129**에서 성공
- OpenShell: 0.0.116
- 에이전트: OpenClaw v2026.9.1
- Node: v22.23.3 (nvm)
- Docker: 네이티브 Docker Engine 26.1.4 → **Docker Desktop 26.1.1** (WSL integration)
- GPU: NVIDIA GeForce RTX 4060 (8GB), 드라이버 591.86. 샌드박스에는 넘기지 않음
- 추론 제공자: NVIDIA Endpoints, 모델 `nvidia/nemotron-3-super-120b-a12b`

### 2. 이슈 요약

> WSL2 + 네이티브 Docker + NemoClaw v0.0.124 조합에서 온보딩이 네 번 막혔다. Docker Desktop으로 전환하고, GPU passthrough를 끄고, NemoClaw를 v0.0.129로 올려서 해결했다.

| 순서 | 오류 | 원인 | 해결 |
|---|---|---|---|
| 1 | 프리플라이트 blocking 3개 | WSL 안의 네이티브 Docker Engine | Docker Desktop으로 전환 |
| 2 | `CapAdd contains duplicate capabilities` | `--resume`에 `--no-gpu`가 빠져 GPU 경로로 진입 | `--no-gpu`를 매번 붙임 |
| 3 | `Backing up workspace state...` 뒤 종료 | Error 상태 샌드박스는 백업 불가 | 실패한 샌드박스를 삭제 |
| 4 | `getent unable to find entry "0:0"` | NemoClaw v0.0.124 버그 (#12010) | v0.0.129 설치 |

### 3. 처음부터 다시 한다면

같은 환경(WSL2)에서 팀원이 설치할 때는 이 순서로 하면 위 오류를 모두 피한다.

```bash
# 1) WSL 안의 네이티브 Docker가 있으면 끈다 (~/.zshrc 등의 자동 시작도 제거)
sudo service docker stop

# 2) Windows에서 Docker Desktop 실행 후 확인
docker info | grep "Operating System"      # Docker Desktop 이어야 함

# 3) 버전을 지정하고 GPU passthrough를 끈 채로 설치
source ~/.secrets/nvidia.env
curl -fsSL https://www.nvidia.com/nemoclaw.sh | NEMOCLAW_INSTALL_TAG=v0.0.129 NEMOCLAW_SANDBOX_GPU=0 bash
```

> 💡 태그 없이 설치하면 v0.0.124가 깔린다. `nemoclaw update --check`도 "업데이트 없음"으로 나오므로 태그를 직접 지정해야 한다.

온보딩 선택값은 9절 참고.

### 4. 이슈 1: 프리플라이트 실패

🔴 **증상**: 설치 스크립트의 `[3/3] Onboarding` 단계에서 중단.

🔴 **에러 메시지**:

```
[WARN]  Host preflight found issues that will prevent onboarding right now.
  Admission finding IDs: host.platform.wsl_native_docker_unqualified, host.gpu.container_toolkit_missing, host.gpu.cdi_missing
  - Native Docker Engine inside WSL is not the qualified Docker Desktop integration.
  - NVIDIA Container Toolkit is missing.
  - The NVIDIA CDI specification is missing.
[ERROR] Skipping onboarding until the host prerequisites above are fixed.
```

🔴 **발생 조건**: WSL2에서 `docker info`의 Operating System이 `Docker Desktop`이 아닌 경우.

🟢 **원인 1**: NemoClaw가 WSL2에서 인정하는 런타임은 Docker Desktop(WSL integration)과 rootless Podman뿐이다. 우회 플래그는 없다.

🟢 **원인 2**: 네이티브 dockerd는 `~/.zshrc`의 "Auto-start Docker on WSL2" 블록이 셸을 열 때마다 `sudo service docker start`로 띄우고 있었다. 이 WSL은 systemd를 쓰지 않아서 `systemctl disable`로는 끌 수 없었다.

🟢 **원인 3**: GPU finding 2개는 네이티브 Docker 때문에 함께 뜬 것이다. Docker Desktop으로 전환하자 사라졌다.

🟢 **조치**:

```bash
# ~/.zshrc 의 Auto-start Docker 블록을 주석 처리한 뒤
sudo service docker stop
# Windows에서 Docker Desktop 실행
docker info | grep -E "Operating System|Server Version"
docker run --rm hello-world
nemoclaw host probe
```

결과: blocking finding 3개가 모두 사라지고 warning 1개(`host.platform.wsl_gpu_passthrough_inconclusive`)만 남았다.

### 5. 이슈 2: CapAdd 오류

🔴 **증상**: 이미지 pull 뒤 `Building sandbox image...` 단계에서 중단.

🔴 **에러 메시지**:

```
Error: Managed bootstrap Docker CapAdd contains duplicate capabilities. Managed bootstrap rollback requires attention: Managed bootstrap quiesced and retained sandbox 'my-assistant' (...) because deletion cannot atomically require this durable ID.
```

🔴 **발생 조건**: `nemoclaw onboard --no-gpu`로 시작했지만, 이어서 돌린 `nemoclaw onboard --resume`에는 `--no-gpu`가 없었다. 세션의 `gpuPassthrough`가 `false`에서 `true`로 바뀌었다.

🟢 **원인(추정)**: GPU passthrough가 켜지면 NemoClaw가 컨테이너를 GPU 호환용으로 다시 만들면서 capability를 추가하는데, 이 경로의 검증에서 중복으로 판정됐다. 중복이 정확히 어디서 생기는지는 확인하지 못했다. 관련 이슈: NVIDIA/NemoClaw #11259.

🟢 **조치**: `--no-gpu`를 붙여 다시 실행. 이후 재발하지 않았다.

> 💡 `--no-gpu`는 세션에 저장되지 않는다. `--resume`할 때마다 다시 붙여야 한다. 설치 스크립트로 온보딩할 때는 `NEMOCLAW_SANDBOX_GPU=0`을 쓴다.

메시징 채널에 임의의 토큰을 넣은 것이 원인일 가능성도 제기됐다. 실패한 컨테이너와 gateway에 메시징 흔적이 없어서 가능성은 낮다고 봤지만, 확정하지는 못했다.

### 6. 이슈 3: 재생성 전 백업 단계에서 종료

🔴 **증상**: `--recreate-sandbox`로 다시 돌리자 아래 두 줄 뒤에 종료.

```
  Sandbox 'my-assistant' exists — recreating to apply sandbox GPU settings.
  Backing up workspace state before recreating sandbox...
```

🟢 **원인**: NemoClaw는 샌드박스를 다시 만들기 전에 기존 상태를 백업한다. Error 상태의 샌드박스는 백업할 수 없어서 종료한다.

🟢 **조치**: 실패한 샌드박스를 삭제했다(8절). 백업을 건너뛰는 방법도 있다.

```bash
NEMOCLAW_RECREATE_WITHOUT_BACKUP=1 nemoclaw onboard --resume --no-gpu --recreate-sandbox
```

> 💡 이 변수는 잃을 내용이 없을 때만 쓴다. 에이전트가 작업한 내용이 있으면 복원되지 않는다.

### 7. 이슈 4: receipt 전송 실패 (`0:0`)

🔴 **증상**: 샌드박스가 `Ready`가 된 직후 중단.

🔴 **에러 메시지**:

```
Docker GPU patch failed.
Could not transfer managed-startup receipt to Docker: Error response from daemon: getent unable to find entry "0:0" in passwd
Error: Sandbox post-create verification or finalization failed; automatic sandbox cleanup was not safe.
```

🔴 **발생 조건**: NemoClaw v0.0.124 + Docker Engine 27 이하. 이름은 "Docker GPU patch"지만 `--no-gpu`에서도 지나가는 경로다(진단 기록에 `selected_gpu_route=none`).

🟢 **원인**: NemoClaw의 알려진 버그(NVIDIA/NemoClaw #12010). 임시 컨테이너를 `--user 0:0`으로 만드는데, Docker Engine 27 이하는 `docker cp -a` 때 `0:0`을 passwd 항목 이름으로 해석해서 실패한다. PR #12015가 `--user 0`으로 고쳤다.

| 태그 | 날짜 | `0:0` 버그 |
|---|---|---|
| v0.0.124 (`lkg`, 설치 기본값) | 2026-09-14 | 있음 |
| v0.0.127 | 2026-09-17 | 있음 |
| v0.0.128 | 2026-09-22 | 수정됨 |
| v0.0.129 (`latest`) | 2026-09-23 | 수정됨 |

🟢 **조치**: 태그를 지정해 v0.0.129 설치.

```bash
source ~/.secrets/nvidia.env
curl -fsSL https://www.nvidia.com/nemoclaw.sh | NEMOCLAW_INSTALL_TAG=v0.0.129 NEMOCLAW_SANDBOX_GPU=0 bash
```

결과: 온보딩의 모든 단계가 완료됐다.

진단 기록은 `~/.nemoclaw/onboard-failures/<시각>-<샌드박스>-docker-gpu-patch/`에 남는다. `summary.txt`부터 보면 된다.

### 8. 실패한 샌드박스 정리 절차

온보딩이 중간에 실패하면 샌드박스가 남고, 같은 이름으로는 재온보딩이 막힌다. 남은 상태에 따라 방법이 다르다.

🟢 **샌드박스가 Error 상태일 때**: NemoClaw 명령으로 지워진다. 다만 상태 볼륨이 남는다.

```bash
nemoclaw my-assistant destroy --yes --no-cleanup-gateway
docker volume rm nemoclaw-openclaw-state-v1-my-assistant
```

🔴 **샌드박스가 Ready 상태로 남았을 때**: `destroy`가 삭제를 거부한다.

```
Refusing to delete retained sandbox 'my-assistant': OpenShell reports a sandbox present under this name. NemoClaw cannot bind a mutable-name delete to the retained record
```

OpenShell 0.0.116은 이름으로만 삭제할 수 있어서, NemoClaw는 "그 이름이 다른 샌드박스를 가리킬 수도 있다"는 이유로 막는다.

🟢 **이 경우의 절차**: 순서가 중요하다. 볼륨은 멈춘 bootstrap 컨테이너가 붙잡고 있어서 컨테이너를 먼저 지워야 한다.

```bash
openshell sandbox get my-assistant                          # ID와 create-attempt 라벨이 실패 기록과 같은지 확인
openshell sandbox delete my-assistant                       # NemoClaw 문서는 비권장. 위 확인 뒤에만 실행
docker ps -a --filter volume=nemoclaw-openclaw-state-v1-my-assistant
docker rm <컨테이너 ID>                                      # 멈춘 ...-nemoclaw-bootstrap-... 컨테이너
docker volume rm nemoclaw-openclaw-state-v1-my-assistant
nemoclaw my-assistant destroy --yes --no-cleanup-gateway    # NemoClaw 기록 정리
```

> 💡 `openshell` 명령을 직접 쓰는 것은 예외적인 조치다. 샌드박스가 하나뿐이고 안에 작업 내용이 없어서 실행했다. 평소에는 `nemoclaw` 명령만 쓴다.

볼륨 안에는 이미지가 넣어둔 플러그인 파일(약 360MB)만 있었다.

### 9. 온보딩 선택값과 이유

| 단계 | 선택 | 이유 |
|---|---|---|
| 에이전트 | OpenClaw | 기본값 |
| 추론 제공자 | NVIDIA Endpoints | 무료, 모델이 큼. 13절 참고 |
| 모델 | `nvidia/nemotron-3-super-120b-a12b` | NemoClaw의 기본 클라우드 모델 |
| 샌드박스 이름 | `my-assistant` | 기본값 |
| 웹 검색 | 사용 안 함 | 승인·게시 흐름에 불필요. egress가 늘어남. Brave는 과금 위험 |
| 메시징 채널 | 선택 안 함 | 실제 연동은 GitHub만. 알림·결재는 자체 UI가 담당 |
| 리소스 프로필 | 없음 (OpenShell 기본값) | 에이전트가 가볍고, 샌드박스를 2개 띄울 계획 |
| GPU passthrough | 끔 | 추론을 API로 하므로 불필요 |

적용된 정책 프리셋: `brew`, `huggingface`, `npm`, `openclaw-pricing`, `pypi`.

웹 검색과 메시징은 나중에 바꿀 수 있지만 샌드박스 rebuild가 따라온다.

```bash
nemoclaw <name> channels add slack
nemoclaw <name> channels remove slack
```

NemoClaw의 "메시징 채널"은 사람이 에이전트와 대화하는 입구다. 우리 제품의 "게시 채널"(GitHub, Confluence 등 결과물이 나가는 목적지)과는 다른 것이다.

리소스 프로필의 퍼센트는 호스트 전체 대비 비율이다. 이 PC(20코어, RAM 약 16GB) 기준 환산값은 아래와 같다.

| 프로필 | CPU | RAM |
|---|---|---|
| gamer (25%) | 5코어 | 약 4GB |
| creator (50%) | 10코어 | 약 8GB |
| game-developer (60%) | 12코어 | 약 9.5GB |
| developer (75%) | 15코어 | 약 12GB |

### 10. 문답: 실행 위치와 `--no-gpu`

**Q. build.nvidia.com API로 하면 로컬에서 도는 게 맞나?**

반만 로컬이다. 에이전트는 내 PC에서 돌고, 모델 추론만 NVIDIA 클라우드에서 돈다.

| 구성요소 | 실행 위치 |
|---|---|
| `nemoclaw` CLI, OpenShell gateway | 내 PC (WSL) |
| 샌드박스 컨테이너 + 에이전트(OpenClaw) | 내 PC (Docker Desktop) |
| 정책 집행, 격리, 대시보드 | 내 PC |
| 모델 추론 | NVIDIA 클라우드 |

- 에이전트가 모델을 호출할 때마다 프롬프트와 도구 결과가 NVIDIA 서버로 전송된다. 에이전트가 읽은 내부 문서 내용도 프롬프트에 담기면 외부로 나간다.
- 인터넷 연결과 `nvapi-` 키가 필요하다.

**Q. `--no-gpu`는 무엇인가?**

| 플래그 | 의미 |
|---|---|
| `--gpu` | gateway와 샌드박스에 GPU passthrough를 필수로 요구 |
| `--no-gpu` | NVIDIA GPU가 감지돼도 GPU passthrough를 끔 |
| `--no-sandbox-gpu` | 샌드박스만 CPU로 강제 |

- GPU passthrough는 내 PC의 GPU를 **컨테이너 안에서** 쓰게 넘겨주는 기능이다. 모델 서버가 컨테이너로 도는 경우(vLLM, NIM)에 필요하다.
- API 추론을 쓰면 GPU 연산은 NVIDIA 서버가 하므로 `--no-gpu`로 인한 성능 손해는 없다.
- Local Ollama는 호스트(WSL)에서 돌기 때문에 `--no-gpu`여도 GPU를 쓴다.

### 11. 문답: 에이전트 설치와 소통

**Q. 내 PC에 OpenClaw가 없는데 어떻게 설치되나?**

OpenClaw는 호스트가 아니라 샌드박스 컨테이너 이미지 안에 설치된다. 호스트에 `openclaw` 명령이 없는 것이 정상이다.

- NemoClaw 설치 스크립트가 `~/.nemoclaw/source`에 소스를 받아둔다.
- `Dockerfile.base`가 Node 22 이미지 위에 OpenClaw CLI를 정해진 버전으로 설치하고 `/sandbox/.openclaw/` 구조를 만든다.
- 온보딩의 에이전트 선택은 `~/.nemoclaw/source/agents/` 아래(`openclaw`, `hermes`, `langchain-deepagents-code` 등) 중 무엇을 쓸지 고르는 단계다.
- 호스트에 설치하지 않는 이유는 격리다. 컨테이너 안에 두고 정책으로 허용한 것만 통과시킨다.

**Q. 선택한 에이전트와는 어떻게 소통하나?**

| 방법 | 명령 |
|---|---|
| 웹 대시보드 | `nemoclaw my-assistant dashboard-url --quiet` |
| 터미널 UI | `nemoclaw launch my-assistant` |
| 샌드박스 셸 | `nemoclaw my-assistant connect` 후 `openclaw tui` |
| 메시징 채널 | `nemoclaw my-assistant channels add <채널>` |

메시지 경로:

```
나 (브라우저/터미널)
  → 샌드박스 안의 OpenClaw   (내 PC, 컨테이너)
  → OpenShell gateway        (내 PC, 키 보관·정책 검사)
  → build.nvidia.com         (NVIDIA 클라우드, 모델 추론)
```

OpenClaw는 API 키를 모른다. gateway가 요청에 키를 붙여서 내보낸다.

### 12. 문답: 비용

**Q. NVIDIA API는 비싸지 않나?**

과금되지 않는다. 카드를 등록하지 않는 무료 서비스라서 한도를 넘으면 요청이 거절될 뿐이다.

| 항목 | 내용 |
|---|---|
| 가입·키 발급 | 무료, 카드 등록 없음 (NVIDIA Developer Program) |
| 속도 제한 | 분당 약 40회 요청 |
| 한도 초과 시 | HTTP 429로 막힘. 과금 없음 |
| OpenClaw 공식 문서 | "NVIDIA models are currently free to use", 비용 기본값 0 |

- 크레딧 총량 유무는 출처마다 다르다. 크레딧 제도가 없어졌다는 자료도 있고, 2026년 8월 NVIDIA 포럼에는 무료 1,000 크레딧을 소진했다는 글도 있다. build.nvidia.com에 로그인해서 본인 계정을 확인하는 것이 정확하다.
- 해커톤에서는 비용보다 한도가 문제다. 에이전트는 작업 하나에 모델을 여러 번 호출한다.
- 팀원이 각자 키를 발급하면 한도도 각자 따로 잡힌다.

**Q. Brave 웹 검색은 무료인가?**

사실상 아니다. 2026년 2월에 무료 요금제가 없어졌다.

| | Brave Search | Tavily Search |
|---|---|---|
| 무료분 | 월 $5 크레딧 (약 1,000회) | 월 1,000 크레딧 |
| 카드 등록 | 필수 | 불필요 |
| 무료분 초과 시 | 카드로 과금 (상한 없음) | 요청이 멈춤 |

검색이 필요해지면 Tavily를 쓴다.

**이 프로젝트에서 돈이 나가는 경로**는 Brev 인스턴스뿐이다. 쓴 뒤에는 `brev stop`.

### 13. Local Ollama를 쓴다면

온보딩 중 한 번 Local Ollama를 골랐다가 NVIDIA Endpoints로 바꿨다. 비교는 아래와 같다.

| 항목 | NVIDIA Endpoints | Local Ollama |
|---|---|---|
| 모델 추론 위치 | NVIDIA 클라우드 | 내 PC (WSL 호스트의 `ollama serve`) |
| 프롬프트 외부 전송 | 있음 | 없음 |
| API 키, 호출 한도 | `nvapi-` 키, 분당 약 40회 | 없음 |
| 모델 크기 | 120B급 | 9B (`qwen3.5:9b`) |

당시 확인한 상태:

- `ollama ps`: `qwen3.5:9b`, 5.5GB, 100% GPU, context 4096.
- `nvidia-smi`: VRAM 7788 / 8188 MiB 사용.

Ollama를 고르지 않은 이유:

- NemoClaw는 Ollama가 보고하는 context 길이를 OpenClaw의 `contextWindow`로 쓴다. 4096은 에이전트의 시스템 프롬프트와 도구 정의가 들어가기에 작다.
- context를 늘리려면 `OLLAMA_CONTEXT_LENGTH`를 주고 Ollama를 다시 띄워야 하는데, VRAM이 이미 거의 찼다.
- 모델 크기 차이가 커서 여러 단계를 거치는 작업의 품질이 떨어질 수 있다.

"내부 문서가 외부로 나가지 않는다"가 핵심 주장이 되면 다시 검토한다. 제공자는 온보딩 뒤에도 바꿀 수 있다.

### 14. 복습 퀴즈

| 질문 | 답 |
|---|---|
| 프리플라이트를 막은 진짜 원인과, WSL2에서 인정되는 런타임 두 가지는? | 네이티브 Docker Engine. Docker Desktop(WSL 통합)과 rootless Podman |
| `systemctl disable`이 동작하지 않은 이유와, dockerd를 띄우던 곳은? | 이 WSL이 systemd를 쓰지 않음. `~/.zshrc` |
| NVIDIA API를 쓸 때 내 PC가 아닌 곳에서 도는 것은? | 모델 추론 |
| OpenClaw는 어디에 설치되며, 호스트에 설치하지 않는 이유는? | 샌드박스 컨테이너 이미지 안. 격리 |
| NVIDIA 무료 한도를 넘으면? 돈이 나가는 경로는? | 429로 거절되고 과금 없음. Brev 인스턴스 |

### 15. 참고 사항

- Docker Desktop이 켜져 있어야 WSL에서 `docker`가 동작한다.
- 네이티브 Docker에 있던 `cmf-agent` 이미지는 Desktop에서 보이지 않는다. 필요하면 `docker compose up -d --build`로 다시 빌드.
- 네이티브 Docker로 되돌리기: Docker Desktop 통합을 끄고 `~/.zshrc`의 주석을 푼 뒤 `sudo service docker start`.
- 온보딩이 실행 중일 때 다른 터미널에서 `nemoclaw list`를 돌리면 `Failed to acquire lock on ~/.nemoclaw-portable-host.lock` 오류가 난다. 온보딩이 끝나면 해소된다.
- v0.0.129는 NVIDIA가 아직 `lkg`(검증된 안정 버전)로 지정하지 않은 버전이다.
- `nemoclaw my-assistant status`의 `Inference (upstream)`은 `not probed`로 나온다. 셸에 API 키가 없으면 실제 모델 호출까지는 검사하지 않기 때문이다. 에이전트가 실제로 답하는지는 대시보드에서 메시지를 보내 확인한다.
- 링크
  - NemoClaw 이슈 #12010 (`0:0`): https://github.com/NVIDIA/NemoClaw/issues/12010
  - NemoClaw PR #12015 (수정): https://github.com/NVIDIA/NemoClaw/pull/12015
  - NemoClaw 이슈 #11259 (capability 중복 처리): https://github.com/NVIDIA/NemoClaw/issues/11259
  - OpenClaw NVIDIA provider 문서: https://docs.openclaw.ai/providers/nvidia
  - NVIDIA 포럼(크레딧 소진 사례): https://forums.developer.nvidia.com/t/request-additional-api-credits-rate-limit-increase-for-build-nvidia-com-free-tier/379569
  - Brave Search API 요금 변경: https://www.implicator.ai/brave-drops-free-search-api-tier-puts-all-developers-on-metered-billing/
  - Tavily 요금: https://www.tavily.com/pricing
  - NemoClaw 문서: https://docs.nvidia.com/nemoclaw/latest/index.html
