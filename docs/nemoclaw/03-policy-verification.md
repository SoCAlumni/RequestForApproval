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

### 5. 남은 확인

- review 서비스의 loopback 가드가 Docker Desktop 환경에서도 유효한지. uvicorn 접근 로그에서 샌드박스 요청의 출처 주소가 `127.0.0.1`로 찍히는지 보면 된다 (policies/README.md "확인이 필요한 것").
