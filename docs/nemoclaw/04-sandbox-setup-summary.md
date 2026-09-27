## RFA 샌드박스 권한 설정 가이드

> 이 가이드는 승희 님의 외부게시 모듈(RFA_module)을 NemoClaw 샌드박스에 올리기 위한 네트워크 정책과 에이전트 권한 설정을 설명합니다. 2026-09-27 작업을 정리했으며, 확인한 것과 확인하지 못한 것을 구분해 적었습니다.

제출 마감은 2026-09-28 23:59입니다. 그림은 [sandbox-layout.html](../sandbox-layout.html), 검증 로그는 [03-policy-verification.md](03-policy-verification.md)에 있습니다.

### 0. 사전 요구사항

- NemoClaw v0.0.129, OpenShell 0.0.116(docker 드라이버), Docker Desktop(WSL 통합). 설치 과정은 [02-onboarding-qna.md](02-onboarding-qna.md)
- 샌드박스 `my-assistant`가 Ready 상태 (`nemoclaw list`)
- RFA_module 클론. 위치는 레포 루트 `modules.yaml`과 `.env`의 `RFA_MODULE_DIR`로 관리
- Python 3.12+, `uv`

환경 값:

| 항목 | 값 |
|---|---|
| 호스트 IP (`RFA_HOST_IP`) | `172.29.134.236` (WSL eth0). WSL을 재시작하면 바뀔 수 있음 |
| 샌드박스 python | `/usr/bin/python3` → `/usr/bin/python3.13` |
| 검증한 RFA_module 커밋 | `a243c37` (main, Step 7) |

### 1. 구조 원칙

기밀 구획이 다르면 샌드박스를 나눈다. 한 샌드박스 안에서 에이전트를 나누는 것은 역할 구분이지 보안 경계가 아니다.

| | 샌드박스를 나눔 | 한 샌드박스 안에서 에이전트를 나눔 |
|---|---|---|
| 설정 파일 | `policies/*.yaml` | `agents/*.yaml` |
| 집행 주체 | OpenShell 프록시와 커널 | OpenClaw 런타임 |
| 파일시스템 | 따로 | 같이 씀 |
| 네트워크 정책 | 샌드박스마다 따로 | 같이 씀 |

- 네트워크 정책은 프로그램(바이너리) 단위다. 한 샌드박스의 OpenClaw 에이전트들은 같은 프로그램으로 돌기 때문에 정책이 에이전트를 구분하지 못한다.
- 샌드박스끼리는 직접 말하지 않는다. 호스트 서비스의 API로만 주고받고, 어느 경로를 열지는 네트워크 정책이 정한다.
- 에이전트 명단은 샌드박스 하나당 파일 하나로 둔다.

샌드박스 배치:

| 샌드박스 | 에이전트 | 상태 |
|---|---|---|
| `my-assistant` | `main` 비서 | 실행 중 |
| `rfa` | `main`(잠금), `public-desk`, 워크플로 | 아직 안 만듦 |
| `km` | 민섭 님 실무 에이전트 | 미정. 팀 합의 전의 가정 |

샌드박스는 네트워크만이 아니라 파일시스템, 프로세스, 기억의 관리 단위이기도 하다. 샌드박스 하나가 정책 문서 하나를 갖는다 (`nemoclaw <이름> status`로 확인).

| 항목 | `my-assistant`의 실제 값 | 집행 |
|---|---|---|
| 읽기 전용 경로 | `/usr`, `/lib`, `/etc`, `/app`, `/proc`, `/var/log`, `/var/lib/dpkg` | 커널(Landlock) |
| 읽기·쓰기 경로 | `/tmp`, `/sandbox/.openclaw`, `/sandbox/.nemoclaw`, `/home/linuxbrew` | 커널(Landlock) |
| 실행 계정 | `sandbox` 사용자와 그룹 | 컨테이너 |
| 네트워크 | 허용 주소, 포트, 메서드, 경로, 프로그램 | 샌드박스 전용 프록시 |
| 네트워크 공간 | 샌드박스마다 별도 네임스페이스 | 커널 |
| 자격증명 | 게이트웨이가 보관. 샌드박스에는 없음 | 게이트웨이 |

무엇을 어떻게 바꾸는지:

| 바꾸려는 것 | 방법 | 샌드박스 재생성 |
|---|---|---|
| 네트워크 허용 | `nemoclaw <이름> policy add/remove` | 필요 없음 |
| 파일시스템 경로 | 에이전트 기본 정책 파일 수정 후 온보딩 | 필요 |
| 호스트 폴더 연결 | `nemoclaw onboard --host-mount <호스트:/sandbox/경로>` | 필요 |
| 에이전트 도구 권한 | `agents/*.yaml` | 필요 |

