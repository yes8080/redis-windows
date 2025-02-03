# Redis Windows 构建项目

[![Build Status](https://github.com/redis-windows/redis-windows/actions/workflows/build.yml/badge.svg)](https://github.com/redis-windows/redis-windows/actions)

为 Windows 系统提供最新版 Redis 的预编译版本，支持原生运行和高性能优化。

## 📦 下载预编译版

前往 [Release 页面](https://github.com/redis-windows/redis-windows/releases) 下载最新版本。

## 🛠 手动构建

### 系统要求
- Windows 10/11 或 Windows Server 2019+
- 8GB 内存
- 2GB 可用磁盘空间

### 构建步骤
```powershell
# 克隆仓库
git clone https://github.com/redis-windows/redis-windows
cd redis-windows

# 运行构建脚本
.\scripts\build.sh -v 7.2.4

# 输出文件位于 redis/src 目录