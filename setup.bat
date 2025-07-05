@echo off
echo MCPy Setup and Build Script
echo =========================
echo.

REM Parse command line arguments
set ACTION=all
if not "%1"=="" set ACTION=%1

if "%ACTION%"=="help" (
    echo Usage: setup.bat [action]
    echo.
    echo Available actions:
    echo   env        - Set up virtual environment and install dependencies
    echo   build      - Build Cython modules
    echo   run        - Run the server
    echo   all        - Perform all actions except run (default)
    echo   help       - Display this help message
    exit /b 0
)

if "%ACTION%"=="env" goto setup_env
if "%ACTION%"=="build" goto build_cython
if "%ACTION%"=="run" goto run_server
if "%ACTION%"=="all" goto all

echo Unknown action: %ACTION%
echo Run 'setup.bat help' for usage information
exit /b 1

:all
call :setup_env
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
call :build_cython
exit /b %ERRORLEVEL%

:setup_env
echo Setting up virtual environment and installing dependencies...
echo.

REM Check if Python is installed
python --version > nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Python not found. Please install Python 3.9 or later.
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist .venv (
    echo Creating virtual environment...
    python -m venv .venv
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create virtual environment.
        exit /b 1
    )
)

REM Activate virtual environment
call .venv\Scripts\activate
if %ERRORLEVEL% NEQ 0 (
    echo Failed to activate virtual environment.
    exit /b 1
)

REM Install dependencies
echo Installing dependencies...
python -m pip install --upgrade pip
if %ERRORLEVEL% NEQ 0 exit /b 1

pip install -r requirements.txt
if %ERRORLEVEL% NEQ 0 exit /b 1

pip install -e ".[dev]"
if %ERRORLEVEL% NEQ 0 exit /b 1

REM Check dependencies
echo Checking dependencies...
python check_dependencies.py
if %ERRORLEVEL% NEQ 0 (
    echo Some dependencies may be missing. Check the output above.
    echo You may need to install system dependencies or rebuild Cython modules.
)

echo.
echo Virtual environment set up successfully.
echo.
exit /b 0

:build_cython
echo Building Cython modules...
echo.

REM Activate virtual environment if not already activated
if not defined VIRTUAL_ENV (
    call .venv\Scripts\activate
)

REM Clean previous builds
echo Cleaning previous builds...
if exist build rmdir /s /q build
if exist mcpy\core\*.c del /q mcpy\core\*.c

REM Build Cython extensions
python setup.py build_ext --inplace
if %ERRORLEVEL% NEQ 0 (
    echo Failed to build Cython extensions.
    exit /b 1
)

echo.
echo Cython modules built successfully.
echo.
exit /b 0



:run_server
echo Running the MCPy server...
echo.

REM Activate virtual environment if not already activated
if not defined VIRTUAL_ENV (
    call .venv\Scripts\activate
)

REM Run the server
python -m mcpy.server %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%

:end
echo.
echo Setup completed successfully!
echo.
echo To run the server, use: setup.bat run
echo For other options, use: setup.bat help
echo.

pause
