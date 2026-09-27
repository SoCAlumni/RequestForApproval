## 샌드박스 네트워크 정책 검증 기록

작성일: 2026-09-27. 샌드박스 `my-assistant`(OpenClaw v2026.9.1, OpenShell 0.0.116 docker 드라이버, NemoClaw v0.0.129)에 `policies/rfa-host-services.yaml`과 `policies/rfa-host-probe.yaml`을 적용하고 `scripts/verify_policy.sh`로 확인했다. 정책 설명은 [policies/README.md](../../policies/README.md) 참고.

### 1. 결과 요약

| 요청 (샌드박스 안 curl) | 정책 적용 전 | 적용 후, 서비스 없음 | 적용 후, 서비스 실행 | 판정 주체 |
|---|---|---|---|---|
| `GET inference.local/v1/models` | 200 | 200 | 200 | 기본 정책 |
| `POST https://example.com/` (임의 외부 전송) | 차단 | 차단 | 차단 | OPA, 허용된 엔드포인트 아님 |
| `GET :8790/reviews` | 403 | 502 | **200** | L7 allow |
| `GET :8791/tasks` | 403 | 502 | **200** | L7 allow |
| `POST :8790/reviews/1/approve` | 403 | 403 | **403** | L7 `deny_rules` |
| `POST :8790/reviews/1/reject` | 403 | 403 | **403** | L7 `deny_rules` |
| `GET :8790/` (결재 웹) | 403 | 403 | **403** | L7, allow에 없음 |
| `GET :8792/` (허용 안 된 포트) | 403 | 403 | **403** | OPA, 허용된 엔드포인트 아님 |

502는 정책이 요청을 통과시켰지만 호스트 서비스가 떠 있지 않을 때의 응답이다. review(8790)와 knowledge(8791)를 `0.0.0.0`으로 띄운 뒤 `verify_policy.sh` 7개 항목이 모두 기대대로 나왔다.

### 2. 프록시 로그 (차단 증거)

정책 적용 전:

```
NET:OPEN  DENIED /usr/bin/curl -> example.com:443 [engine:opa] [reason:endpoint example.com:443 is not allowed by any policy]
HTTP:POST DENIED /usr/bin/curl -> POST http://172.29.134.236:8790/reviews/1/approve [engine:opa] [reason:endpoint 172.29.134.236:8790 is not allowed by any policy]
```

정책 적용 후:

```
HTTP:GET  ALLOWED /usr/bin/curl -> GET http://172.29.134.236:8790/reviews [policy:nemoclaw_custom__rfa-host-probe__rfa_probe engine:l7]
HTTP:GET  ALLOWED /usr/bin/curl -> GET http://172.29.134.236:8791/tasks [policy:nemoclaw_custom__rfa-host-probe__rfa_probe engine:l7]
HTTP:POST DENIED  /usr/bin/curl -> POST http://172.29.134.236:8790/reviews/1/approve [engine:l7] [reason:... POST /reviews/1/approve blocked by deny rule]
HTTP:POST DENIED  /usr/bin/curl -> POST http://172.29.134.236:8790/reviews/1/reject [engine:l7] [reason:... POST /reviews/1/reject blocked by deny rule]
HTTP:GET  DENIED  /usr/bin/curl -> GET http://172.29.134.236:8790/ [engine:l7] [reason:... GET / not permitted by policy]
HTTP:GET  DENIED  /usr/bin/curl -> GET http://172.29.134.236:8792/ [engine:opa] [reason:endpoint 172.29.134.236:8792 is not allowed by any policy]
NET:OPEN  DENIED  /usr/bin/curl -> example.com:443 [engine:opa] [reason:endpoint example.com:443 is not allowed by any policy]
```

로그 보는 법: `docker logs <샌드박스 컨테이너> | grep DENIED`

### 3. 확인된 사실

