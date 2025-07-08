@echo off
setlocal enabledelayedexpansion

:: Purpose: Installs Salad application with required settings, GPU drivers, and dependencies
:: Logs all actions to InstallSalad.log (UTF-8 encoded).
:: Usage: Run as Administrator, optional -y flag for non-interactive mode

:: Set console code page to UTF-8
chcp 65001 >nul

:: Define log file and temp directory
set "tempDir=SaladInstallFiles"
set "logFile=InstallSalad.log"

:: Initialize log file with UTF-8 BOM (fixes non-unicode characters used in WSL installation)
echo. > "%logFile%"
powershell -Command "[System.IO.File]::WriteAllText('%logFile%', [char]0xFEFF + [System.IO.File]::ReadAllText('%logFile%'), [System.Text.Encoding]::UTF8)" >nul 2>&1

:: Initial debug output and directory check
echo Starting script execution... >> "%logFile%" 2>&1
echo Starting script execution...
if not exist "%tempDir%" (
    mkdir "%tempDir%" 2>nul
    if errorlevel 1 (
        echo Failed to create temp folder: %tempDir%. Check permissions. >> "%logFile%" 2>&1
        echo Failed to create temp folder: %tempDir%. Check permissions.
        exit /b 1
    )
    echo Created temp folder: %tempDir% >> "%logFile%" 2>&1
    echo Created temp folder: %tempDir%
)

:: Check for elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Script requires elevation. Relaunching as Administrator... >> "%logFile%" 2>&1
    echo Script requires elevation. Relaunching as Administrator...
    powershell -Command "Start-Process cmd -Verb RunAs -ArgumentList '/c cd /d %CD% && %0 %*'" >> "%logFile%" 2>&1
    exit /b
)
echo Running with elevation. >> "%logFile%" 2>&1
echo Running with elevation.

:: Check Virtualization
for /f "tokens=2 delims==" %%i in ('bcdedit /enum ^| find "hypervisorlaunchtype"') do set "vmStatus=%%i"
if "!vmStatus!"=="Off" (
    echo Virtualization is not enabled. Enabling it may require a reboot.
    if not "%1"=="-y" pause
    bcdedit /set hypervisorlaunchtype Auto >nul 2>&1
    if !errorlevel! equ 0 (
        echo Virtualization enabled. A reboot is required to apply changes.
    ) else (
        echo Failed to enable virtualization automatically. Please enable it in BIOS/UEFI.
    )
    if not "%1"=="-y" pause
) else (
    echo Virtualization is enabled.
)

:: Detect GPU hardware
set "nvidiaPresent=false"
set "gpuNames="
for /f "tokens=*" %%g in ('powershell -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name | ConvertTo-Json -Compress"') do (
    set "gpuNames=!gpuNames!, %%g"
    echo %%g | findstr /i "NVIDIA" >nul && set "nvidiaPresent=true"
)
:: Clean up JSON formatting from PowerShell
set "gpuNames=!gpuNames:\"=!"
set "gpuNames=!gpuNames:[=!"
set "gpuNames=!gpuNames:]=!"

:: Log GPU detection status
if "!gpuNames!"=="" (
    echo Warning: No GPU detected. >> "%logFile%" 2>&1
    echo Warning: No GPU detected.
) else (
    set "gpuNameSafe=!gpuNames:, =!"
    set "gpuNameSafe=!gpuNameSafe:(=^(!"
    set "gpuNameSafe=!gpuNameSafe:)=^)!"
    echo GPU detected: !gpuNameSafe! >> "%logFile%" 2>&1
    echo GPU detected: !gpuNameSafe!
)

:: Install WSL without default distribution
echo Installing WSL... >> "%logFile%" 2>&1
echo Installing WSL...
powershell -Command "& { wsl --install --no-distribution } | Out-File -FilePath '%logFile%' -Encoding UTF8 -Append" 2>&1
echo WSL installed. >> "%logFile%" 2>&1
echo WSL installed.

