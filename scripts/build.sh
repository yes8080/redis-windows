#!/bin/bash
set -eo pipefail

# 参数处理
while getopts "v:" opt; do
  case $opt in
    v) REDIS_VERSION="$OPTARG" ;;
    *) echo "Usage: $0 -v <redis_version>"; exit 1 ;;
  esac
done

# 版本验证
validate_version() {
  [[ "$REDIS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Invalid version format. Example: 7.2.4"
    exit 1
  }
}

# 主构建流程
main() {
  validate_version
  
  WORKDIR="/c/redis-build"
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  echo "▌ Building Redis $REDIS_VERSION..."
  
  # 克隆源码
  git clone --depth 1 --branch "$REDIS_VERSION" https://github.com/redis/redis.git
  cd redis

  # 应用补丁
  apply_patches() {
    echo "▌ Applying patches..."
    for patch in ../../patches/common/*.patch; do
      git apply --verbose "$patch" || echo "Skipping incompatible patch: $patch"
    done

    local major_minor=${REDIS_VERSION%.*}
    if [ -d "../../patches/v$major_minor" ]; then
      for patch in "../../patches/v$major_minor"/*.patch; do
        git apply "$patch"
      done
    fi
  }
  apply_patches

  # 修复Windows路径
  find src -type f -exec sed -i 's#/#\\#g' {} +

  # 编译配置
  sed -i.orig '
    s/-Werror //g;
    s/MALLOC=.*/MALLOC=jemalloc/;
    s/^LDFLAGS=/LDFLAGS=-pthread /;
    s/-O2/-O2 -D_WIN32_WINNT=0x0600/;
  ' src/Makefile

  echo "LIBS += -ljemalloc -lws2_32" >> src/Makefile

  # 开始编译
  echo "▌ Compiling..."
  make -j$(nproc) CC="gcc" CFLAGS="-I/mingw64/include" LDFLAGS="-L/mingw64/lib"

  # 验证输出
  required_bins=("redis-server.exe" "redis-cli.exe")
  for bin in "${required_bins[@]}"; do
    [ -f "src/$bin" ] || {
      echo "Build failed: Missing $bin"
      exit 1
    }
  done

  echo "✓ Build successful!"
}

main "$@"