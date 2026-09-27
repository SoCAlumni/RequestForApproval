# NemoClaw와 Brev: 개념과 사용법 정리

작성일: 2026-09-26. 공식 문서(docs.nvidia.com/nemoclaw, docs.nvidia.com/brev)와 GitHub README를 기준으로 정리. 버전이 빠르게 바뀌므로 명령이 안 맞으면 `nemoclaw help`, `brev --help`로 다시 확인할 것.

## 1. 한 줄 요약

- **NemoClaw**: 에이전트(OpenClaw 등)를 **OpenShell 샌드박스 안에서** 안전하게 돌리기 위한 NVIDIA의 오픈소스 참조 스택. 설치 마법사 + 추론(모델) 연결 + 네트워크 정책 + 스냅샷/수명주기 관리를 CLI 하나(`nemoclaw`)로 묶어 놓은 것.
- **Brev**: NVIDIA의 **클라우드 GPU 인스턴스 대여 서비스**. "Launchable"은 GPU + 소프트웨어 환경 + 시작 스크립트를 묶은 원클릭 배포 패키지.
- **로컬 설치 맞음.** NemoClaw는 기본적으로 내 머신(Linux, WSL2, macOS)에 설치하는 도구다. Brev Launchable은 "내 머신 대신 NVIDIA 클라우드 GPU VM에 NemoClaw를 설치해 주는" 선택지일 뿐이다. 둘 중 하나만 있으면 된다.

## 2. NemoClaw 구조

```
[내 호스트: nemoclaw CLI]
        │  onboard / policy / logs / dashboard
        ▼
[OpenShell gateway]  ── 자격증명 보관, 정책 집행, 추론 라우팅
        │
        ▼
[OpenShell sandbox (컨테이너)]
   └── 에이전트 런타임: OpenClaw(기본) | Hermes | LangChain Deep Agents
   └── 네트워크 egress는 정책(preset)으로만 허용
        │
        ▼
[추론 제공자] NVIDIA Endpoints(build.nvidia.com, nvapi- 키) | OpenAI | Anthropic | 로컬 Ollama | vLLM 등
```

핵심 포인트:

- 에이전트는 호스트에서 직접 돌지 않고 **샌드박스 컨테이너** 안에서 돈다. 파일·네트워크·권한 격리가 여기서 나온다.
- API 키 같은 자격증명은 **gateway가 보관**하고 샌드박스 안 에이전트에는 노출하지 않는다.
- 네트워크는 **정책 프리셋**으로 통제한다. 온보딩 때 tier를 고른다.
  - Balanced(권장): npm, PyPI, Hugging Face 등 개발용 프리셋 + 검색 제공자
  - Restricted: 최소 egress
  - Open: 무제한
- 우리 프로젝트에서 "에이전트별 정책·권한"이라고 부르는 것이 바로 이 OpenShell 정책 계층이다. `nemoclaw <name> policy list/add/remove`로 다룬다.

## 3. 두 가지 사용 경로

| | 로컬 설치 | Brev Launchable |
|---|---|---|
| 어디에 설치되나 | 내 PC(WSL2/Linux/macOS) | NVIDIA 클라우드 GPU VM |
| GPU 필요? | 아니오. 추론은 build.nvidia.com API로 하면 됨 | VM에 GPU 포함(시간당 과금) |
| 최소 사양 | 4 vCPU, RAM 8GB(권장 16GB), 디스크 20GB+, Docker, Node 22.19+ | 없음(웹에서 클릭) |
| 접속 | `127.0.0.1:18789` 대시보드 | `brev port-forward` 또는 Brev 콘솔 링크 |
| 비용 | 무료(API 호출 비용만) | 인스턴스 실행 중 시간당 과금. stop하면 중단, delete하면 삭제 |
| 언제 쓰나 | 개발·데모·정책 실험 | 로컬 Docker가 안 되거나 로컬 모델(Ollama/vLLM)을 GPU로 돌리고 싶을 때 |