:: Install Visual C++ Redistributable 2022
echo Downloading Visual C++ Redistributable 2022... >> "%logFile%" 2>&1
echo Downloading Visual C++ Redistributable 2022...
set "vcRedistPath=%tempDir%\VC_redist.x64.exe"
curl -L -o "!vcRedistPath!" "https://aka.ms/vs/17/release/vc_redist.x64.exe" >> "%logFile%" 2>&1
if exist "!vcRedistPath!" (
    echo Launching Visual C++ Redistributable installer... >> "%logFile%" 2>&1
    echo Launching Visual C++ Redistributable installer...
    start /wait "" "!vcRedistPath!" /quiet /norestart >> "%logFile%" 2>&1
    set "installErrorLevel=!errorlevel!"
    echo Debug: Visual C++ Redistributable installation exit code !installErrorLevel! >> "%logFile%" 2>&1
    echo Debug: Visual C++ Redistributable installation exit code !installErrorLevel!
    if !installErrorLevel! equ 0 (
        echo Visual C++ Redistributable installed successfully. >> "%logFile%" 2>&1
        echo Visual C++ Redistributable installed successfully.
    ) else (
        echo Visual C++ Redistributable installation failed with error code !installErrorLevel!. >> "%logFile%" 2>&1
        echo Visual C++ Redistributable installation failed with error code !installErrorLevel!.
        if not "%1"=="-y" pause
    )
) else (
    echo Error: Visual C++ Redistributable download failed. >> "%logFile%" 2>&1
    echo Error: Visual C++ Redistributable download failed.
    if not "%1"=="-y" pause
)

:: Install .NET Framework 4.8
echo Downloading .NET Framework 4.8... >> "%logFile%" 2>&1
echo Downloading .NET Framework 4.8...
set "dotNetPath=%tempDir%\ndp48-x86-x64-allos-enu.exe"
curl -L -o "!dotNetPath!" "https://go.microsoft.com/fwlink/?linkid=2088631" >> "%logFile%" 2>&1
if exist "!dotNetPath!" (
    echo Launching .NET Framework installer... >> "%logFile%" 2>&1
    echo Launching .NET Framework installer...
    start /wait "" "!dotNetPath!" /q /norestart >> "%logFile%" 2>&1
    set "installErrorLevel=!errorlevel!"
    echo Debug: .NET Framework installation exit code !installErrorLevel! >> "%logFile%" 2>&1
    echo Debug: .NET Framework installation exit code !installErrorLevel!
    if !installErrorLevel! equ 0 (
        echo .NET Framework installed successfully. >> "%logFile%" 2>&1
        echo .NET Framework installed successfully.
    ) else (
        echo .NET Framework installation failed with error code !installErrorLevel!. >> "%logFile%" 2>&1
        echo .NET Framework installation failed with error code !installErrorLevel!.
        if not "%1"=="-y" pause
    )
) else (
    echo Error: .NET Framework download failed. >> "%logFile%" 2>&1
    echo Error: .NET Framework download failed.
    if not "%1"=="-y" pause
)

:: Download and parse latest.yml for Salad installer
echo Downloading latest Salad Definition... >> "%logFile%" 2>&1
echo Downloading latest Salad Definition...
set "yamlPath=%tempDir%\latest.yml"
curl -L -o "!yamlPath!" "https://releases.salad.com/release/latest.yml" >> "%logFile%" 2>&1
if not exist "!yamlPath!" (
    echo Error: Failed to download latest.yml. >> "%logFile%" 2>&1
    echo Error: Failed to download latest.yml.
    if not "%1"=="-y" pause
    exit /b 1
)

:: Parse YAML for Salad executable path
set "saladPath="
for /f "tokens=1,* delims=:" %%a in ('type "!yamlPath!" ^| findstr /r "path:.*Salad-.*\.exe"') do (
    set "saladPath=%%b"
    set "saladPath=!saladPath: =!"
)
if "!saladPath!"=="" (
    echo Error: Failed to parse latest.yml for Salad download path. >> "%logFile%" 2>&1
    echo Error: Failed to parse latest.yml for Salad download path.
    if not "%1"=="-y" pause
    exit /b 1
)