`policies/*.yaml`은 이 중 네트워크만 다룬다. 파일시스템 변경 절차는 옵션 이름만 확인했고 직접 해 보지 않았다.

한 샌드박스 안에서는 에이전트 사이에 하드한 경계를 만들 수 없다.

- 에이전트들은 `openclaw-gateway` 프로세스 하나 안에서 같은 계정(`sandbox`)으로 돈다. 커널 정책은 프로세스에 걸리므로 에이전트를 구분하지 못한다.
- OpenClaw 문서도 에이전트 작업 폴더를 "기본 작업 위치일 뿐 하드 샌드박스가 아니다"라고 적는다. 절대 경로를 쓰면 다른 에이전트의 폴더에 닿는다.
- OpenClaw 자체의 에이전트별 샌드박스(`sandbox.mode`)는 Docker가 필요한데, NemoClaw 샌드박스 안에는 docker, podman, bwrap, unshare가 없다.
- 기억 검색은 기본값이 에이전트별이다. 공유는 `memory.search.extraPaths`에 명시한 경로만 된다. 다만 이것은 설정이지 강제가 아니다.
- 같은 샌드박스에서 도는 다른 프로그램(예: 워크플로 python)은 도구 제한을 받지 않고 `/sandbox/.openclaw` 전체를 읽을 수 있다.

따라서 기억을 확실히 나눠야 하는 에이전트는 샌드박스를 나눈다. 샌드박스를 나누면 기억 파일이 그 샌드박스의 파일시스템에 있으므로 함께 나뉜다.

> 💡 `my-assistant`의 Landlock은 `best_effort`다. 커널이 규칙을 적용하지 못해도 샌드박스가 뜬다. 기동 로그에는 규칙 14개 적용, 3개 건너뜀으로 나왔고 건너뛴 규칙이 무엇인지는 확인하지 않았다. 기밀을 다루는 샌드박스는 `strict`가 맞지만, 환경에 따라 샌드박스가 뜨지 않을 수 있어 시험이 필요하다.

### 2. 모듈 레지스트리

모듈 레포의 위치, 검증한 커밋, 포트, 실행 명령을 레포 루트 `modules.yaml`에 적는다. 문서와 스크립트에는 경로를 직접 적지 않는다.

```bash
# .env (각자)
RFA_MODULE_DIR=/내/클론/경로/RFA_module     # 비우면 ~/git/RFA_module
```

> 💡 `ref`는 기록일 뿐 강제가 아니다. 모듈이 바뀌어 다시 검증하면 함께 올린다. 아직 이 파일을 읽는 스크립트는 없다.

### 3. 호스트 서비스 띄우기

```bash
cd "${RFA_MODULE_DIR:-$HOME/git/RFA_module}"
export RFA_CLEARANCE_KEY=$(openssl rand -hex 32) RFA_PUBLISHER=mock
uv run uvicorn --factory review.app:create_app --host 0.0.0.0 --port 8790 &
uv run uvicorn knowledge_stub.app:app --host 0.0.0.0 --port 8791 &
```

> 💡 샌드박스는 호스트의 `127.0.0.1`에 닿지 못하므로 `--host 0.0.0.0`이 필요하다. 같은 네트워크의 다른 기기에서도 접근할 수 있게 되므로 공용 네트워크에서는 내린다.

포트 전체 목록은 [ports.md](../ports.md).

### 4. 네트워크 정책 적용

```bash
# 미리보기
RFA_HOST_IP=172.29.134.236 ./scripts/apply_policies.sh my-assistant

# 적용 (검증용 curl 정책 포함)
RFA_HOST_IP=172.29.134.236 ./scripts/apply_policies.sh my-assistant --apply --with-probe
```

`policies/rfa-host-services.yaml`이 여는 경로:

| 대상 | 허용 | 명시적 거부 |
|---|---|---|
| review `:8790` | `POST /reviews`, `GET /reviews`, `GET /reviews/*`, `POST /reviews/*/knowledge\|draft\|verdict\|needs-human`, `GET /policy/*` | `/reviews/*/approve\|reject\|republish`, `POST /policy/**` |
| knowledge `:8791` | `GET /tasks`, `POST /tasks/*/ask` | — |

허용 프로그램은 python뿐이다. GitHub MCP(8792)는 `nemoclaw <샌드박스> mcp add`가 정책을 따로 만들기 때문에 이 파일에 없다.

> 💡 사설 IP는 `--trusted-private-host`가 있어야 통과한다. 스크립트가 붙인다. 정책 파일에 `allowed_ips`를 직접 적으면 거부된다.

### 5. 검증

