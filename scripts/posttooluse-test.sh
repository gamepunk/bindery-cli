#!/usr/bin/env bash
# bindery-cli：在“编辑/写入”类工具调用后自动跑一次 minitest，其余工具调用跳过。
# 非阻塞：测试失败会以非零退出码返回，VS Code 显示为非阻塞警告，不打断流程。
set -uo pipefail

input="$(cat)"

tool_name="$(printf '%s' "$input" | ruby -rjson -e \
  'begin; print(JSON.parse(STDIN.read).dig("tool_name").to_s); rescue StandardError; end' 2>/dev/null)"

case "$tool_name" in
  create_file|replace_string_in_file|insert_edit_into_file|edit_notebook_file|create_new_jupyter_notebook)
    rake test
    ;;
  *)
    exit 0
    ;;
esac
