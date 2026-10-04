@echo off
setlocal EnableExtensions

rem 현재 배치 파일 위치 기준의 ffmpeg\bin 경로
set "FFMPEG_BIN=%~dp0bin"

rem 마지막 백슬래시 제거
if "%FFMPEG_BIN:~-1%"=="\" set "FFMPEG_BIN=%FFMPEG_BIN:~0,-1%"

rem 관리자 권한 확인
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo 관리자 권한으로 다시 실행합니다...
    powershell.exe -NoProfile -ExecutionPolicy Bypass ^
        -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

echo 제거할 경로:
echo "%FFMPEG_BIN%"
echo.

rem PowerShell로 HKLM System PATH에서 정확히 일치하는 항목 제거
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment';" ^
    "$target = [IO.Path]::GetFullPath('%FFMPEG_BIN%').TrimEnd('\');" ^
    "$oldPath = [Environment]::GetEnvironmentVariable('Path', 'Machine');" ^
    "$items = $oldPath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' };" ^
    "$newItems = $items | Where-Object { ([IO.Path]::GetFullPath($_).TrimEnd('\')) -ine $target };" ^
    "$newPath = $newItems -join ';';" ^
    "if ($items.Count -eq $newItems.Count) { Write-Host '[INFO] 제거할 경로가 없습니다.'; exit 0 };" ^
    "Set-ItemProperty -Path $regPath -Name Path -Value $newPath -Type ExpandString;" ^
    "Write-Host '[OK] System PATH에서 제거했습니다.';"

if errorlevel 1 (
    echo.
    echo [ERROR] System PATH 수정에 실패했습니다.
    pause
    exit /b 1
)

rem 시스템에 환경 변수 변경 알림
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$signature = '[DllImport(\"user32.dll\", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);';" ^
    "Add-Type -MemberDefinition $signature -Name NativeMethods -Namespace Win32;" ^
    "[UIntPtr]$result = [UIntPtr]::Zero;" ^
    "[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null;"

echo.
echo 완료되었습니다.
echo 새 CMD 또는 PowerShell 창에서 다음 명령으로 확인하세요.
echo   where ffmpeg
echo   reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path
echo.

exit /b 0