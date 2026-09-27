#!/usr/bin/env bash
# policies/*.yaml 의 __RFA_HOST_IP__ 를 채워 샌드박스에 적용한다.
#
#   RFA_HOST_IP=172.29.134.236 ./scripts/apply_policies.sh public            # 미리보기(dry-run)
#   RFA_HOST_IP=172.29.134.236 ./scripts/apply_policies.sh public --apply    # 적용
#   RFA_HOST_IP=... ./scripts/apply_policies.sh public --apply --with-probe  # 검증용 curl 정책 포함
set -euo pipefail

sandbox="${1:?usage: apply_policies.sh <sandbox> [--apply] [--with-probe]}"
shift
apply=0
presets=(rfa-host-services)
for arg in "$@"; do
  case "$arg" in
    --apply) apply=1 ;;
    --with-probe) presets+=(rfa-host-probe) ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

: "${RFA_HOST_IP:?RFA_HOST_IP 를 지정하세요 (샌드박스에서 닿는 호스트의 사설 IP)}"
if [[ ! "$RFA_HOST_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "RFA_HOST_IP 는 IPv4 리터럴이어야 합니다: $RFA_HOST_IP" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/policies/.rendered"
mkdir -p "$out"

for name in "${presets[@]}"; do
  sed "s/__RFA_HOST_IP__/$RFA_HOST_IP/g" "$root/policies/$name.yaml" > "$out/$name.yaml"
  cmd=(nemoclaw "$sandbox" policy add --from-file "$out/$name.yaml" --trusted-private-host "$RFA_HOST_IP")
  if (( apply )); then
    "${cmd[@]}" --yes
  else
    "${cmd[@]}" --dry-run
  fi
done

(( apply )) || echo "미리보기만 했습니다. 적용하려면 --apply 를 붙이세요."