**결론:** 해커톤 개발용이면 로컬(WSL2) 설치가 기본이다. 현재 이 PC는 WSL2 + Docker + Node가 이미 있으므로 조건을 충족한다. Brev는 GPU가 필요한 로컬 추론이나 팀 공용 데모 서버가 필요할 때 켜면 된다.

## 4. 로컬 설치 (WSL2 기준)

```bash
# 1) NVIDIA API 키 준비: https://build.nvidia.com 에서 nvapi-... 키 발급
export NVIDIA_INFERENCE_API_KEY=nvapi-xxxx

# 2) 설치 + 온보딩 마법사 (sudo 불필요, nvm/npm으로 사용자 디렉터리에 설치)
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

WSL2에서는 위 명령 그대로면 실패한다(2026-09-27 확인). 기본으로 깔리는 v0.0.124에 버그가 있어서 버전을 지정하고 GPU passthrough를 꺼야 한다. 전체 경과는 [02-onboarding-qna.md](02-onboarding-qna.md) 참고.

```bash
curl -fsSL https://www.nvidia.com/nemoclaw.sh | NEMOCLAW_INSTALL_TAG=v0.0.129 NEMOCLAW_SANDBOX_GPU=0 bash
```

마법사 순서: 서드파티 고지 동의 → 에이전트 선택(OpenClaw 기본) → 추론 제공자(NVIDIA Endpoints 권장) → API 키 → 샌드박스 이름(기본 `my-assistant`) → 웹 검색(선택) → 메시징 채널(선택) → 정책 tier(Balanced 권장).

설치 후 에이전트에 접근:

```bash
nemoclaw my-assistant dashboard-url --quiet   # 브라우저 대시보드 URL (127.0.0.1:18789)
nemoclaw launch my-assistant                  # 터미널 UI
nemoclaw my-assistant connect                 # 샌드박스 셸로 들어가기
openclaw tui                                  #   (샌드박스 안에서)
```

주의:

- OpenShell은 Linux kernel 5.15+, cgroup v2, user namespace가 필요. `nemoclaw <name> doctor`로 점검.
- 샌드박스 이미지가 약 2.4GB. RAM 8GB 미만이면 swap 8GB 이상 설정.
- `openshell` 명령을 직접 만지지 말 것(`openshell sandbox create`, `openshell self-update` 등). 항상 `nemoclaw onboard`를 통해 관리.
- 마법사가 걸리는 CI/원격 환경은 `NEMOCLAW_NON_INTERACTIVE=1`과 `NEMOCLAW_*` 환경변수로 무인 설치 가능(5절 참고).

## 5. Brev 경로

### 5.1 Brev란

- NVIDIA가 인수한 GPU 클라우드 브로커. AWS/GCP 등 여러 클라우드의 GPU VM을 한 콘솔에서 빌려 쓴다.
- `brev` CLI는 SSH 키·config·IP를 자동 관리해서 인스턴스 이름만으로 접속한다.
- **Launchable** = 하드웨어 기본값(GPU 종류, 스토리지) + 실행 모드(VM/컨테이너/Compose/k8s) + 시작 스크립트 + 노출 포트 + 배포 시 입력값(API 키 등)을 묶은 공유 가능한 링크. "Deploy Now"를 누르면 인스턴스를 만들고 시작 스크립트를 실행한다.
- 과금은 시간당 종량제. **`brev stop`이면 과금 중단, `brev delete`면 완전 삭제.** 워크스페이스(`/home/ubuntu/workspace`)는 stop에는 살아남고 delete하면 사라진다.

### 5.2 NemoClaw Launchable 사용 흐름

우리가 참고 중인 링크: `https://brev.nvidia.com/launchable/deploy/now?launchableID=env-3Azt0aYgVNFEuz7opyx3gscmowS`

