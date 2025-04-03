#!/bin/bash

# 공통 유틸 불러오기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_utils.sh"

# 도움말 출력 함수
function print_help() {
  cecho "Usage: $0 <name> --set nodePort=<nodePort> [additional --set options...]\n" $WHITE
  cecho "Required parameters:" $CYAN
  cecho "  <name>                     Name for the deployment and Helm release (e.g., username or department)" $WHITE
  echo ""
  cecho "Optional parameters:" $CYAN
  cecho "  --set nodePort=<port>      NodePort for the service (30000~32767, must not overlap)" $WHITE
  cecho "  --set nodeName=<node>      Kubernetes node to deploy to (default: any node)" $WHITE
  cecho "  --set storageSize=<size>   PVC size (default: 30G)" $WHITE
  cecho "  --set replica=<number>     Set the number of replica (default: 1) " $WHITE
  echo ""
  cecho "Example:" $CYAN
  cecho "  $0 example-user" $WHITE
  cecho "  $0 example-user --set nodePort=30001 --set nodeName=cui-worker-1" $WHITE
  cecho "  $0 example-user --set replica=3" $WHITE
  echo ""
}

# 실패/중단 시 자동 Helm uninstall
function cleanup_on_failure() {
  cecho "" $WHITE
  warn "Interrupted or failed."
  helm uninstall "$NAME" > /dev/null 2>&1 && success "Helm release '$NAME' deleted."
  exit 1
}

# 시그널 트랩 등록
trap cleanup_on_failure TERM ERR

# 글로벌 변수로 PID 저장
SPINNER_PID=""
# 스피너 종료 트랩 (스크립트가 어떤 이유로 종료되든 항상 실행됨)
cleanup_spinner_on_exit() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" > /dev/null 2>&1
    wait "$SPINNER_PID" 2>/dev/null
    echo -ne "\r\033[K"  # 줄 깔끔하게 지움
  fi
}

trap cleanup_spinner_on_exit EXIT

# --help 옵션 처리
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  print_help
  exit 0
fi

# 필수 인자 확인
if [ $# -lt 1 ]; then
  error "Missing required parameters."
  cecho "Use $0 --help for usage information." $WHITE
  exit 1
fi

# 릴리즈/배포 이름
NAME="$1"
shift
SET_NAME="--set name=$NAME"

# 네임스페이스 / PVC 설정
NAMESPACE="default"
PVC_NAME="cui-nfs-${NAME}-pvc"

# 기존 릴리즈 존재 시 삭제 여부 확인
if helm status "$NAME" > /dev/null 2>&1; then
  info "Helm release '$NAME' already exists."
  read -e -p "$(cecho "Do you want to delete and reinstall it? (y/N): " $YELLOW)" CONFIRM
    case "$CONFIRM" in
    y|Y|yes|YES)
      info "Uninstalling existing release..."
      helm uninstall "$NAME"

      info "Waiting for volume cleanup..."
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

      success "PVC and PV cleanup complete."
      ;;
    *)
      info "Installation aborted by user."
      exit 0
      ;;
  esac
fi

headline "������ Installing Helm release: $NAME"

# 스피너 시작 (백그라운드로)
start_spinner &
SPINNER_PID=$!

# Helm 설치 실행
helm install --wait "$NAME" $SCRIPT_DIR $SET_NAME "$@"
INSTALL_EXIT_CODE=$?

# 스피너 멈춤
stop_spinner $SPINNER_PID

# 설치 결과 확인
if [ $INSTALL_EXIT_CODE -ne 0 ]; then
  error "Helm installation failed."
  cleanup_on_failure
fi


# 성공 시 트랩 해제
trap - TERM ERR

# nodePort 조회
SERVICE_NAME="comfyui-$NAME-svc"
NODE_PORT=$(kubectl get svc "$SERVICE_NAME" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

# 노드 IP 조회 (첫 번째 Ready 노드 기준)
NODE_IP=$(kubectl get nodes -owide --no-headers | awk '$2 == "Ready" {print $6; exit}')

echo ""

if [[ -n "$NODE_PORT" && -n "$NODE_IP" ]]; then
  headline "������ Access URL"
  cecho "  → http://$NODE_IP:$NODE_PORT" $CYAN
else
  warn "Could not determine access URL. Make sure the service and node are available."
fi

success "������ Helm release '$NAME' installed successfully!"
