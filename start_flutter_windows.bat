@echo off
echo Starting Flutter App...
echo ========================================

REM Try different Flutter commands
echo Trying to find Flutter installation...

REM Try flutter command
flutter --version >nul 2>&1
if %errorlevel% == 0 (
    echo Found Flutter via 'flutter' command
    flutter run
    goto :end
)

REM Try with full path (from your previous session)
if exist "C:\flutter\bin\flutter.bat" (
    echo Found Flutter at C:\flutter\bin\
    C:\flutter\bin\flutter.bat run
    goto :end
)

REM Try common Flutter paths
if exist "C:\Users\limji\flutter\bin\flutter.bat" (
    echo Found Flutter at C:\Users\limji\flutter\bin\
    C:\Users\limji\flutter\bin\flutter.bat run
    goto :end
)

if exist "C:\Users\limji\AppData\Local\flutter\bin\flutter.bat" (
    echo Found Flutter at AppData\Local\flutter\bin\
    C:\Users\limji\AppData\Local\flutter\bin\flutter.bat run
    goto :end
)

echo.
echo ERROR: Flutter not found!
echo.
echo Please install Flutter from: https://flutter.dev/docs/get-started/install/windows
echo Or add Flutter to your PATH environment variable.
echo.
echo Common Flutter installation paths:
echo - C:\flutter\bin\flutter.bat
echo - C:\Users\limji\flutter\bin\flutter.bat
echo.
echo After installing Flutter, run this script again.
pause

:end