1. 링크를 열고 로그인. 인스턴스 타입·클라우드·시간당 비용을 확인하고 **Deploy NemoClaw** 클릭.
2. Configure → Setup → Launch 3단계. Configure 단계 "Connect to AI" 화면에서 `nvapi-` 키를 붙여 넣고 Create Agent.
3. Brev가 VM을 만들고 Docker/Container Toolkit/OpenShell CLI를 설치한 뒤 `nemoclaw setup`(gateway 생성, provider 등록, 샌드박스 실행)을 돌린다. 즉 **VM에 NemoClaw가 이미 설치된 상태**로 나온다. 로컬 설치 절차를 반복할 필요 없음.
4. 완료되면 OpenClaw 대시보드 링크가 열린다.

### 5.3 로컬 터미널(WSL)에서 Brev 인스턴스 다루기

```bash
brev login                                   # 브라우저 OAuth
brev ls                                      # 인스턴스 목록 (org: dayg502-e4a2df-hq)
brev shell <instance>                        # SSH 셸
brev port-forward <instance> --port 18789:18789   # 대시보드를 로컬로 터널
brev open <instance>                         # VS Code/Cursor로 열기 (beta)
brev copy ./local <instance>:/remote         # 파일 복사
brev stop <instance>                         # 과금 중단
brev delete <instance>                       # 삭제
```

VM 안에서는 로컬과 같은 `nemoclaw` 명령을 쓴다. 대시보드는 VM의 127.0.0.1:18789에만 바인딩되므로 반드시 port-forward(또는 `ssh -N -L 18789:127.0.0.1:18789`)로 본다.

무인 설치가 필요하면(직접 만든 VM에 설치할 때):

