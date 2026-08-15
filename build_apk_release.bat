@echo off
cd /d %~dp0

:: Set JAVA_HOME (Android Studio bundled JBR)
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo === Building APK (release) ===
echo Working directory: %CD%
echo JAVA_HOME: %JAVA_HOME%
if not exist "lib\main.dart" (
    echo ERROR: lib\main.dart not found!
    pause
    exit /b 1
)

:: Stop any stale Gradle daemons first
echo Stopping Gradle daemons...
pushd android
call gradlew.bat --stop >nul 2>&1
popd
if exist "%USERPROFILE%\.gradle\daemon" rmdir /s /q "%USERPROFILE%\.gradle\daemon"

:: Attempt 1: Normal build
echo [1/3] Normal build...
call flutter build apk --release
if %ERRORLEVEL% EQU 0 goto success

echo.
echo [1/3] Failed (exit code %ERRORLEVEL%), running flutter clean...

:: Attempt 2: Light clean
echo [2/3] flutter clean + pub get + build...
call flutter clean
call flutter pub get
call flutter build apk --release
if %ERRORLEVEL% EQU 0 goto success

echo.
echo [2/3] Failed (exit code %ERRORLEVEL%), running deep clean...

:: Attempt 3: Deep clean
echo [3/3] Deep clean + build...
call flutter clean
if exist ".dart_tool" rmdir /s /q ".dart_tool"
if exist "android\.gradle" rmdir /s /q "android\.gradle"
call flutter pub get
call flutter build apk --release
if %ERRORLEVEL% EQU 0 goto success

echo.
echo === BUILD FAILED ===
echo All 3 attempts failed. Please check the error messages above.
pause
exit /b 1

:success
echo.
echo === BUILD SUCCESS ===
echo APK: build\app\outputs\flutter-apk\app-release.apk
pause
