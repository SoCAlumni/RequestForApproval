## 포트 정리

작성일: 2026-09-27. 다영 PC(WSL2) 기준. 호스트 IP는 WSL `eth0` 주소 `172.29.134.236`이며 WSL을 재시작하면 바뀔 수 있다.

### 1. 포트 표

| 포트 | 무엇 | 띄우는 주체 | 바인딩 | 샌드박스에서 접근 |
|---|---|---|---|---|
| 8080 | OpenShell 게이트웨이. 정책 집행, API 키 보관, 추론 라우팅 | NemoClaw | `127.0.0.1` | 내부 경로로만 |
| 18789 | OpenClaw 대시보드. 에이전트와 대화하는 웹 UI | NemoClaw | `0.0.0.0` | 해당 없음 |
| 8790 | review 서비스. 결재 문서, 상태기계, 스캐너, 서명, 결재 웹 | 사람 (RFA_module) | `0.0.0.0` | 읽기와 초안 제출만 허용. 결재는 차단 |
| 8791 | knowledge stub. 실무대장(민섭) API 흉내 | 사람 (RFA_module) | `0.0.0.0` | `GET /tasks`, `POST /tasks/*/ask`만 허용 |
| 8792 | GitHub MCP 서버. 멘션 읽기, 스레드 읽기 | 사람 (RFA_module), 아직 안 띄움 | — | 차단. `mcp add` 후 허용 |

샌드박스 안에서만 보이는 주소:

| 주소 | 무엇 |
|---|---|
| `https://inference.local` | 모델 호출. 게이트웨이가 API 키를 붙여 NVIDIA Endpoints로 보낸다. 샌드박스는 키를 모른다 |
| `10.200.0.1:3128` | 샌드박스 프록시. 모든 외부 요청이 여기를 지나며 정책 검사를 받는다 |

### 2. 브라우저로 여는 곳

| 주소 | 화면 |
|---|---|
| `http://127.0.0.1:8790/` | RFA 결재함. 승인과 거절 |
| `http://127.0.0.1:18789/` | OpenClaw 대시보드 |
| `http://127.0.0.1:8790/docs` | review API 문서 (FastAPI 자동 생성) |
| `http://127.0.0.1:8791/docs` | knowledge API 문서 |

### 3. 서비스 띄우기

모듈 경로와 실행 명령의 원본은 레포 루트의 `modules.yaml`이다.

```bash
cd "${RFA_MODULE_DIR:-$HOME/git/RFA_module}"
export RFA_CLEARANCE_KEY=$(openssl rand -hex 32) RFA_PUBLISHER=mock
uv run uvicorn --factory review.app:create_app --host 0.0.0.0 --port 8790 &
uv run uvicorn knowledge_stub.app:app --host 0.0.0.0 --port 8791 &
```

`--host 0.0.0.0`이 필요한 이유: 샌드박스 컨테이너는 호스트의 `127.0.0.1`에 닿지 못한다. 호스트 IP로 들어오는 요청을 받으려면 loopback이 아닌 주소에 바인딩해야 한다.

### 4. 주의

- `0.0.0.0` 바인딩은 같은 네트워크의 다른 기기에서도 접근할 수 있다는 뜻이다. 공용 네트워크에서는 서비스를 내린다.
- 8790의 승인·거절은 두 겹으로 막는다. 샌드박스 네트워크 정책의 `deny_rules`, 그리고 review 서비스의 loopback 검사. 검증 결과는 [nemoclaw/03-policy-verification.md](nemoclaw/03-policy-verification.md).
- 포트 확인: `ss -ltnp | grep -E ":(8080|8790|8791|8792|18789)\b"`
