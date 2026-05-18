@echo off
REM Habbo (AIR desktop build) build script
REM Builds the AIR-root HabboAir.swf and packages it as a captive-runtime app.
REM Override with: set AIR_HOME=path\to\sdk

setlocal

if not defined AIR_HOME set "AIR_HOME=C:\harman-air\AIRSDK_51.3.1"
if not defined JAVA_HOME set "JAVA_HOME=C:\Program Files\Java\jdk-21"
if not defined CLIENT_DIR set "CLIENT_DIR=C:\habbo\client\habbo-client-clean"
if not defined GORDON_DIR set "GORDON_DIR=C:\habbo\ngh\gordon\PRODUCTION-201611291003-338511768"

set "AMXMLC=%AIR_HOME%\bin\amxmlc.bat"
set "ADT=%AIR_HOME%\bin\adt.bat"
set "ADL=%AIR_HOME%\bin\adl.exe"
set "AIR_GLOBAL=%AIR_HOME%\frameworks\libs\air\airglobal.swc"
set "PATH=%JAVA_HOME%\bin;%PATH%"

set "PROJECT_DIR=%~dp0"
set "CLIENT_SRC_DIR=%CLIENT_DIR%\src"
set "BUILD_DIR=%PROJECT_DIR%build"
set "OUTPUT_SWF=%BUILD_DIR%\HabboAir.swf"
set "LOCAL_INCLUDE_DIR=%BUILD_DIR%\local_include"
set "DESCRIPTOR=%BUILD_DIR%\application.xml"
set "CERT=%PROJECT_DIR%cert.p12"
set "CERT_PASS=nghwin"
set "BUNDLE_DIR=%PROJECT_DIR%HabboBundle"

if "%1"=="" goto :all
if /I "%1"=="compile" goto :compile
if /I "%1"=="run" goto :run
if /I "%1"=="package" goto :package
if /I "%1"=="cert" goto :cert
if /I "%1"=="clean" goto :clean
echo Unknown target: %1
echo Usage: build.bat [compile^|run^|package^|cert^|clean]
exit /b 1

:all
call :compile
if errorlevel 1 exit /b 1
call :package
exit /b %errorlevel%

:compile
echo === Compiling HabboAir.swf ===
pushd "%CLIENT_DIR%"
cmd.exe /c npm run tool -- build --source src/HabboAir.as --output "%OUTPUT_SWF%" --bin "%BUILD_DIR%" --no-archive -- -external-library-path+="%AIR_GLOBAL%"
set "COMPILE_EXIT=%ERRORLEVEL%"
popd
if not "%COMPILE_EXIT%"=="0" exit /b %COMPILE_EXIT%
if errorlevel 1 exit /b %errorlevel%
echo === Staging AIR local_include room assets ===
if exist "%BUILD_DIR%\Habbo.swf" del "%BUILD_DIR%\Habbo.swf"
if exist "%LOCAL_INCLUDE_DIR%" rmdir /s /q "%LOCAL_INCLUDE_DIR%"
mkdir "%LOCAL_INCLUDE_DIR%" >nul
for %%F in (HabboRoomContent.swf PlaceHolderFurniture.swf PlaceHolderWallItem.swf PlaceHolderPet.swf TileCursor.swf SelectionArrow.swf) do (
    if not exist "%GORDON_DIR%\%%F" (
        echo ERROR: %GORDON_DIR%\%%F not found.
        exit /b 1
    )
    copy /Y "%GORDON_DIR%\%%F" "%LOCAL_INCLUDE_DIR%\%%F" >nul
)
echo Staged local_include assets from %GORDON_DIR%
echo === Staging runtime config ===
if exist "%PROJECT_DIR%config.ini" (
    copy /Y "%PROJECT_DIR%config.ini" "%BUILD_DIR%\config.ini" >nul
    echo Staged config.ini from %PROJECT_DIR%config.ini
) else (
    echo WARNING: config.ini missing -- bundle will fall back to hardcoded defaults.
)
echo === Staging app icons ===
if exist "%BUILD_DIR%\icons" rmdir /s /q "%BUILD_DIR%\icons"
if exist "%PROJECT_DIR%icons" (
    mkdir "%BUILD_DIR%\icons" >nul
    for %%I in (16 32 48 128) do (
        if not exist "%PROJECT_DIR%icons\icon-%%I.png" (
            echo ERROR: %PROJECT_DIR%icons\icon-%%I.png missing.
            exit /b 1
        )
        copy /Y "%PROJECT_DIR%icons\icon-%%I.png" "%BUILD_DIR%\icons\icon-%%I.png" >nul
    )
    echo Staged icons from %PROJECT_DIR%icons
) else (
    echo WARNING: icons folder missing -- bundle will use default AIR icon.
)
exit /b 0

:run
echo === Launching with ADL (dev mode) ===
"%ADL%" "%DESCRIPTOR%" "%BUILD_DIR%"
exit /b %errorlevel%

:cert
echo === Generating self-signed certificate ===
if exist "%CERT%" (
    echo cert.p12 already exists, delete it first to regenerate.
    exit /b 0
)
call "%ADT%" -certificate -cn NGHWin -ou NGH -o NGH -c GB 2048-RSA "%CERT%" %CERT_PASS%
exit /b %errorlevel%

:package
if not exist "%CERT%" (
    echo No cert.p12 found. Run: build.bat cert
    exit /b 1
)
if exist "%BUNDLE_DIR%" (
    rmdir /s /q "%BUNDLE_DIR%"
    if exist "%BUNDLE_DIR%" (
        echo ERROR: Could not remove existing bundle at %BUNDLE_DIR%.
        echo Close Habbo.exe or any Explorer window using that folder, then run build.bat again.
        exit /b 1
    )
)
echo === Packaging captive-runtime bundle ===
call "%ADT%" -package -storetype pkcs12 -keystore "%CERT%" -storepass %CERT_PASS% -tsa none -target bundle "%BUNDLE_DIR%" "%DESCRIPTOR%" -C "%BUILD_DIR%" .
set "PACKAGE_EXIT=%ERRORLEVEL%"
if not "%PACKAGE_EXIT%"=="0" exit /b %PACKAGE_EXIT%
echo.
echo Bundle written to: %BUNDLE_DIR%
echo Run: %BUNDLE_DIR%\Habbo.exe
exit /b 0

:clean
if exist "%OUTPUT_SWF%" del "%OUTPUT_SWF%"
if exist "%BUILD_DIR%\Habbo.swf" del "%BUILD_DIR%\Habbo.swf"
if exist "%BUILD_DIR%\config.ini" del "%BUILD_DIR%\config.ini"
if exist "%BUILD_DIR%\icons" rmdir /s /q "%BUILD_DIR%\icons"
if exist "%LOCAL_INCLUDE_DIR%" rmdir /s /q "%LOCAL_INCLUDE_DIR%"
if exist "%BUNDLE_DIR%" rmdir /s /q "%BUNDLE_DIR%"
if exist "%BUNDLE_DIR%" (
    echo ERROR: Could not remove existing bundle at %BUNDLE_DIR%.
    echo Close Habbo.exe or any Explorer window using that folder, then run clean again.
    exit /b 1
)
echo Cleaned build artifacts.
exit /b 0
