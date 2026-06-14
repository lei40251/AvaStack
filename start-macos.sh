#!/usr/bin/env bash

# macOS 启动入口。
# 这里单独保留一个入口脚本，目的是让使用方式更直观，
# 同时把具体实现收敛到公共 Unix 内核里，后续维护不用改三份逻辑。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/start-unix-common.sh" --platform macos "$@"
