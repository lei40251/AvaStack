#!/usr/bin/env bash

# AvaStack 的 Unix 启动内核。
# 这个脚本负责承接 macOS / Linux 两个入口脚本的公共逻辑：
# 1. 一次性检查本地工具链或 Docker 环境
# 2. 提前提醒代理配置，避免下载阶段中途报错
# 3. 先做宿主机端口预检，再执行 docker compose build / up
# 4. 在构建失败时尽量把错误归类，减少排障绕路

set -u
set -o pipefail

MODE="docker"
PROXY=""
PLATFORM=""
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTENV_FILE="$PROJECT_ROOT/.env"
DOTENV_EXAMPLE_FILE="$PROJECT_ROOT/.env.example"

REQUIRED_PYTHON_VERSION="3.11.0"
REQUIRED_GO_VERSION="1.22.0"
REQUIRED_NODE_VERSION="20.0.0"

US=$'\x1f'
CHECK_ROWS=()
LOCAL_PYTHON_CMD=""
LOCAL_PYTHON_DISPLAY="python3"

COLOR_RESET=""
COLOR_CYAN=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
COLOR_DIM=""

init_colors() {
  if [[ -t 1 ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_CYAN=$'\033[36m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_RED=$'\033[31m'
    COLOR_DIM=$'\033[90m'
  fi
}

print_info() {
  printf '%b%s%b\n' "$COLOR_DIM" "$1" "$COLOR_RESET"
}

print_success() {
  printf '%b%s%b\n' "$COLOR_GREEN" "$1" "$COLOR_RESET"
}

print_warn() {
  printf '%b%s%b\n' "$COLOR_YELLOW" "$1" "$COLOR_RESET"
}

print_error() {
  printf '%b%s%b\n' "$COLOR_RED" "$1" "$COLOR_RESET" >&2
}

write_section_header() {
  printf '\n%b[%s]%b\n' "$COLOR_CYAN" "$1" "$COLOR_RESET"
}

usage() {
  cat <<'EOF'
用法：
  ./start-macos.sh [--mode docker|local] [--proxy http://<代理主机>:<端口>]
  ./start-linux.sh [--mode docker|local] [--proxy http://<代理主机>:<端口>]

参数说明：
  --mode   启动模式，默认 docker
  --proxy  可选。用于 docker compose build 阶段依赖下载的代理地址
  -h, --help  显示帮助
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        [[ $# -ge 2 ]] || { print_error "--platform 缺少参数"; exit 1; }
        PLATFORM="$2"
        shift 2
        ;;
      --mode)
        [[ $# -ge 2 ]] || { print_error "--mode 缺少参数"; exit 1; }
        MODE="$2"
        shift 2
        ;;
      --proxy)
        [[ $# -ge 2 ]] || { print_error "--proxy 缺少参数"; exit 1; }
        PROXY="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        print_error "无法识别的参数：$1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ "$PLATFORM" != "macos" && "$PLATFORM" != "linux" ]]; then
    print_error "必须通过包装脚本传入 --platform macos 或 --platform linux"
    exit 1
  fi

  if [[ "$MODE" != "docker" && "$MODE" != "local" ]]; then
    print_error "--mode 只支持 docker 或 local"
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

resolve_command_path() {
  local candidate
  for candidate in "$@"; do
    if command_exists "$candidate"; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

get_command_output_text() {
  local output
  if output="$("$@" 2>/dev/null)"; then
    printf '%s' "$output"
    return 0
  fi
  return 1
}

extract_version() {
  local text="$1"
  printf '%s' "$text" | sed -nE 's/.*([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n 1
}

version_at_least() {
  local current="$1"
  local minimum="$2"

  [[ -n "$current" && -n "$minimum" ]] || return 1

  awk -v a="$current" -v b="$minimum" '
    BEGIN {
      split(a, aa, ".")
      split(b, bb, ".")
      for (i = 1; i <= 4; i++) {
        x = (aa[i] == "" ? 0 : aa[i]) + 0
        y = (bb[i] == "" ? 0 : bb[i]) + 0
        if (x > y) exit 0
        if (x < y) exit 1
      }
      exit 0
    }
  '
}

append_row() {
  CHECK_ROWS+=("$1$US$2$US$3$US$4$US$5$US$6$US$7")
}

write_check_table() {
  printf '%-18s %-18s %-8s %s\n' "组件" "要求" "结果" "当前状态"
  printf '%-18s %-18s %-8s %s\n' "----" "----" "----" "----"

  local row id component requirement result current passed hint
  for row in "${CHECK_ROWS[@]}"; do
    IFS="$US" read -r id component requirement result current passed hint <<< "$row"
    printf '%-18s %-18s %-8s %s\n' "$component" "$requirement" "$result" "$current"
  done
}

ensure_dotenv_exists() {
  if [[ ! -f "$DOTENV_FILE" && -f "$DOTENV_EXAMPLE_FILE" ]]; then
    cp "$DOTENV_EXAMPLE_FILE" "$DOTENV_FILE"
    print_success "已根据 .env.example 创建 .env"
  fi
}

get_dotenv_value() {
  local name="$1"
  [[ -f "$DOTENV_FILE" ]] || return 1

  local line
  line="$(grep -E "^${name}=" "$DOTENV_FILE" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1

  line="${line#*=}"
  line="${line#\"}"
  line="${line%\"}"
  line="${line#\'}"
  line="${line%\'}"
  printf '%s' "$line"
}

get_effective_env_value() {
  local name="$1"
  local default_value="$2"
  local process_value="${!name:-}"

  if [[ -n "$process_value" ]]; then
    printf '%s' "$process_value"
    return 0
  fi

  local dotenv_value
  dotenv_value="$(get_dotenv_value "$name" || true)"
  if [[ -n "$dotenv_value" ]]; then
    printf '%s' "$dotenv_value"
    return 0
  fi

  printf '%s' "$default_value"
}

get_current_proxy_url() {
  local name
  for name in HTTPS_PROXY HTTP_PROXY ALL_PROXY https_proxy http_proxy all_proxy; do
    if [[ -n "${!name:-}" ]]; then
      printf '%s' "${!name}"
      return 0
    fi
  done
  return 1
}

get_proxy_example_value() {
  if [[ -n "$PROXY" ]]; then
    printf '%s' "$PROXY"
    return 0
  fi

  local current_proxy
  current_proxy="$(get_current_proxy_url || true)"
  if [[ -n "$current_proxy" ]]; then
    printf '%s' "$current_proxy"
    return 0
  fi

  printf '%s' 'http://<代理主机>:<端口>'
}

set_proxy_for_session() {
  local url="$1"
  export HTTP_PROXY="$url"
  export HTTPS_PROXY="$url"
  export ALL_PROXY="$url"
  export http_proxy="$url"
  export https_proxy="$url"
  export all_proxy="$url"
}

write_proxy_reminder() {
  local scenario="$1"
  local proxy_example
  proxy_example="$(get_proxy_example_value)"

  printf '\n'
  print_warn "下载前代理提醒："
  print_info "  如果你当前网络访问外网较慢或受限，建议先在当前 Shell 会话里设置代理，再执行下面需要下载的步骤。"
  printf '%b%s%b\n' "$COLOR_CYAN" "  export HTTP_PROXY=\"$proxy_example\"" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "  export HTTPS_PROXY=\"$proxy_example\"" "$COLOR_RESET"
  printf '\n'
  print_info "  配置完代理后，直接继续执行下面的命令即可，不需要额外改脚本。"
  print_info "  注意：这个代理主要用于 docker compose build 阶段容器内的 pip / npm / go 下载。"
  print_info "  如果报错发生在 FROM 基础镜像拉取阶段，还需要给 Docker daemon 单独配置代理。"

  if [[ "$scenario" == "docker" ]]; then
    print_info "  Docker 模式也支持直接这样传入代理："
    printf '%b%s%b\n' "$COLOR_CYAN" "  ./start-$PLATFORM.sh --mode docker --proxy \"$proxy_example\"" "$COLOR_RESET"
  fi
}

write_rerun_hint() {
  printf '\n'
  print_warn "安装完成后可重新执行："
  printf '%b%s%b\n' "$COLOR_CYAN" "  $1" "$COLOR_RESET"
}

detect_python_command() {
  if command_exists python3; then
    LOCAL_PYTHON_CMD="python3"
    LOCAL_PYTHON_DISPLAY="python3"
    return 0
  fi

  if command_exists python; then
    LOCAL_PYTHON_CMD="python"
    LOCAL_PYTHON_DISPLAY="python"
    return 0
  fi

  LOCAL_PYTHON_CMD=""
  LOCAL_PYTHON_DISPLAY="python3"
  return 1
}

# 一次性检查本地开发模式所需工具链，避免修完一个依赖后还得反复重跑脚本。
test_local_prerequisites() {
  CHECK_ROWS=()
  detect_python_command || true

  local python_version_text python_version python_result python_current
  if [[ -z "$LOCAL_PYTHON_CMD" ]]; then
    append_row "python" "Python" ">= 3.11" "缺少" "未检测到" "false" "先安装 Python 3.11+。"
    append_row "pip" "pip" "可用" "缺少" "未检测到 Python，无法检查" "false" "安装 Python 时请包含 pip。"
  else
    python_version_text="$("$LOCAL_PYTHON_CMD" --version 2>/dev/null || true)"
    python_version="$(extract_version "$python_version_text")"
    if version_at_least "$python_version" "$REQUIRED_PYTHON_VERSION"; then
      python_result="通过"
    elif [[ -n "$python_version" ]]; then
      python_result="版本偏低"
    else
      python_result="无法识别版本"
    fi

    python_current="$python_version_text"
    append_row "python" "Python" ">= 3.11" "$python_result" "$python_current" "$([[ "$python_result" == "通过" ]] && echo true || echo false)" "升级到 Python 3.11+。"

    local pip_version_text
    pip_version_text="$("$LOCAL_PYTHON_CMD" -m pip --version 2>/dev/null || true)"
    if [[ -n "$pip_version_text" ]]; then
      append_row "pip" "pip" "可用" "通过" "$pip_version_text" "true" "pip 已可用。"
    else
      append_row "pip" "pip" "可用" "缺少" "不可用" "false" "执行 python -m ensurepip --upgrade。"
    fi
  fi

  local go_path go_version_text go_version go_result
  go_path="$(resolve_command_path go || true)"
  if [[ -n "$go_path" ]]; then
    go_version_text="$(go version 2>/dev/null || true)"
    go_version="$(printf '%s' "$go_version_text" | sed -nE 's/.*go([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n 1)"
    if version_at_least "$go_version" "$REQUIRED_GO_VERSION"; then
      go_result="通过"
    elif [[ -n "$go_version" ]]; then
      go_result="版本偏低"
    else
      go_result="无法识别版本"
    fi
    append_row "go" "Go" ">= 1.22" "$go_result" "$go_version_text" "$([[ "$go_result" == "通过" ]] && echo true || echo false)" "升级到 Go 1.22+。"
  else
    append_row "go" "Go" ">= 1.22" "缺少" "未检测到" "false" "安装 Go 1.22+。"
  fi

  local node_path node_version_text node_version node_result
  node_path="$(resolve_command_path node || true)"
  if [[ -n "$node_path" ]]; then
    node_version_text="$(node --version 2>/dev/null || true)"
    node_version="$(printf '%s' "$node_version_text" | sed -nE 's/^v([0-9]+\.[0-9]+\.[0-9]+).*$/\1/p' | head -n 1)"
    if version_at_least "$node_version" "$REQUIRED_NODE_VERSION"; then
      node_result="通过"
    elif [[ -n "$node_version" ]]; then
      node_result="版本偏低"
    else
      node_result="无法识别版本"
    fi
    append_row "nodejs" "Node.js" ">= 20" "$node_result" "$node_version_text" "$([[ "$node_result" == "通过" ]] && echo true || echo false)" "升级到 Node.js 20+。"
  else
    append_row "nodejs" "Node.js" ">= 20" "缺少" "未检测到" "false" "安装 Node.js 20+。"
  fi

  local npm_path npm_version_text
  npm_path="$(resolve_command_path npm || true)"
  if [[ -n "$npm_path" ]]; then
    npm_version_text="$(npm --version 2>/dev/null || true)"
    if [[ -n "$npm_version_text" ]]; then
      append_row "npm" "npm" "可用" "通过" "npm $npm_version_text" "true" "npm 已可用。"
    else
      append_row "npm" "npm" "可用" "缺少" "已检测到命令但无法执行" "false" "通常随 Node.js 一起安装。"
    fi
  else
    append_row "npm" "npm" "可用" "缺少" "未检测到" "false" "安装 Node.js 后会自动带上 npm。"
  fi
}

has_failed_rows() {
  local row id component requirement result current passed hint
  for row in "${CHECK_ROWS[@]}"; do
    IFS="$US" read -r id component requirement result current passed hint <<< "$row"
    if [[ "$passed" != "true" ]]; then
      return 0
    fi
  done
  return 1
}

has_macos_docker_desktop() {
  [[ -d "/Applications/Docker.app" || -d "$HOME/Applications/Docker.app" ]]
}

has_macos_rancher_desktop() {
  [[ -d "/Applications/Rancher Desktop.app" || -d "$HOME/Applications/Rancher Desktop.app" ]]
}

# Docker 模式单独区分 CLI、compose 插件、daemon 三层状态，避免把问题混成一类。
test_docker_prerequisites() {
  CHECK_ROWS=()

  if command_exists docker; then
    local docker_version_text compose_version_text daemon_current
    docker_version_text="$(docker --version 2>/dev/null || true)"
    append_row "docker" "Docker CLI" "可用" "通过" "${docker_version_text:-已检测到 docker}" "true" "Docker CLI 已可用。"

    if docker compose version >/dev/null 2>&1; then
      compose_version_text="$(docker compose version 2>/dev/null || true)"
      append_row "docker_compose" "Docker Compose" "docker compose 可用" "通过" "$compose_version_text" "true" "Docker Compose 已可用。"
    else
      append_row "docker_compose" "Docker Compose" "docker compose 可用" "缺少" "不可用" "false" "安装 Docker Compose 插件。"
    fi

    if docker info >/dev/null 2>&1; then
      append_row "docker_daemon" "Docker daemon" "docker info 可连接" "通过" "可连接" "true" "Docker daemon 已就绪。"
    else
      if [[ "$PLATFORM" == "macos" && "$(has_macos_rancher_desktop && echo yes || echo no)" == "yes" ]]; then
        daemon_current="已安装 Rancher Desktop，但 daemon 未就绪"
      elif [[ "$PLATFORM" == "macos" && "$(has_macos_docker_desktop && echo yes || echo no)" == "yes" ]]; then
        daemon_current="已安装 Docker Desktop，但 daemon 未就绪"
      elif [[ "$PLATFORM" == "linux" ]]; then
        daemon_current="docker 命令存在，但 daemon 未就绪"
      else
        daemon_current="docker 命令存在，但 daemon 未就绪"
      fi
      append_row "docker_daemon" "Docker daemon" "docker info 可连接" "未就绪" "$daemon_current" "false" "先启动 Docker daemon。"
    fi
  else
    append_row "docker" "Docker CLI" "可用" "缺少" "未检测到" "false" "安装 Docker。"
    append_row "docker_compose" "Docker Compose" "docker compose 可用" "缺少" "未检测到 Docker CLI，无法检查" "false" "安装 Docker Compose。"
    append_row "docker_daemon" "Docker daemon" "docker info 可连接" "缺少" "未检测到 Docker CLI，无法检查" "false" "安装并启动 Docker daemon。"
  fi
}

write_install_guide_python() {
  printf '\n'
  print_success "Python 安装方式："
  if [[ "$PLATFORM" == "macos" ]]; then
    printf '%b%s%b\n' "$COLOR_CYAN" "  brew install python@3.11" "$COLOR_RESET"
    print_info "  也可以使用 python.org 官方安装包。"
  else
    printf '%b%s%b\n' "$COLOR_CYAN" "  Ubuntu/Debian 示例：sudo apt-get install -y python3 python3-pip" "$COLOR_RESET"
    print_info "  不同发行版请换成 dnf / yum / zypper 等对应包管理器。"
  fi
}

write_install_guide_go() {
  printf '\n'
  print_success "Go 安装方式："
  if [[ "$PLATFORM" == "macos" ]]; then
    printf '%b%s%b\n' "$COLOR_CYAN" "  brew install go" "$COLOR_RESET"
  else
    printf '%b%s%b\n' "$COLOR_CYAN" "  建议优先使用 Go 官方安装包，或通过发行版包管理器安装。" "$COLOR_RESET"
  fi
}

write_install_guide_node() {
  printf '\n'
  print_success "Node.js 安装方式："
  if [[ "$PLATFORM" == "macos" ]]; then
    printf '%b%s%b\n' "$COLOR_CYAN" "  brew install node@20" "$COLOR_RESET"
    print_info "  如果你使用 nvm，也可以直接安装 Node.js 20 LTS。"
  else
    printf '%b%s%b\n' "$COLOR_CYAN" "  建议使用 nvm 安装 Node.js 20 LTS，或使用 NodeSource 官方源。" "$COLOR_RESET"
  fi
}

write_install_guide_docker() {
  printf '\n'
  print_success "Docker 安装方式："
  if [[ "$PLATFORM" == "macos" ]]; then
    printf '%b%s%b\n' "$COLOR_CYAN" "  brew install --cask docker" "$COLOR_RESET"
    printf '%b%s%b\n' "$COLOR_CYAN" "  或：brew install --cask rancher" "$COLOR_RESET"
  else
    printf '%b%s%b\n' "$COLOR_CYAN" "  建议按 Docker 官方文档安装 Docker Engine 与 Docker Compose Plugin。" "$COLOR_RESET"
  fi
}

write_install_guide_docker_daemon() {
  printf '\n'
  print_success "Docker daemon 处理方式："
  if [[ "$PLATFORM" == "macos" ]]; then
    print_info "  请打开 Docker Desktop 或 Rancher Desktop，并等待状态变为 Running。"
  else
    printf '%b%s%b\n' "$COLOR_CYAN" "  sudo systemctl start docker" "$COLOR_RESET"
    printf '%b%s%b\n' "$COLOR_CYAN" "  sudo systemctl enable docker" "$COLOR_RESET"
  fi
  printf '%b%s%b\n' "$COLOR_CYAN" "  docker info" "$COLOR_RESET"
}

write_install_guides_from_rows() {
  local printed="|"
  local row id component requirement result current passed hint

  for row in "${CHECK_ROWS[@]}"; do
    IFS="$US" read -r id component requirement result current passed hint <<< "$row"
    [[ "$passed" == "true" ]] && continue

    case "$id" in
      python|pip)
        [[ "$printed" == *"|python|"* ]] || { write_install_guide_python; printed="${printed}python|"; }
        ;;
      go)
        [[ "$printed" == *"|go|"* ]] || { write_install_guide_go; printed="${printed}go|"; }
        ;;
      nodejs|npm)
        [[ "$printed" == *"|node|"* ]] || { write_install_guide_node; printed="${printed}node|"; }
        ;;
      docker|docker_compose)
        [[ "$printed" == *"|docker|"* ]] || { write_install_guide_docker; printed="${printed}docker|"; }
        ;;
      docker_daemon)
        [[ "$printed" == *"|docker-daemon|"* ]] || { write_install_guide_docker_daemon; printed="${printed}docker-daemon|"; }
        ;;
    esac
  done
}

write_project_dependency_guide() {
  local python_command="$1"
  printf '\n'
  print_warn "环境工具就绪后，按下面步骤安装项目依赖："
  print_success "Node.js（orchestrator-ts）："
  printf '%b%s%b\n' "$COLOR_CYAN" "  cd services/orchestrator-ts && npm install && cd ../.." "$COLOR_RESET"
  print_success "Node.js（admin-web）："
  printf '%b%s%b\n' "$COLOR_CYAN" "  cd services/admin-web && npm install && cd ../.." "$COLOR_RESET"
  print_success "Python："
  printf '%b%s%b\n' "$COLOR_CYAN" "  $python_command -m pip install -r services/model-asr-python/requirements.txt" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "  $python_command -m pip install -r services/model-tts-python/requirements.txt" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "  $python_command -m pip install -r services/model-avatar-python/requirements.txt" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "  $python_command -m pip install -r services/model-llm-python/requirements.txt" "$COLOR_RESET"
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

check_tcp_port_available() {
  local port="$1"

  if command_exists lsof; then
    ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  if command_exists ss; then
    ! ss -ltn "( sport = :$port )" 2>/dev/null | awk 'NR>1 { found=1 } END { exit found ? 0 : 1 }'
    return
  fi

  if command_exists netstat; then
    if [[ "$PLATFORM" == "macos" ]]; then
      ! netstat -anv -p tcp 2>/dev/null | grep -E "[\.\:]${port}[[:space:]].*LISTEN" >/dev/null 2>&1
    else
      ! netstat -ltn 2>/dev/null | awk '{print $4}' | grep -E "(^|:)$port$" >/dev/null 2>&1
    fi
    return
  fi

  return 0
}

check_udp_port_available() {
  local port="$1"

  if command_exists lsof; then
    ! lsof -nP -iUDP:"$port" >/dev/null 2>&1
    return
  fi

  if command_exists ss; then
    ! ss -lun 2>/dev/null | awk '{print $5}' | grep -E "(^|:)$port$" >/dev/null 2>&1
    return
  fi

  if command_exists netstat; then
    if [[ "$PLATFORM" == "macos" ]]; then
      ! netstat -anv -p udp 2>/dev/null | grep -E "[\.\:]${port}[[:space:]]" >/dev/null 2>&1
    else
      ! netstat -lun 2>/dev/null | awk '{print $4}' | grep -E "(^|:)$port$" >/dev/null 2>&1
    fi
    return
  fi

  return 0
}

# 这里只检查宿主机暴露端口，容器内部监听端口仍保持服务原生端口。
get_docker_host_port_checks() {
  cat <<'EOF'
orchestratorORCHESTRATOR_PORT58080tcp
asrASR_PORT58101tcp
ttsTTS_PORT58102tcp
avatarAVATAR_PORT58103tcp
llmLLM_PORT58104tcp
adminADMIN_PORT54173tcp
livekit-httpLIVEKIT_PORT57880tcp
livekit-tcpLIVEKIT_TCP_PORT57881tcp
livekit-udpLIVEKIT_UDP_PORT57882udp
srs-rtmpSRS_RTMP_PORT51935tcp
srs-apiSRS_API_PORT51985tcp
srs-httpSRS_HTTP_PORT58081tcp
EOF
}

get_blocked_docker_host_ports() {
  local line service env_name default_value protocol raw_value
  while IFS="$US" read -r service env_name default_value protocol; do
    raw_value="$(get_effective_env_value "$env_name" "$default_value")"
    if ! is_integer "$raw_value"; then
      printf '%s%s%s%s%s%s%s%s%s\n' "$service" "$US" "$env_name" "$US" "$raw_value" "$US" "$protocol" "$US" "端口值不是有效整数"
      continue
    fi

    if [[ "$protocol" == "udp" ]]; then
      if ! check_udp_port_available "$raw_value"; then
        printf '%s%s%s%s%s%s%s%s%s\n' "$service" "$US" "$env_name" "$US" "$raw_value" "$US" "$protocol" "$US" "宿主机端口不可用"
      fi
    else
      if ! check_tcp_port_available "$raw_value"; then
        printf '%s%s%s%s%s%s%s%s%s\n' "$service" "$US" "$env_name" "$US" "$raw_value" "$US" "$protocol" "$US" "宿主机端口不可用"
      fi
    fi
  done < <(get_docker_host_port_checks)
}

# 先做宿主机端口预检，避免镜像都构建完成后才在端口绑定阶段失败。
assert_docker_host_ports_available() {
  local blocked
  blocked="$(get_blocked_docker_host_ports)"
  [[ -z "$blocked" ]] && return 0

  write_section_header "宿主机端口检查未通过"
  printf '%-16s %-20s %-10s %-10s %s\n' "组件" "环境变量" "协议" "端口" "原因"
  printf '%-16s %-20s %-10s %-10s %s\n' "----" "----" "----" "----" "----"

  local line service env_name port protocol reason
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS="$US" read -r service env_name port protocol reason <<< "$line"
    printf '%-16s %-20s %-10s %-10s %s\n' "$service" "$env_name" "$protocol" "$port" "$reason"
  done <<< "$blocked"

  printf '\n'
  print_warn "请先在当前 Shell 会话或 .env 中改掉冲突端口，再重新启动。"
  print_info "本仓库默认已经优先使用 5xxxx 端口；如果仍有冲突，再继续手动覆盖。"
  print_warn "如果你还想临时覆盖默认端口，可先执行："
  printf '%b%s%b\n' "$COLOR_CYAN" '  export SRS_RTMP_PORT="61935"' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" '  export SRS_API_PORT="61985"' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" '  export SRS_HTTP_PORT="68081"' "$COLOR_RESET"
  printf '\n'
  print_warn "然后重新运行："
  printf '%b%s%b\n' "$COLOR_CYAN" "  ./start-$PLATFORM.sh --mode docker" "$COLOR_RESET"
  return 1
}

resolve_linux_docker_host() {
  local host

  if command_exists docker; then
    host="$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)"
    if [[ -n "$host" && "$host" != "<no value>" ]]; then
      printf '%s' "$host"
      return 0
    fi
  fi

  if command_exists ip; then
    host="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
    if [[ -n "$host" ]]; then
      printf '%s' "$host"
      return 0
    fi
  fi

  return 1
}

# Docker build 跑在容器侧，localhost / 127.0.0.1 在里面只会指向容器自己。
convert_proxy_url_for_docker_build() {
  local proxy_url="$1"
  [[ -n "$proxy_url" ]] || { printf '%s' "$proxy_url"; return 0; }

  if [[ "$proxy_url" =~ ^(https?://)([^/@]+@)?(127\.0\.0\.1|localhost)(:.*)?$ ]]; then
    local scheme="${BASH_REMATCH[1]}"
    local auth_part="${BASH_REMATCH[2]}"
    local tail_part="${BASH_REMATCH[4]}"
    local docker_host=""

    if [[ "$PLATFORM" == "macos" ]]; then
      docker_host="host.docker.internal"
    else
      docker_host="$(resolve_linux_docker_host || true)"
    fi

    if [[ -n "$docker_host" ]]; then
      printf '%s%s%s%s' "$scheme" "$auth_part" "$docker_host" "$tail_part"
      return 0
    fi
  fi

  printf '%s' "$proxy_url"
}

test_docker_base_image_proxy_failure() {
  local content="$1"
  grep -Eq 'failed to resolve source metadata|Docker Desktop has no HTTPS proxy|load metadata for docker\.io|registry-1\.docker\.io' <<< "$content"
}

test_docker_proxy_connection_failure() {
  local content="$1"
  grep -Eq "ProxyError\('Cannot connect to proxy|Failed to establish a new connection: \[Errno 111\] Connection refused|proxyconnect tcp|Connection refused" <<< "$content"
}

write_macos_docker_daemon_proxy_guide() {
  local proxy_example
  proxy_example="$(get_proxy_example_value)"
  printf '\n'
  print_success "Docker Desktop 代理配置方式："
  print_info "  1. 打开 Docker Desktop"
  print_info "  2. 进入 Settings"
  print_info "  3. 找到 Proxies（部分版本在 Resources 下）"
  print_info "  4. 在 HTTP Proxy / HTTPS Proxy 中填入你的代理地址，例如 $proxy_example"
  print_info "  5. 点击 Apply & Restart"
  printf '\n'
  print_warn "配完后先验证："
  printf '%b%s%b\n' "$COLOR_CYAN" "  docker info" "$COLOR_RESET"
}

write_linux_docker_daemon_proxy_guide() {
  local proxy_example
  proxy_example="$(get_proxy_example_value)"
  printf '\n'
  print_success "Linux 下 Docker daemon 代理配置方式："
  print_info "  如果你使用 Docker Desktop for Linux，可直接在图形界面的代理设置里填写。"
  print_info "  如果你使用 Docker Engine，可按 systemd 方式配置 daemon 代理。"
  printf '%b%s%b\n' "$COLOR_CYAN" '  sudo mkdir -p /etc/systemd/system/docker.service.d' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" '  sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null <<EOF' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "[Service]" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "Environment=\"HTTP_PROXY=$proxy_example\"" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "Environment=\"HTTPS_PROXY=$proxy_example\"" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" 'EOF' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" '  sudo systemctl daemon-reload && sudo systemctl restart docker' "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" '  docker info' "$COLOR_RESET"
}

# 把构建失败尽量归类成“基础镜像拉取失败”或“容器内代理不可达”，减少排障绕路。
write_docker_build_failure_hint() {
  local output_content="$1"
  local original_proxy_url="$2"
  local docker_proxy_url="$3"

  if test_docker_base_image_proxy_failure "$output_content"; then
    printf '\n'
    print_warn "检测到构建失败发生在基础镜像拉取阶段。"
    print_warn "这一步发生在 Docker daemon 侧，单纯传入 --proxy 或 Shell 环境变量还不够。"
    if [[ "$PLATFORM" == "macos" ]]; then
      write_macos_docker_daemon_proxy_guide
    else
      write_linux_docker_daemon_proxy_guide
    fi
    return 0
  fi

  if test_docker_proxy_connection_failure "$output_content"; then
    printf '\n'
    print_warn "检测到构建失败发生在容器内依赖下载阶段，而且当前代理地址无法从容器里连通。"

    if [[ "$original_proxy_url" =~ localhost|127\.0\.0\.1 ]]; then
      print_warn "你传入的是本机回环地址（127.0.0.1 / localhost）。"
      if [[ "$PLATFORM" == "macos" ]]; then
        print_warn "脚本会自动改写成 host.docker.internal；如果代理本身没监听或拒绝连接，仍会失败。"
      else
        print_warn "Linux 下脚本会尽量改写成 Docker bridge gateway；如果仍失败，建议直接改用宿主机局域网 IP。"
      fi
    fi

    if [[ -n "$docker_proxy_url" ]]; then
      printf '\n'
      print_warn "当前用于 Docker build 的代理地址："
      printf '%b%s%b\n' "$COLOR_CYAN" "  $docker_proxy_url" "$COLOR_RESET"
    fi

    printf '\n'
    print_warn "建议先确认你的代理软件确实允许 Docker 访问："
    print_info "  1. 代理软件已启动"
    print_info "  2. 监听端口与当前代理地址中的端口一致"
    print_info "  3. 已允许来自 Docker / 局域网的连接"
    printf '\n'
    print_warn "更稳妥的重试方式："
    if [[ -n "$docker_proxy_url" ]]; then
      printf '%b%s%b\n' "$COLOR_CYAN" "  ./start-$PLATFORM.sh --mode docker --proxy \"$docker_proxy_url\"" "$COLOR_RESET"
    else
      printf '%b%s%b\n' "$COLOR_CYAN" '  ./start-'"$PLATFORM"'.sh --mode docker --proxy "http://<宿主机地址>:<端口>"' "$COLOR_RESET"
    fi
  fi
}

# 统一先 build 再 up，把镜像拉取、依赖下载和容器启动问题拆到不同阶段暴露。
invoke_docker_compose_up() {
  local proxy_url="$1"
  local docker_proxy_url build_log build_exit output_content
  docker_proxy_url="$(convert_proxy_url_for_docker_build "$proxy_url")"
  build_log="$(mktemp)"

  local build_args=()
  if [[ -n "$proxy_url" ]]; then
    set_proxy_for_session "$docker_proxy_url"
    printf '\n'
    print_info "检测到代理配置，先执行 docker compose build ..."
    if [[ "$docker_proxy_url" != "$proxy_url" ]]; then
      print_info "已将本机代理地址转换为 Docker 可访问地址：$docker_proxy_url"
    fi
    build_args+=(--build-arg "HTTP_PROXY=$docker_proxy_url" --build-arg "HTTPS_PROXY=$docker_proxy_url")
  else
    printf '\n'
    print_info "先执行 docker compose build 检查镜像构建..."
  fi

  set +e
  docker compose build "${build_args[@]}" 2>&1 | tee "$build_log"
  build_exit=${PIPESTATUS[0]}
  set -e

  if [[ "$build_exit" -ne 0 ]]; then
    output_content="$(cat "$build_log")"
    write_docker_build_failure_hint "$output_content" "$proxy_url" "$docker_proxy_url"
    rm -f "$build_log"
    return "$build_exit"
  fi

  rm -f "$build_log"
  docker compose up
}

# Docker 模式主入口：先做宿主机端口预检，再决定使用哪份代理配置。
start_docker_mode() {
  local active_proxy=""
  assert_docker_host_ports_available || return 1

  if [[ -n "$PROXY" ]]; then
    active_proxy="$PROXY"
    printf '\n'
    print_info "使用命令行传入的代理：$active_proxy"
  else
    active_proxy="$(get_current_proxy_url || true)"
    if [[ -n "$active_proxy" ]]; then
      printf '\n'
      print_info "检测到当前会话已配置代理：$active_proxy"
    else
      printf '\n'
      print_info "当前未检测到代理配置。"
      print_info "如果你需要代理，请先 Ctrl+C 终止脚本，设置代理后重新运行；如果不需要，可直接继续。"
    fi
  fi

  invoke_docker_compose_up "$active_proxy"
}

run_local_mode() {
  write_section_header "本地开发模式检查结果"
  test_local_prerequisites
  write_check_table

  if ! has_failed_rows; then
    printf '\n'
    print_success "本地工具链已就绪。"
    write_proxy_reminder "local"
    write_project_dependency_guide "$LOCAL_PYTHON_DISPLAY"
    printf '\n'
    print_warn "当前仓库的本地模式仍以手动启动各服务为主，脚本先负责一次性把环境和依赖指引给全。"
    return 0
  fi

  write_proxy_reminder "local"
  write_install_guides_from_rows
  write_project_dependency_guide "$LOCAL_PYTHON_DISPLAY"
  write_rerun_hint "./start-$PLATFORM.sh --mode local"
  return 1
}

run_docker_mode() {
  write_section_header "Docker 模式检查结果"
  test_docker_prerequisites
  write_check_table

  if has_failed_rows; then
    write_proxy_reminder "docker"
    write_install_guides_from_rows
    write_rerun_hint "./start-$PLATFORM.sh --mode docker"
    return 1
  fi

  write_proxy_reminder "docker"
  printf '\n'
  print_success "Docker 环境已就绪，开始启动 compose 服务..."
  start_docker_mode
}

main() {
  init_colors
  parse_args "$@"

  cd "$PROJECT_ROOT"
  ensure_dotenv_exists

  printf '\n'
  printf '%b%s%b\n' "$COLOR_CYAN" "  ====================================" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "      AvaStack 启动与环境检查脚本" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_CYAN" "  ====================================" "$COLOR_RESET"

  if [[ "$MODE" == "local" ]]; then
    run_local_mode
  else
    run_docker_mode
  fi
}

main "$@"