:: Download and install Salad
echo Downloading Salad... >> "%logFile%" 2>&1
echo Downloading Salad...
set "saladUrl=https://releases.salad.com/release/!saladPath!"
set "saladExe=%tempDir%\!saladPath!"
curl -L -o "!saladExe!" "!saladUrl!" >> "%logFile%" 2>&1
if exist "!saladExe!" (
    echo Installing Salad... >> "%logFile%" 2>&1
    echo Installing Salad...
    set "installDir=C:\Program Files\Salad"
    set "installMarker=C:\Program Files\Salad\Salad.exe"
    :: Run installer and wait
    powershell -Command "try { Start-Process -FilePath '!saladExe!' -ArgumentList '/S' -Wait -NoNewWindow; Write-Output 'Salad installer process completed'; exit 0 } catch { Write-Output 'Error running Salad installer: ' + $_.Exception.Message; exit 1 }" >> "%logFile%" 2>&1
    set "installErrorLevel=!errorlevel!"
    echo Debug: Salad installer exit code !installErrorLevel! >> "%logFile%" 2>&1
    echo Debug: Salad installer exit code !installErrorLevel!
    :: Check for marker file with PowerShell (secondary validation)
    powershell -Command "try { $installMarker = 'C:\Program Files\Salad\Salad.exe'; Write-Output 'Checking marker file: ' + $installMarker; for ($i = 0; $i -lt 600; $i++) { if (Test-Path -Path $installMarker) { Write-Output 'Salad installation detected at: ' + $installMarker; exit 0 }; Write-Output 'Waiting for marker file, attempt ' + ($i + 1); Start-Sleep -Milliseconds 1000 }; Write-Output 'Installation marker file not found after 600 seconds'; exit 1 } catch { Write-Output 'Error checking marker file: ' + $_.Exception.Message; exit 1 }" >> "%logFile%" 2>&1
    set "psErrorLevel=!errorlevel!"
    echo Debug: PowerShell marker check exit code !psErrorLevel! >> "%logFile%" 2>&1
    echo Debug: PowerShell marker check exit code !psErrorLevel!
    :: Fallback check in batch
    if exist "!installMarker!" (
        set "installErrorLevel=0"
    ) else (
        if !installErrorLevel! neq 0 (
            echo Salad installation failed with error code !installErrorLevel!. >> "%logFile%" 2>&1
            echo Salad installation failed with error code !installErrorLevel!.
            if not "%1"=="-y" pause
            exit /b 1
        )
        if !psErrorLevel! neq 0 (
            echo Salad installation failed: Marker file not found after PowerShell check. >> "%logFile%" 2>&1
            echo Salad installation failed: Marker file not found after PowerShell check.
            if not "%1"=="-y" pause
            exit /b 1
        )
    )
    echo Salad installed successfully. >> "%logFile%" 2>&1
    echo Salad installed successfully.
) else (
    echo Error: Salad executable not found after download. >> "%logFile%" 2>&1
    echo Error: Salad executable not found after download.
    if not "%1"=="-y" pause
    exit /b 1
)

