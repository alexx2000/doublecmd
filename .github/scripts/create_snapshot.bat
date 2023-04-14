
rem Set Double Commander version
set DC_VER=1.1.0

rem The new package will be created from here
set BUILD_PACK_DIR=%TEMP%\doublecmd-release

rem The new package will be saved here
set PACK_DIR=%CD%\doublecmd-release

rem Prepare target dir
mkdir %PACK_DIR%

rem Get revision number
call src\platform\git2revisioninc.exe.cmd %CD%
echo %REVISION%> %PACK_DIR%\revision.txt

rem Set processor architecture
set CPU_TARGET=i386
set OS_TARGET=win32

call :doublecmd

rem Set processor architecture
set CPU_TARGET=x86_64
set OS_TARGET=win64

call :doublecmd

GOTO:EOF

:doublecmd
  rem Build all components of Double Commander
  call build.bat darkwin

  rem Copy libraries
  copy install\windows\lib\%CPU_TARGET%\*.dll             %CD%\
  copy install\windows\lib\%CPU_TARGET%\winpty-agent.exe  %CD%\

  rem Prepare install dir
  mkdir %BUILD_PACK_DIR%

  rem Prepare install files
  call install\windows\install.bat

  rem Create *.zip package
  powershell "Compress-Archive -Path """%DC_INSTALL_DIR%\*""" -DestinationPath """%PACK_DIR%\doublecmd-%DC_VER%.r%REVISION%.%CPU_TARGET%-%OS_TARGET%.zip""""

  rem Clean
  del /Q *.dll
  del /Q *.exe
  call clean.bat
  rm -rf %BUILD_PACK_DIR%

GOTO:EOF
