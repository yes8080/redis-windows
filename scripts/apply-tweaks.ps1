# 需要管理员权限
param([switch]$Force)

if (-not $Force) {
    $confirmation = Read-Host "This will modify system settings. Continue? (y/n)"
    if ($confirmation -ne 'y') { Exit }
}

# 网络优化
Set-NetTCPSetting -SettingName InternetCustom `
    -MaxSynRetransmissions 64 `
    -DynamicPortRangeStartPort 10000 `
    -DynamicPortRangeNumberOfPorts 60000

# 句柄限制
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows" /v USERProcessHandleQuota /t REG_DWORD /d 100000 /f

Write-Host "✓ System optimization complete! Reboot required." -ForegroundColor Green