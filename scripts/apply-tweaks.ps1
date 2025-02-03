# 需管理员权限运行
param([switch]$Force)

if (-not $Force) {
    $confirmation = Read-Host "此操作将修改系统设置，确认继续？(y/n)"
    if ($confirmation -ne 'y') { Exit }
}

# 优化网络设置
Set-NetTCPSetting -SettingName InternetCustom `
    -MaxSynRetransmissions 64 `
    -InitialRto 1000 `
    -MinRto 300 `
    -DynamicPortRangeStartPort 10000 `
    -DynamicPortRangeNumberOfPorts 60000

# 调整句柄限制
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v USERProcessHandleQuota /t REG_DWORD /d 0x000186a0 /f

Write-Host "✓ 系统优化完成！请重启生效。" -ForegroundColor Green