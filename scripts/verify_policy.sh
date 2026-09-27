#!/usr/bin/env bash
# 샌드박스 안에서 "허용된 읽기는 통과, 결재와 임의 외부 전송은 차단"을 확인한다.
# 전제: apply_policies.sh <sandbox> --apply --with-probe 적용, 호스트 서비스 실행 중.
#
#   RFA_HOST_IP=172.29.134.236 ./scripts/verify_policy.sh public
set -uo pipefail

sandbox="${1:?usage: verify_policy.sh <sandbox>}"
: "${RFA_HOST_IP:?RFA_HOST_IP 를 지정하세요}"

fail=0
probe() {  # probe <설명> <기대: pass|block> <curl 인자...>
  local label="$1" expect="$2"
  shift 2
  local code
  code="$(nemoclaw "$sandbox" exec -- curl -s -m 5 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null)"
  code="${code:-000}"
  # 403/000 은 차단. 502~504 는 정책은 통과했지만 호스트 서비스가 응답하지 않은 것.
  # 그 밖의 코드(404 등)는 요청이 서비스까지 닿았다는 뜻이므로 차단으로 치지 않는다.
  local got=reach
  [[ "$code" =~ ^2 ]] && got=pass
  [[ "$code" =~ ^50[234]$ ]] && got=nosvc
  [[ "$code" == 403 || "$code" == 000 ]] && got=block
  local mark=OK
  if [[ "$got" == nosvc && "$expect" == pass ]]; then
    mark=WARN
  elif [[ "$got" != "$expect" ]]; then
    mark=FAIL
    fail=1
  fi
  printf '%-4s %-34s 기대=%-5s 결과=%-5s (HTTP %s)\n' "$mark" "$label" "$expect" "$got" "$code"
}

probe "review 목록 읽기"        pass  "http://$RFA_HOST_IP:8790/reviews"
probe "knowledge task 목록"     pass  "http://$RFA_HOST_IP:8791/tasks"
# 승인·거절은 없는 문서 번호로 호출한다. 정책이 뚫려 있어도 실제 문서가 결재되지 않게 하기 위해서다.
probe "결재 승인 호출"          block -X POST "http://$RFA_HOST_IP:8790/reviews/999999/approve"
probe "결재 거절 호출"          block -X POST -H 'content-type: application/json' \
      -d '{"reason":"x"}' "http://$RFA_HOST_IP:8790/reviews/999999/reject"
# 이 두 이름으로 들어온 요청은 호스트에서 127.0.0.1 출처로 보여 review 의 출처 검사를 통과한다.
probe "승인, host.docker.internal"   block -X POST "http://host.docker.internal:8790/reviews/999999/approve"
probe "승인, host.openshell.internal" block -X POST "http://host.openshell.internal:8790/reviews/999999/approve"
probe "결재 웹 화면"            block "http://$RFA_HOST_IP:8790/"
probe "허용 안 된 포트"         block "http://$RFA_HOST_IP:8792/"
probe "임의 외부 전송"          block -X POST -d 'leak=1' "https://example.com/"

exit "$fail"
