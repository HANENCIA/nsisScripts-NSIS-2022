@echo off
chcp 949 >nul
setlocal EnableExtensions

echo FFmpeg System PATH 설정을 시작합니다.
echo.

set "FFMPEG_BIN=%~dp0bin"

if "%FFMPEG_BIN:~-1%"=="\" set "FFMPEG_BIN=%FFMPEG_BIN:~0,-1%"

echo 계산된 경로:
echo %FFMPEG_BIN%
echo.

if not exist "%FFMPEG_BIN%\ffmpeg.exe" (
    echo 오류: ffmpeg.exe를 찾을 수 없습니다.
    echo 확인 경로: %FFMPEG_BIN%
    pause
    exit /b 1
)

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo 관리자 권한으로 다시 실행합니다.
    powershell.exe -NoProfile -ExecutionPolicy Bypass ^
        -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment';" ^
    "$target = '%FFMPEG_BIN%';" ^
    "$target = [IO.Path]::GetFullPath($target).TrimEnd('\');" ^
    "$key = Get-Item -Path $regPath;" ^
    "$oldPath = $key.GetValue('Path', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);" ^
    "if ($null -eq $oldPath) { throw 'System PATH 값을 읽을 수 없습니다.' };" ^
    "$items = @($oldPath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' });" ^
    "$exists = $false;" ^
    "foreach ($item in $items) { try { $normalized = [IO.Path]::GetFullPath($item).TrimEnd('\') } catch { $normalized = $item }; if ($normalized -ieq $target) { $exists = $true } };" ^
    "if (-not $exists) { $items += $target; };" ^
    "$newPath = $items -join ';';" ^
    "Set-ItemProperty -Path $regPath -Name Path -Value $newPath -Type ExpandString;" ^
    "Write-Host 'System PATH가 정상적으로 갱신되었습니다.';" ^
    "Write-Host ('추가 경로: ' + $target);"

if errorlevel 1 (
    echo.
    echo 오류: System PATH 갱신에 실패했습니다.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$signature = '[DllImport(\"user32.dll\", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);';" ^
    "Add-Type -MemberDefinition $signature -Name NativeMethods -Namespace Win32;" ^
    "[UIntPtr]$result = [UIntPtr]::Zero;" ^
    "[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null;"

echo.
echo 완료되었습니다.
echo 새 CMD 창에서 다음 명령으로 확인하세요.
echo ffmpeg -version
echo.

endlocal