#!/bin/bash

# 도움말 함수
function print_help() {
  echo "Usage: $0 <release-name> --set name=<name> --set nodePort=<nodePort> [additional --set options...]"
  echo ""
  echo "Required parameters:"
  echo "  <release-name>             Name of the Helm release (e.g., 'my-release')"
  echo "  --set name=<name>          Name for the deployment (e.g., username or department)"
  echo "  --set nodePort=<nodePort>  Port for accessing the service (30000~32767, must not overlap)"
  echo ""
  echo "Optional parameters:"
  echo "  --set nodeName=<nodeName>          Kubernetes node to deploy the resources (default: scheduler decides)"
  echo "  --set storageSize=<storageSize>    Storage size for the deployment (e.g., 10G, default: 30G)"
  echo ""
  echo "Example:"
  echo "  $0 my-release --set name=example-user --set nodePort=30001 --set nodeName=node1 --set storageSize=50G"
  echo ""
}

# --help 옵션 처리
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  print_help
  exit 0
fi

# 필수 값 확인
if [ $# -lt 3 ]; then
  echo "Error: Missing required parameters."
  echo "Use $0 --help for usage information."
  exit 1
fi

RELEASE_NAME="$1"
shift

# Helm 설치 명령어 실행
echo "helm install "$RELEASE_NAME" . "$@""
helm install "$RELEASE_NAME" . "$@"

# 설치 성공 여부 확인
if [ $? -ne 0 ]; then
  echo "Helm installation failed. Exiting."
  exit 1
fi

echo "Helm installation succeeded. Waiting for resources to be ready..."

# 리소스 준비 상태 확인
WAIT_TIMEOUT=600  # 최대 대기 시간 (초)
INTERVAL=3       # 상태 확인 간격 (초)
ELAPSED_TIME=0


# 사용자 입력에서 name 값을 추출
NAME_VALUE=$(echo "$@" | grep -oP '(?<=--set name=)[^ ]+')

if [ -z "$NAME_VALUE" ]; then
  echo "Error: --set name=<name> parameter is required."
  exit 1
fi

# TODO: Pod에 Readiness Probe 추가 후에 Ready 여부로 판단 필요
LABEL="app=comfyui-$NAME_VALUE"

while true; do
  # 특정 라벨을 가진 Pod의 Ready 상태 확인
  READY_COUNT=$(kubectl get pods --selector "$LABEL" --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c "True")
  TOTAL_COUNT=$(kubectl get pods --selector "$LABEL" --no-headers 2>/dev/null | wc -l)

  # 모든 Pod가 준비되었는지 확인
  if [ "$READY_COUNT" -eq "$TOTAL_COUNT" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
    echo "All Pods with label $LABEL are ready."
    break
  fi

  # 대기 시간 초과 처리
  if [ "$ELAPSED_TIME" -ge "$WAIT_TIMEOUT" ]; then
    echo "Timeout while waiting for Pods with label $LABEL to be ready. Deleting release..."
    helm uninstall "$RELEASE_NAME"
    echo "Release deleted due to timeout."
    exit 1
  fi

  # 대기
  echo "Waiting for Pods with label $LABEL to be ready... ($ELAPSED_TIME/$WAIT_TIMEOUT seconds elapsed)"
  sleep "$INTERVAL"
  ELAPSED_TIME=$((ELAPSED_TIME + INTERVAL))
done

echo "Helm installation and resource readiness check completed successfully."
