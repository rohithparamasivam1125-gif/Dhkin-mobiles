@echo off
echo =======================================
echo     AUTOMATED BUILD AND UPLOAD SCRIPT
echo =======================================
echo.

echo 1. Bumping Version in Code...
call dart run tools/bump_version.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to bump version!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 2. Building Release APK...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 3. Copying APK to apks/ folder...
if not exist apks mkdir apks
copy /Y build\app\outputs\flutter-apk\app-release.apk apks\app-release.apk

echo.
echo 4. Uploading to GitHub...
echo.
git status
echo.
set /p msg="Enter your commit message (what you did): "
echo.
echo Adding changes...
git add .
echo.
echo Committing...
git commit -m "%msg%"
echo.
echo Pushing to GitHub...
git push origin main

echo.
echo =======================================
echo         PROCESS COMPLETE!
echo =======================================
echo.
echo Your latest APK is uploaded to GitHub!
echo Direct download link for your staff:
echo https://github.com/rohithparamasivam1125-gif/Dhkin-mobiles/raw/main/apks/app-release.apk
echo.
pause
