@echo off
echo =======================================
echo     UPLOADING CHANGES TO GITHUB
echo =======================================
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
echo          UPLOAD COMPLETE!
echo =======================================
pause