```bash
export NEMOCLAW_AGENT=openclaw
export NEMOCLAW_PROVIDER=build
export NEMOCLAW_SANDBOX_NAME=headless-agent
export NEMOCLAW_POLICY_TIER=balanced
export NEMOCLAW_NON_INTERACTIVE=1
export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
export NVIDIA_INFERENCE_API_KEY=nvapi-xxxx
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

알려진 함정(블로그 사례): `brev exec`는 stdin이 없어 마법사가 멈춤 → `brev shell`로 들어가서 실행하거나 무인 변수 사용. Docker-in-Docker에서 nvidia-container-runtime auto 모드가 실패하면 legacy 모드로 전환.

## 6. 자주 쓰는 nemoclaw 명령

| 명령 | 용도 |
|---|---|
| `nemoclaw onboard` | 마법사. gateway/샌드박스 생성·재생성 |
| `nemoclaw list` | 등록된 샌드박스(모델·provider·정책) |
| `nemoclaw <name> status` / `doctor` | 상태 확인 / 진단·복구 |
| `nemoclaw <name> start` / `stop` / `destroy` / `rebuild` | 수명주기 |
| `nemoclaw <name> policy list/add/remove <preset>` | 네트워크 정책 |
| `nemoclaw <name> mcp ...` | MCP 서버 연동 관리 |
| `nemoclaw <name> logs` | 로그 스트림 |
| `nemoclaw <name> dashboard` | 대시보드 URL |
| `nemoclaw <name> snapshot` / `backup-all` | 스냅샷·백업 |
| `nemoclaw config export <name>` | 자격증명 제외 YAML로 설정 내보내기 |
| `nemoclaw host probe` / `resources` | 호스트 사양 점검 |

샌드박스 안 채팅에서는 `/nemoclaw status`, `/nemoclaw onboard` 슬래시 명령 사용 가능.

## 7. 우리 프로젝트와의 연결점

- 에이전트별로 **별도 샌드박스**를 만들어야 강한 격리가 된다(`nemoclaw onboard`를 이름 달리해서 여러 번). 한 샌드박스 안에서 논리적으로 나눈 에이전트는 보안 경계가 아니다.
- "내부 지식 읽기 에이전트"는 Restricted tier + 필요한 내부 endpoint만 add, "외부 게시 에이전트"는 게시 채널 endpoint만 add하는 식으로 정책 분리를 실험할 수 있다.
- 정책 변경 권한은 호스트의 `nemoclaw` CLI에만 있고 샌드박스 안 에이전트에는 없다. 이 성질이 제안서의 "정책 변경 권한은 에이전트에게 주지 않는다"와 맞는다.
- 다음 할 일: 로컬(WSL2)에 `nemoclaw` 설치 → 샌드박스 2개(reader/publisher) 생성 → `policy list` 출력 비교 → MCP 연동 범위 확인.

## 참고 링크

- NemoClaw 문서: https://docs.nvidia.com/nemoclaw/latest/index.html
- Quickstart: https://docs.nvidia.com/nemoclaw/latest/get-started/quickstart.html
- Prerequisites: https://docs.nvidia.com/nemoclaw/user-guide/openclaw/get-started/prerequisites
- CLI 명령 레퍼런스: https://docs.nvidia.com/nemoclaw/user-guide/openclaw/reference/commands
- 원격 GPU/헤드리스 서버 배포: https://docs.nvidia.com/nemoclaw/latest/deployment/deploy-to-remote-gpu.html
- Brev 웹 UI로 NemoClaw 띄우기: https://docs.nvidia.com/nemoclaw/user-guide/openclaw/deployment/brev-web-ui
- GitHub: https://github.com/NVIDIA/NemoClaw
- Brev 문서: https://docs.nvidia.com/brev/getting-started/overview
- Brev Launchables 개념: https://docs.nvidia.com/brev/concepts/launchables
- Brev CLI 시작: https://docs.nvidia.com/brev/cli/getting-started
- 실전 삽질기(Brev + NemoClaw + Telegram): https://blog.juchunko.com/en/nemoclaw-brev-setup-guide/

## 8. API 키 관리 원칙

키는 **세 군데** 중 하나에만 있어야 한다. 셸 히스토리, Slack, 레포에는 절대 남기지 않는다.

| 용도 | 위치 | 비고 |
|---|---|---|
| 개인 개발(온보딩 때 한 번) | `~/.secrets/nvidia.env` (chmod 600) | 온보딩 후에는 OpenShell gateway가 키를 보관하므로 이후 매번 export할 필요 없음 |
| 레포에서 돌리는 서비스(LangGraph 등) | 레포 루트 `.env` (gitignore됨) | 커밋용 템플릿은 `.env.example` |
| Brev 인스턴스 | `brev secrets` (org 단위) | VM 생성 시 환경변수로 주입. Launchable 웹 UI에서 입력한 키도 여기로 감 |

개인 키 파일 만들기:

```bash
mkdir -p ~/.secrets && chmod 700 ~/.secrets
printf 'export NVIDIA_INFERENCE_API_KEY=nvapi-xxxx\n' > ~/.secrets/nvidia.env
chmod 600 ~/.secrets/nvidia.env
# 필요할 때만 로드 (zshrc에 항상 source하지 않는다)
source ~/.secrets/nvidia.env && curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```

팀 규칙:

- 키는 **1인 1키**. build.nvidia.com 발급은 무료이므로 공유하지 말고 각자 발급. 유출 시 해당 키만 폐기하면 된다.
- `.env.example`에는 키 이름만 두고 값은 비운다.
- 셸 히스토리에 키가 남지 않게 `export NVIDIA...=nvapi-` 를 직접 타이핑하지 말고 파일을 source한다.
- 샌드박스 안 에이전트에 키를 넘길 일이 생기면 설계가 잘못된 것이다. 키는 gateway 또는 MCP 연동(`nemoclaw <name> mcp`) 쪽에 두고, 에이전트는 자격증명 없이 호출만 한다.

## 9. 트러블슈팅: WSL2에서 온보딩 프리플라이트 실패 (2026-09-26)

증상: `nemoclaw onboard` 실행 시 아래 3개 blocking finding으로 온보딩이 중단됨.

| finding | 뜻 | 해결 |
|---|---|---|
| `host.platform.wsl_native_docker_unqualified` | WSL 안에 apt로 설치한 **네이티브 Docker Engine**은 NemoClaw가 "qualified"로 인정하지 않음. WSL2에서 인정하는 런타임은 **Docker Desktop(WSL integration)** 또는 **rootless Podman**(`NEMOCLAW_GATEWAY_RUNTIME=podman`) 두 가지뿐. 우회 플래그·환경변수 없음(소스 `src/lib/readiness/platform-qualification.ts` 확인) | Docker Desktop으로 전환 |
| `host.gpu.container_toolkit_missing` | nvidia-container-toolkit 미설치 | `--no-gpu`로 건너뜀 |
| `host.gpu.cdi_missing` | `/etc/cdi/nvidia.yaml` 없음 | `--no-gpu`로 건너뜀 |

GPU finding 2개는 로컬 GPU를 샌드박스에 넘길 때만 필요하다. 추론은 build.nvidia.com API로 하므로 **`--no-gpu`로 온보딩**하면 된다(RTX 4060 8GB로 로컬 모델을 돌릴 계획도 없음). 진짜 차단 요인은 네이티브 Docker 하나다.

### 조치: Docker Desktop 통합으로 전환

이 PC 상태(확인 결과): Windows에 Docker Desktop 설치돼 있으나 **꺼져 있음**, 설정은 "기본 WSL 배포판과 통합"이고 기본 배포판이 `Ubuntu-22.04`라 켜기만 하면 통합됨. WSL 안 네이티브 dockerd가 `/var/run/docker.sock`을 점유 중이며 다른 프로젝트(`~/git/cmf-agent`)의 compose 컨테이너 2개가 돌고 있음.

1. **cmf-agent 컨테이너 정리** (데이터는 `backend/data` 바인드 마운트라 안전. 이미지는 Desktop 쪽에서 다시 빌드해야 함)
   ```bash
   cd ~/git/cmf-agent && docker compose down
   ```
2. **네이티브 Docker 중지·비활성화** (소켓 충돌 방지). 이 PC의 WSL은 systemd가 아니라서(`PID 1 = init`) `systemctl`이 동작하지 않는다. dockerd는 `~/.zshrc`의 "Auto-start Docker on WSL2" 블록이 셸을 열 때마다 `sudo service docker start`로 띄우고 있었다.
   ```bash
   # ~/.zshrc 의 Auto-start Docker 블록을 주석 처리한 뒤
   sudo service docker stop
   ```
3. **Windows에서 Docker Desktop 실행** → Settings → Resources → WSL integration에서 `Ubuntu-22.04` 토글이 켜져 있는지 확인 → Apply.
4. **WSL에서 검증**
   ```bash
   docker info | grep -E "Operating System|Server Version"   # Operating System: Docker Desktop 이어야 함
   nemoclaw host probe                                        # wsl_native_docker_unqualified 사라져야 함
   ```
5. **온보딩**
   ```bash
   source ~/.secrets/nvidia.env
   nemoclaw onboard --no-gpu
   ```
6. cmf-agent가 다시 필요하면 Desktop 위에서 `docker compose up -d --build`.

이 뒤에 만난 오류 3개와 최종 해결은 [02-onboarding-qna.md](02-onboarding-qna.md)에 정리했다.

전환 결과(2026-09-27): 1~4단계 완료. `docker info`가 `Docker Desktop`으로 나오고 `nemoclaw host probe`의 blocking finding 3개가 모두 사라짐. 남은 것은 warning 1개(`host.platform.wsl_gpu_passthrough_inconclusive`)뿐이며 `--no-gpu` 온보딩에는 영향 없음. 앞으로는 **Docker Desktop이 켜져 있어야** WSL에서 `docker`가 동작한다.

되돌리기: Desktop 통합 끄고 `~/.zshrc`의 Auto-start Docker 블록 주석을 풀고 `sudo service docker start`.

### 대안

- **rootless Podman**: 네이티브 Docker를 유지하고 싶을 때. `sudo apt install podman lsof`, 사용자 socket/service 활성화, `NEMOCLAW_GATEWAY_RUNTIME=podman nemoclaw onboard --no-gpu`. 프리플라이트가 까다로워(cgroups v2, bridge, DNS, socket 소유권) 권장하지 않음.
- **Brev Launchable**: 로컬 Docker 문제를 아예 피하고 싶을 때. 5절 참고. 시간당 과금.
