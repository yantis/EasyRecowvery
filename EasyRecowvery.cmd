@echo off
set SRC=%~dp0exploit
set TARGET=/data/local/tmp
set ADB=""
set GETBACKUPS=""

:menu

cls

echo.
echo =============================================================================================
echo ==             T-mobile LG V20 (H918) One-Click DirtyCow Installer and Toolkit             ==
echo ================================================================================= beta1 =====
echo.
echo Pre-flight checklist:
echo - Install ADB, perferably with the Android SDK provided by Google (https://goo.gl/7ijkjp)
echo - Unlock your bootloader with "fastboot oem unlock" (see: http://i.imgur.com/2BhNatP.png)
echo - Enable USB debugging on your device and set this computer to always be allowed to connect
echo - Upload your desired recovery to /sdcard/recovery.img
echo - Plug in only one device - this script does not support batch operations
echo - Try to resist the urge to touch your phone, especially when the screen goes all weird
echo.
echo.
echo.
echo Please select from the following options:
echo.
echo 1) Exploit and flash /sdcard/recovery.img (Leave selinux enforcing)
echo 2) Exploit and flash /sdcard/recovery.img (Set selinux permissive)
echo 3) Exploit and spawn a root shell (Be careful in there!)
echo 4) Flash only (For resuming after a successful exploit)
echo 5) Download boot and recovery backups from /sdcard/stock_*.img
echo 6) Restore stock boot and recovery from /sdcard/stock_*.img
rem TODO: finish integrity verification disabler
rem <nul set /p= 7) Toggle integrity verification during exploit (currently 
rem if "%NOHASH%"=="true" (echo disabled^)) else (echo enabled^))
echo 0) Quit this script
echo.
set /p command=^(0-6^) %=%

if "%command%"=="1" goto start
if "%command%"=="2" goto start
if "%command%"=="3" goto start
if "%command%"=="4" goto start
if "%command%"=="5" goto start
if "%command%"=="6" goto start
if "%command%"=="7" (
    if "%NOHASH%"=="true" (set NOHASH=false) else (set NOHASH=true)
    goto menu
)
if "%command%"=="0" goto end

goto menu

:start

echo.
echo - - - Making sure we're good to go - - -
echo.
echo >%~dp0recowvery-exploit.log

:findadb

<nul set /p= Locating adb.exe...                                             

adb version >nul && set ADB=adb || (
    if not exist %ADB% (
        echo No adb.exe in PATH >>%~dp0recowvery-exploit.log
        set ADB=%ANDROID_HOME%\platform-tools\adb.exe
    )
    if not exist %ADB% (
        echo Failed to find adb.exe in ANDROID_HOME >>%~dp0recowvery-exploit.log
        set ADB=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe
    )
    if not exist %ADB% (
        echo Failed to find adb.exe in AppData >>%~dp0recowvery-exploit.log
        set ADB=%ProgramFiles^(x86^)%\Android\android-sdk\platform-tools\adb.exe
    )
    if not exist %ADB% (
        echo Failed to find adb.exe in Program Files ^(x86^) >>%~dp0recowvery-exploit.log
        set ADB=%PROGRAMFILES%\Android\android-sdk\platform-tools\adb.exe
    )
    if not exist %ADB% (
        echo Failed to find adb.exe in Program Files >>%~dp0recowvery-exploit.log
        set ADB=C:\android-sdk\platform-tools\adb.exe
    )
    if not exist %ADB% (
        echo FAILED!
        echo
    )
)
echo SUCCESS!
echo adb.exe found at "%ADB%" >>%~dp0recowvery-exploit.log

:scan

<nul set /p= Looking for ADB device...                                       
%ADB% kill-server >nul || (echo FAILED! & echo Could not run adb.exe...)
%ADB% devices >nul

set ANDROID_SERIAL=""
for /f "tokens=1,3" %%i in ('%ADB% devices -l') do (
    if not "%%i"=="List" (
        set ANDROID_SERIAL=%%i
        for /f "tokens=2 delims=:" %%n in ("%%j") do echo %%n
        if not "%%j"=="product:elsa_tmo_us" (
            echo This device doesn't look like a T-mobile V20. Proceed anyway?
            set /p response=^(Y/N^) %=%
            if /i "%response%"=="y" goto check
            if /i "%response%"=="n" goto end
            goto scan
        )
    )
)

if %ANDROID_SERIAL%=="" (
    echo Failed to find your V20!
    echo.
    echo Did you remember to plug in the device?
    echo Is your V20 set to "always allow" this computer to connect to ADB?
    echo Are you using a recent version of ADB?
    echo.
    echo Press Ctrl-C to quit, or any other key to retry.
    pause
    goto scan
)

set ADB=%ADB% -s %ANDROID_SERIAL%

