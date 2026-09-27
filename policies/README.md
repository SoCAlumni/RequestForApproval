# policies — 샌드박스 `public` 네트워크 정책

작성일: 2026-09-27. NemoClaw v0.0.129 기준. 근거는 RFA_module `docs/architecture.md` 4장 "Tool call 정책표".

## 파일

| 파일 | 용도 | 허용 바이너리 |
|---|---|---|
| `rfa-host-services.yaml` | LangGraph 워크플로가 호스트의 review(8790), knowledge(8791)를 호출 | python |
| `rfa-host-probe.yaml` | 검증 전용. 확인이 끝나면 제거 | curl |
| `.rendered/` | 호스트 IP가 채워진 생성물 (gitignore) | — |

github MCP(8792)는 `nemoclaw public mcp add`가 정책을 직접 만들기 때문에 여기 없다. `inference.local`은 기본 정책에 들어 있다.

## 정책표 대응

| 호출 주체 | 엔드포인트 | 정책 |
|---|---|---|
| LangGraph 노드 | `GET /tasks`, `POST /tasks/{id}/ask` | 허용 (`rfa_knowledge`) |
| LangGraph 노드 | `POST /reviews`, `/reviews/{id}/knowledge\|draft\|verdict\|needs-human` | 허용 (`rfa_review`) |
| LangGraph 노드 | `GET /reviews`, `GET /reviews/{id}`, `GET /policy/{scope}` | 허용 (`rfa_review`) |
| 사람만 | `POST /reviews/{id}/approve\|reject\|republish` | **거부** (`deny_rules`) |
| 사람만 | `POST /policy/{scope}/personal` | **거부** (`deny_rules`) |
| 사람만 | `GET /` 결재 웹 | 거부 (allow에 없음) |
| 아무도 | 그 밖의 호스트 포트, 임의 외부 주소 | 거부 (기본 정책) |

## 사용법

```bash
# 1. 미리보기: 생성되는 allowed_ips 와 허용 범위를 확인
RFA_HOST_IP=<호스트 IP> ./scripts/apply_policies.sh public

# 2. 적용 (검증용 curl 정책 포함)
RFA_HOST_IP=<호스트 IP> ./scripts/apply_policies.sh public --apply --with-probe

# 3. 검증: 읽기는 통과, 결재와 외부 전송은 차단
RFA_HOST_IP=<호스트 IP> ./scripts/verify_policy.sh public

# 4. 검증용 정책 제거
nemoclaw public policy remove rfa-host-probe --yes
```

## RFA_module `docs/setup.md`와 다른 점

| setup.md | 실제 (NemoClaw 문서 확인) | 조치 |
|---|---|---|
| `nemoclaw rfa hosts-add rfa-host.local $RFA_HOST_IP` | `hosts-add`는 Docker 드라이버 샌드박스에서 지원되지 않음 | 호스트명 대신 IP 리터럴 사용 |
| `policy add --from-file policies/rfa.yaml` | 사설 IP는 `--trusted-private-host`가 있어야 통과 | `apply_policies.sh`가 붙임 |
| review/knowledge도 HTTPS(caddy + mkcert) | HTTPS가 필수인 것은 `mcp add`뿐. 정책 preset은 HTTP도 허용 | review/knowledge는 HTTP, MCP만 HTTPS |
| MCP URL `https://rfa-host.local:8792/...` | 호스트명을 못 쓰므로 IP URL. 인증서에 IP SAN 필요 | `mkcert <호스트 IP>` |

## 확인이 필요한 것

- **`RFA_HOST_IP` 값.** 이 PC에서는 WSL `eth0` 주소(`172.29.134.236`)로 확인했다. WSL 재시작 시 바뀔 수 있다.
- **바이너리 경로.** 시스템 python은 `/usr/bin/python3.13`으로 확인했다. 워크플로를 venv에 설치하면 실제 실행 경로가 다를 수 있다. 막히면 프록시 로그의 DENIED 줄에 찍힌 경로로 `binaries`를 고친다.

## 정책을 고칠 때 지킬 것

- **호스트 서비스 주소는 IP로만 적는다.** `host.docker.internal`, `host.openshell.internal`은 정책에 넣지 않는다. 이 이름으로 들어온 요청은 호스트에서 `127.0.0.1` 출처로 보여서 review 서비스의 승인 출처 검사를 통과한다 (확인함. [검증 기록 5절](../docs/nemoclaw/03-policy-verification.md)).
- **승인·거절 경로의 `deny_rules`를 지우지 않는다.** 이 환경에서 샌드박스의 승인 호출을 막는 것은 네트워크 정책 하나다.
