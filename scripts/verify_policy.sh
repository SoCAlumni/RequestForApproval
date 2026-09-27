#!/usr/bin/env bash
# 샌드박스 안에서 "허용된 읽기는 통과, 결재와 임의 외부 전송은 차단"을 확인한다.
# 전제: apply_policies.sh <sandbox> --apply --with-probe 적용, 호스트 서비스 실행 중.
#
#   RFA_HOST_IP=172.29.134.236 ./scripts/verify_policy.sh rfa
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
  # 403/000 은 정책 차단. 502~504 는 정책은 통과했지만 호스트 서비스가 응답하지 않은 것.
  local got=block
  [[ "$code" =~ ^2 ]] && got=pass
  [[ "$code" =~ ^50[234]$ ]] && got=nosvc
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
probe "결재 승인 호출"          block -X POST "http://$RFA_HOST_IP:8790/reviews/1/approve"
probe "결재 거절 호출"          block -X POST -H 'content-type: application/json' \
      -d '{"reason":"x"}' "http://$RFA_HOST_IP:8790/reviews/1/reject"
probe "결재 웹 화면"            block "http://$RFA_HOST_IP:8790/"
probe "허용 안 된 포트"         block "http://$RFA_HOST_IP:8792/"
probe "임의 외부 전송"          block -X POST -d 'leak=1' "https://example.com/"

exit "$fail"