```bash
RFA_HOST_IP=172.29.134.236 ./scripts/verify_policy.sh my-assistant
nemoclaw my-assistant policy remove rfa-host-probe --yes     # 검증용 정책 제거
```

결과 (2026-09-27):

```
OK   review 목록 읽기        기대=pass  결과=pass  (HTTP 200)
OK   knowledge task 목록     기대=pass  결과=pass  (HTTP 200)
OK   결재 승인 호출          기대=block 결과=block (HTTP 403)
OK   결재 거절 호출          기대=block 결과=block (HTTP 403)
OK   결재 웹 화면            기대=block 결과=block (HTTP 403)
OK   허용 안 된 포트         기대=block 결과=block (HTTP 403)
OK   임의 외부 전송          기대=block 결과=block (HTTP 000)
```

- 검증용 정책을 제거한 뒤 같은 주소에 curl은 403, python은 200이었다. 프로그램 단위 제한이 동작한다.
- 차단 로그에는 프로그램 경로, 메서드, URL, 거부 사유가 남는다. `docker logs <샌드박스 컨테이너> | grep DENIED`

```
HTTP:POST DENIED /usr/bin/curl -> POST http://172.29.134.236:8790/reviews/1/approve [reason:... blocked by deny rule]
NET:OPEN  DENIED /usr/bin/curl -> example.com:443 [reason:endpoint example.com:443 is not allowed by any policy]
```

### 6. 에이전트 명단

`agents/rfa.yaml`은 `rfa` 샌드박스 전용이다.

| 에이전트 | 허용 | 거부 |
|---|---|---|
| `main` | 없음 (`profile: minimal`) | 셸, 파일, 웹, 브라우저, 다른 에이전트 호출, 메시징, cron, MCP 도구 |
| `public-desk` | `github__list_mentions`, `github__get_thread`, `workflow__run` | 셸, 파일, 웹, 브라우저, 다른 에이전트 호출, 메시징, cron |

```bash
source ~/.secrets/nvidia.env
nemoclaw onboard --name rfa --agents agents/rfa.yaml --no-gpu
```

> 💡 `main`은 명단에 없어도 항상 들어가고 기본값이 셸 실행까지 허용이다. 외부 입력을 다루는 샌드박스에서는 `main`도 잠가야 한다.

> 💡 도구 권한은 이미지에 구워진다. 바꾸려면 `--recreate-sandbox`로 다시 만들어야 하고 시간이 걸린다.

### 7. RFA_module 문서와 다른 점

승희 님 `docs/setup.md`, `docs/modules/agents.md`대로는 동작하지 않는 부분이다.

🔴 **`nemoclaw rfa hosts-add rfa-host.local`**: Docker 드라이버 샌드박스에서 지원되지 않는다.
🟢 **조치**: 호스트명 대신 IP 리터럴을 쓴다. MCP 인증서는 `mkcert <호스트 IP>`로 IP SAN을 넣는다.

🔴 **`policy add --from-file`만 실행**: 사설 IP 대상은 거부된다.
🟢 **조치**: `--trusted-private-host <IP>`를 함께 넘긴다.

🔴 **review, knowledge까지 HTTPS로 구성(caddy + mkcert)**: 필요 이상의 설정이다.
🟢 **조치**: HTTPS가 필수인 것은 `mcp add`뿐이다. review와 knowledge는 HTTP로 둔다.

🔴 **`agents.yaml`의 `cron:` 최상위 키**: 허용 키는 `agents`, `defaults`, `main`뿐이라 로드에 실패한다.
🟢 **조치**: 샌드박스 안에서 `openclaw cron add`로 등록한다.

🔴 **`workspace: ./agents/public-desk`, `model: anthropic/...`, `name:`**: 각각 절대 경로만 허용, 온보딩한 provider의 모델만 허용, 없는 키.
🟢 **조치**: `workspace`와 `model`은 생략하고 `name`은 `description`으로 바꾼다.

🔴 **`allow: [github, workflow]`**: 서버 이름은 도구 이름이 아니다.
🟢 **조치**: `서버__도구` 형식으로 하나씩 적는다. `github__*` 같은 와일드카드는 쓰지 않는다. 나중에 게시 도구가 추가돼도 자동 허용되지 않게 하기 위해서다.

🔴 **모듈별 `agents.yaml` 조각을 하나로 병합**: 모든 에이전트가 한 샌드박스에 들어가 구획 분리가 사라진다.
🟢 **조치**: 샌드박스별 파일로 둔다. 비서가 `public-desk`에 위임하는 `subagents.allowAgents` 경로는 샌드박스가 다르면 쓸 수 없으므로 API로 대체한다.

### 8. 확인하지 못한 것

