@echo off

set "addon=C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\SmellTheRoses"

robocopy "%~dp0." "%addon%" SmellTheRoses.toc >nul
robocopy "%~dp0Core" "%addon%\Core" /E >nul
robocopy "%~dp0Compat" "%addon%\Compat" /E >nul
robocopy "%~dp0Art" "%addon%\Art" /E >nul
