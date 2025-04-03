#!/bin/bash

# 공통 유틸 불러오기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_utils.sh"

# 도움말
function print_help() {
  cecho "Usage: $0 <name>" $WHITE
  cecho "" $WHITE
  cecho "  <name>    Name of the Helm release (also used to find PVC/PV)" $WHITE
  cecho "" $WHITE
  cecho "Example:" $CYAN
  cecho "  $0 example-user" $WHITE
  echo ""
}

# 파라미터 확인
if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
  print_help
  exit 0
fi

NAME="$1"
NAMESPACE="default"
PVC_NAME="cui-nfs-${NAME}-pvc"

# 릴리즈 존재 여부 확인
if ! helm status "$NAME" > /dev/null 2>&1; then
  warn "Helm release '$NAME' not found. Nothing to delete."
  exit 0
fi

# 삭제 시작
headline "������️  Deleting Helm release: $NAME"
helm uninstall "$NAME"
info "Helm uninstall command issued."

# PVC/PV 삭제 대기
info "Waiting for volumes to be deleted..."
TIMEOUT=120
ELAPSED=0

while kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" > /dev/null 2>&1 || kubectl get pv | grep -q "$PVC_NAME"; do
  if [ $ELAPSED -ge $TIMEOUT ]; then
    error "Timed out waiting for volumes to be deleted."
    exit 1
  fi
  cnecho "[INFO] Still waiting... (${ELAPSED}s)\r" $CYAN
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

success "\n\n✅ Volume cleanup complete!"