:: Add Salad to startup programs
echo Configuring Salad to run at startup... >> "%logFile%" 2>&1
echo Configuring Salad to run at startup...
if not "%1"=="-y" (
    set /p addStartup="Add Salad to startup programs? (Y/N): "
    if /i "!addStartup!"=="Y" (
        powershell -Command "try { New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Salad' -Value '\"C:\Program Files\Salad\Salad.exe\"' -PropertyType String -Force | Out-Null; Write-Output 'Added Salad to startup programs'; exit 0 } catch { Write-Output 'Error adding Salad to startup: ' + $_.Exception.Message; exit 1 }" >> "%logFile%" 2>&1
        set "startupErrorLevel=!errorlevel!"
        echo Debug: Startup configuration exit code !startupErrorLevel! >> "%logFile%" 2>&1
        echo Debug: Startup configuration exit code !startupErrorLevel!
        if !startupErrorLevel! equ 0 (
            echo Salad added to startup programs successfully. >> "%logFile%" 2>&1
            echo Salad added to startup programs successfully.
        ) else (
            echo Failed to add Salad to startup programs with error code !startupErrorLevel!. >> "%logFile%" 2>&1
            echo Failed to add Salad to startup programs with error code !startupErrorLevel!.
            pause
        )
    ) else (
        echo Skipping adding Salad to startup programs. >> "%logFile%" 2>&1
        echo Skipping adding Salad to startup programs.
    )
) else (
    powershell -Command "try { New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Salad' -Value '\"C:\Program Files\Salad\Salad.exe\"' -PropertyType String -Force | Out-Null; Write-Output 'Added Salad to startup programs'; exit 0 } catch { Write-Output 'Error adding Salad to startup: ' + $_.Exception.Message; exit 1 }" >> "%logFile%" 2>&1
    set "startupErrorLevel=!errorlevel!"
    echo Debug: Startup configuration exit code !startupErrorLevel! >> "%logFile%" 2>&1
    echo Debug: Startup configuration exit code !startupErrorLevel!
    if !startupErrorLevel! equ 0 (
        echo Salad added to startup programs successfully. >> "%logFile%" 2>&1
        echo Salad added to startup programs successfully.
    ) else (
        echo Failed to add Salad to startup programs with error code !startupErrorLevel!. >> "%logFile%" 2>&1
        echo Failed to add Salad to startup programs with error code !startupErrorLevel!.
        exit /b 1
    )
)

:: Install NVIDIA driver if present
if "!nvidiaPresent!"=="true" (
    echo Downloading NVIDIA driver for: !gpuNameSafe! >> "%logFile%" 2>&1
    echo Downloading NVIDIA driver for: !gpuNameSafe!
    set "driverPath=%tempDir%\nvidia_driver.exe"
    curl -L -o "!driverPath!" "https://us.download.nvidia.com/Windows/576.80/576.80-desktop-win10-win11-64bit-international-nsd-dch-whql.exe" >> "%logFile%" 2>&1
    if exist "!driverPath!" (
        echo Launching NVIDIA driver installer... >> "%logFile%" 2>&1
        echo Launching NVIDIA driver installer...
        echo start /wait "" "!driverPath!" /s /noreboot /noeula /clean > "%tempDir%\install_driver.cmd"
        echo exit /b !errorlevel! >> "%tempDir%\install_driver.cmd"
        cmd /c "%tempDir%\install_driver.cmd" >> "%logFile%" 2>&1
        set "installErrorLevel=!errorlevel!"
        del "%tempDir%\install_driver.cmd"
        echo Debug: Driver installation exit code !installErrorLevel! >> "%logFile%" 2>&1
        echo Debug: Driver installation exit code !installErrorLevel!
        if !installErrorLevel! equ 0 (
            echo NVIDIA driver installed successfully. >> "%logFile%" 2>&1
            echo NVIDIA driver installed successfully.
        ) else (
            echo NVIDIA driver installation failed with error code !installErrorLevel!. >> "%logFile%" 2>&1
            echo NVIDIA driver installation failed with error code !installErrorLevel!.
            if not "%1"=="-y" pause
        )
    ) else (
        echo Error: NVIDIA driver download failed. >> "%logFile%" 2>&1
        echo Error: NVIDIA driver download failed.
        if not "%1"=="-y" pause
    )
) else (
    echo No NVIDIA GPU detected, skipping driver installation. >> "%logFile%" 2>&1
    echo No NVIDIA GPU detected, skipping driver installation.
)

:: Cleanup and reboot
if not "%1"=="-y" (
    set /p cleanup="Delete temp folder (%tempDir%)? (Y/N): "
    if /i "!cleanup!"=="Y" rmdir /s /q "%tempDir%" >> "%logFile%" 2>&1
    set /p reboot="Reboot now? (Y/N): "
    if /i "!reboot!"=="Y" shutdown /r /t 0
) else (
    rmdir /s /q "%tempDir%" >> "%logFile%" 2>&1
    shutdown /r /t 0
)

endlocal