- **승인 출처 검사.** review 서비스는 `127.0.0.1` 출처만 승인을 받는다. Docker Desktop이 요청을 대신 전달하면 샌드박스 요청이 호스트에서 `127.0.0.1`로 보일 수 있다. 그렇다면 승인 차단은 프록시 규칙 하나에 기대게 된다. uvicorn 로그에서 샌드박스 요청의 출처 주소를 보면 결론이 난다.
- **POST 경로.** 초안과 판정 제출은 규칙만 적용했고 실제 호출은 하지 않았다. 워크플로(Step 8)가 머지된 뒤 확인한다.
- **도구 이름.** MCP 서버가 `github`, `workflow`로 등록된다는 전제다.
- **도구 거부의 실제 동작.** `agents/rfa.yaml`은 NemoClaw 검증기를 통과했지만 샌드박스에 구워 보지 않았다.
- **GitHub MCP.** 8792를 띄우지 않았고 `mcp add`도 하지 않았다.
- **`get_thread(target)` 인자.** 임의 레포를 지정할 수 있으면 그 문자열이 작은 유출 통로가 된다. MCP 서버가 감시 대상 레포만 받는지 확인하지 않았다.
- **메모리.** 샌드박스 두 개를 동시에 띄웠을 때의 사용량.

### 9. 현재 상태와 남은 일

현재 상태:

- `my-assistant`에 `rfa-host-services` 정책이 붙어 있다. 검증하느라 임시로 붙인 것이고, `rfa`를 만들면 옮긴다.
- RFA_module은 Step 7까지 main에 있고 Step 8(LangGraph 워크플로)은 PR #10으로 열려 있다.
- 이 레포의 변경은 아직 커밋하지 않았다.

남은 일:

| 순서 | 일 | 조건 |
|---|---|---|
| 1 | uvicorn 로그로 승인 출처 검사 확인 | 지금 가능 |
| 2 | `rfa` 샌드박스 생성, 정책 이전, MCP 등록, 워크플로 업로드 | Step 8 머지 후 한 번에 |
| 3 | 도구 거부 동작과 POST 경로 검증 | 2번 후 |
| 4 | 차단 로그를 UI의 활동 타임라인에 연결 | 지금 가능 |
| 5 | README 실행법, 제출 자료 | 9/28 |

팀 미팅 안건:

- 에이전트 명단을 병합하지 않고 샌드박스별로 두는 방침
- 민섭 님 에이전트를 어느 샌드박스에 둘지, knowledge API를 어디서 띄울지
- 민섭 님 세 업무(ORBIT 벤치마크, 양자화, PRISM)가 서로의 기억을 봐도 되는지. 봐도 되면 샌드박스 하나에 에이전트 셋, 안 되면 샌드박스를 나눈다. 미공개 수치를 다루는 업무와 공개 글을 쓰는 업무는 나누는 쪽이 원칙에 맞다
- knowledge API가 돌려주는 내용의 범위. 원문을 그대로 주면 받는 쪽 샌드박스에 기밀이 들어온다. 공개 가능한 표현만 줄지, 원문을 주고 게시 전 기밀검토에 맡길지
- 7절의 RFA_module 문서 수정
- 제출 형식. 심사자가 레포 하나만 받아 실행해야 한다면 `modules.yaml` 대신 submodule이나 클론 순서 안내가 필요하다

### 10. 참고 사항

만든 파일:

| 파일 | 내용 |
|---|---|
| `modules.yaml` | 모듈 레지스트리 |
| `agents/rfa.yaml` | `rfa` 샌드박스 에이전트 명단 |
| `policies/rfa-host-services.yaml` | 호스트 서비스 접근 정책 |
| `policies/rfa-host-probe.yaml` | 검증 전용 curl 정책 |
| `policies/README.md` | 정책표 대응, 사용법 |
| `scripts/apply_policies.sh` | 호스트 IP를 채워 미리보기 또는 적용 |
| `scripts/verify_policy.sh` | 통과 2건, 차단 5건 확인 |
| `docs/ports.md` | 포트 정리 |
| `docs/sandbox-layout.html` | 샌드박스 배치도 |
| `docs/nemoclaw/03-policy-verification.md` | 검증 기록과 로그 |

알아둘 점:

- 온보딩이 실행 중일 때 다른 터미널에서 `nemoclaw` 명령을 돌리면 잠금 대기로 멈춘다.
- `nemoclaw onboard --resume`에는 매번 `--no-gpu`를 붙인다. 세션에 저장되지 않는다.
- 502는 정책은 통과했지만 호스트 서비스가 응답하지 않은 것이고, 403은 정책이 막은 것이다.
- 근거 문서는 설치된 소스의 `~/.nemoclaw/source/docs/network-policy/`, `docs/inference/declarative-agents-manifest.mdx`, `schemas/*.json`.
