#!/usr/bin/env bash

# Linux 启动入口。
# 与 macOS 入口保持同样的命令参数习惯，但底层会走 Linux 专属的提示与代理处理分支。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/start-unix-common.sh" --platform linux "$@"