- 같은 호스트·포트 안에서도 **메서드와 경로 단위로** 허용과 거부가 갈린다. 읽기는 통과하고 결재는 막힌다.
- 차단 로그에 **요청한 바이너리 경로, 메서드, 전체 URL, 거부 사유**가 남는다. 감사 기록과 UI의 차단 알림에 그대로 쓸 수 있다.
- 정책은 **바이너리 단위**다. `rfa-host-services`는 python만 허용하므로 같은 주소라도 curl은 통과하지 못한다(`rfa-host-probe`가 있어야 통과).
- 샌드박스의 python 실행 파일은 `/usr/bin/python3` → `/usr/bin/python3.13`. 정책의 `/usr/bin/python3*`에 포함된다.

### 4. 확정된 값

- `RFA_HOST_IP=172.29.134.236` (WSL eth0). 샌드박스에서 이 주소로 호스트 서비스에 닿는다. WSL을 재시작하면 주소가 바뀔 수 있으므로, 바뀌면 `apply_policies.sh`를 다시 실행한다.
- 검증 후 `rfa-host-probe`를 제거했다. 제거 뒤 같은 주소에 curl은 403, python은 200이다.
- `my-assistant`에 남은 정책: brew, huggingface, npm, openclaw-pricing, pypi, rfa-host-services.

### 5. 승인 출처 검사 확인

review 서비스는 `127.0.0.1`에서 온 요청만 승인·거절을 받는다. 이 검사가 Docker Desktop 환경에서도 통하는지 확인했다. 없는 문서 번호(`999999`)로 승인을 호출하면 검사에 걸릴 때 `403 loopback_only`, 검사를 통과할 때 `404 not_found`가 나오고 어느 쪽이든 상태는 바뀌지 않는다.

| 보낸 곳 | 주소 | 응답 | 뜻 |
|---|---|---|---|
| 호스트 | `127.0.0.1:8790` | 404 `not_found` | 검사 통과 (정상. 사람의 브라우저) |
| 호스트 | `172.29.134.236:8790` | 403 `loopback_only` | 검사에 걸림 |
| 컨테이너 (`openshell-docker` 네트워크) | `172.29.134.236:8790` | 403 `loopback_only` | 검사에 걸림 |
| 컨테이너 (`openshell-docker` 네트워크) | `host.docker.internal:8790` | **404 `not_found`** | **검사 통과. 뚫림** |

🔴 **문제**: `host.docker.internal`로 들어온 요청은 Docker Desktop이 대신 전달해서 호스트에서 `127.0.0.1` 출처로 보인다. 출처 주소만 보는 검사는 컨테이너에서 온 요청을 사람의 요청과 구분하지 못한다.

🟢 **현재 방어**: 샌드박스 안에서는 이 경로가 네트워크 정책에 막힌다. 허용된 프로그램(python)으로 보내도 같다.

```
DENIED /usr/bin/python3.13 -> POST http://host.docker.internal:8790/reviews/999999/approve   [reason:endpoint host.docker.internal:8790 is not allowed by any policy]
DENIED /usr/bin/python3.13 -> POST http://host.openshell.internal:8790/reviews/999999/approve [reason:endpoint host.openshell.internal:8790 is not allowed by any policy]
DENIED /usr/bin/python3.13 -> POST http://172.29.134.236:8790/reviews/999999/approve          [reason:... blocked by deny rule]
```

결론:

- 샌드박스에서 승인에 닿는 경로는 세 가지 모두 막혀 있다. 지금 상태는 안전하다.
- 다만 막고 있는 것은 네트워크 정책 하나다. review 서비스의 출처 검사는 이 환경에서 두 번째 방어선 역할을 하지 못한다.
- 누군가 정책에 `host.docker.internal:8790` 또는 `host.openshell.internal:8790`을 허용으로 추가하면 승인까지 열린다. 호스트 서비스 주소는 반드시 IP로 적고, 이 두 이름은 정책에 넣지 않는다.
- 샌드박스가 아닌 일반 컨테이너는 정책을 받지 않으므로 이 PC에서 도는 다른 컨테이너는 승인을 호출할 수 있다.

🟢 **권장 (RFA_module)**: 출처 주소 대신 비밀값으로 확인한다. 서비스 시작 때 승인용 토큰을 만들어 터미널에 보여 주고, 결재 웹이 승인·거절 요청에 그 토큰을 실어 보내게 한다. 토큰은 호스트에만 있으므로 어느 경로로 들어오든 샌드박스는 맞출 수 없다.