:check

set response=""

<nul set /p= Checking unlock status...                                       
for /f "tokens=1" %%i in ('%ADB% shell getprop ro.boot.flash.locked') do (
    if not "%%i"=="0" (
        echo FAILED!
        echo.
        echo Your device does not appear to be unlocked.
        echo Please boot into fastboot mode and run:
        echo fastboot oem unlock
        echo From your computer, then try again.
        echo http://i.imgur.com/2BhNatP.png
    )
)
echo SUCCESS!

echo Using device with serial %ANDROID_SERIAL%

if "%COMMAND%"=="5" goto getbackups
goto push

:push

echo.
echo - - - Pushing exploit to %TARGET%/recowvery - - -
echo.

<nul set /p= Copying files...                                                
echo Pushing exploit >>%~dp0recowvery-exploit.log
%ADB% shell rm -rf %TARGET%/recowvery >nul
%ADB% push %SRC% %TARGET%/recowvery >>%~dp0recowvery-exploit.log 2>&1
%ADB% shell test -e %TARGET%/recowvery/recowvery.sh || (
    echo FAILED!
    echo.
    echo Could not write to /data/local/tmp/.
    echo Please check the directory permsisions and delete
    echo any files or folders named "recowvery" if needed.
    goto end
)
echo SUCCESS!

:run

echo.
echo - - - Launching Recowvery on device - - -
echo.

if "%command%"=="1" goto exploit-normal
if "%command%"=="2" goto exploit-permissive
if "%command%"=="3" goto exploit-only
if "%command%"=="4" goto flash
if "%command%"=="6" goto restore

:exploit-normal
%ADB% shell sh %TARGET%/recowvery/recowvery.sh && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage1 && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage2
goto installedrec

:exploit-permissive
%ADB% shell sh %TARGET%/recowvery/recowvery.sh && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage1 --permissive && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage2
goto installedrec

:exploit-only
%ADB% shell sh %TARGET%/recowvery/recowvery.sh && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage1 --shell && %ADB% wait-for-device
goto getlogs

:flash
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --flash
goto getlogs

:restore
%ADB% shell sh %TARGET%/recowvery/recowvery.sh && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage1 --restore && %ADB% wait-for-device && ^
%ADB% shell sh %TARGET%/recowvery/recowvery.sh --stage2
goto getlogs

:installedrec
echo.
echo All done! Would you like to download your boot and recovery backup images noW?
set /p response=^(Y/N^) %==%
if /i "%response%"=="y" set GETBACKUPS=true

:getlogs
rem Pull whatever we managed to log

%ADB% pull %TARGET%/recowvery/audit.log %~dp0recowvery-audit.log >nul 2>&1
%ADB% pull %TARGET%/recowvery/shell.log %~dp0recowvery-shell.log >nul 2>&1
%ADB% logcat -d > %~dp0recowvery-logcat.log 2>nul
%ADB% shell cat %TARGET%/recowvery/recowvery.log 2>nul >>%~dp0recowvery-exploit.log

if "%GETBACKUPS%"=="true" goto getbackups

echo.
echo - - - SAVED LOGS TO %cd%\recowvery-*.log - - -
echo.
goto end

:getbackups
rem Grab any backups taken before the flash

echo.
<nul set /p= Downloading backups...                                          
%ADB% pull /sdcard/stock_recovery.img 2>nul >>%~dp0recowvery-exploit.log && ^
%ADB% pull /sdcard/stock_recovery.img.sha1 2>nul >>%~dp0recowvery-exploit.log && ^
%ADB% pull /sdcard/stock_boot.img 2>nul >>%~dp0recowvery-exploit.log && ^
%ADB% pull /sdcard/stock_boot.img.sha1 2>nul >>%~dp0recowvery-exploit.log && (
    echo SUCCESS!
    echo.
    echo - - - SAVED LOGS AND BACKUPS TO %cd%\ - - -
    echo.
    echo Delete backup images from /sdcard/?
    set response=""
    set /p response=^(Y/N^) %==%
    if /i "%response%"=="y" (
        %ADB% shell rm /sdcard/stock_recovery.img 2>nul
        %ADB% shell rm /sdcard/stock_recovery.img.sha1 2>nul
        %ADB% shell rm /sdcard/stock_boot.img 2>nul
        %ADB% shell rm /sdcard/stock_boot.img.sha1 2>nul
    )
    goto end
)
echo FAILED!
echo.
echo Could not get backup images from /sdcard/. Please copy them manually.

goto end

:sendimg
rem Push a custom recovery to flash at the end of the process
rem TODO: Dead execution path

%ADB% push %customimg% /sdcard/recovery.img

goto end

rem Hi mom

:end

echo.
pause
