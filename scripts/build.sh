#!/bin/bash
set -eo pipefail

# 参数解析
while getopts "v:" opt; do
  case $opt in
    v) REDIS_VERSION="$OPTARG" ;;
    *) echo "Usage: $0 -v <redis_version>"; exit 1 ;;
  esac
done

# 版本校验
validate_version() {
  if [[ ! "$REDIS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误：版本号格式无效，示例：7.2.4"
    exit 1
  fi
}

# 主流程
main() {
  validate_version
  
  local WORKDIR="/c/build"
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  echo "▌ 正在构建 Redis $REDIS_VERSION ..."
  
  # 克隆源码
  git clone --depth 1 --branch "$REDIS_VERSION" https://github.com/redis/redis.git
  cd redis

  # 应用补丁
  apply_patches() {
    echo "▌ 应用系统补丁..."
    for patch in ../../patches/common/*.patch; do
      git apply --verbose "$patch" || true
    done

    local major_minor=${REDIS_VERSION%.*}
    for patch in ../../patches/v$major_minor/*.patch; do
      [ -f "$patch" ] && git apply "$patch"
    done
  }
  apply_patches

  # 编译依赖
  build_deps() {
    echo "▌ 编译依赖库..."
    pacman -S --noconfirm mingw-w64-x86_64-jemalloc
  }
  build_deps

  # 修改构建配置
  sed -i 's/-Werror //g' src/Makefile
  echo "LIBS += -ljemalloc" >> src/Makefile

  # 执行编译
  echo "▌ 开始编译..."
  make -j$(nproc) CC="gcc" MALLOC=jemalloc

  # 验证输出
  [ -f src/redis-server.exe ] || { echo "编译失败：缺少 redis-server.exe"; exit 1; }
  echo "✓ 构建成功！"
}

main "$@"