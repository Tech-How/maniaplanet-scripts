@echo off

:: Triggers a shadow-recompute of all the maps in your Maniaplanet docs folder for resurrecting very old ones

:: Edit these values to configure the script.
set MANIAPLANET_INSTALL_DIR=
set MANIAPLANET_DOCS_DIR=
set LIGHTMAP_QUALITY=High


echo Maniaplanet Map Upgrade Tool
echo.
echo Maniaplanet Docs Dir: "%MANIAPLANET_DOCS_DIR%"
echo Maniaplanet Game Dir: "%MANIAPLANET_INSTALL_DIR%"
echo Lightmap Quality: %LIGHTMAP_QUALITY%
echo.
echo.
if exist "%MANIAPLANET_DOCS_DIR%\LightmapsCopy" (
    echo Please delete or move the existing LightmapsCopy folder before proceeding.
    explorer %MANIAPLANET_DOCS_DIR%
    pause
    exit /b 1
)

echo This will force an upgrade to ALL maps currently in your maps directory to the latest version of Maniaplanet.
echo Please remove any maps except the ones that need to be upgraded from your folder now.
echo.
echo If you haven't set your game and user data paths, edit this script and make those changes first.
echo Make sure your game is closed before proceeding.
pause
echo.
echo Please sign into the Maniaplanet client and don't interrupt it.
echo The window will close once all maps have been processed.
echo Press any key to begin the conversion...
pause >nul

echo ManiaPlanet started
"%MANIAPLANET_INSTALL_DIR%\ManiaPlanet.exe" /computeallshadows /upgrademaps /useronly /fullcheck /LmQuality=%LIGHTMAP_QUALITY%
echo.
echo The conversion has been completed. Would you like to delete the LightmapsCopy cache?
choice /c yn /n /m "[Y/N] "
if errorlevel 2 exit /b
if errorlevel 1 rd /s /q "%MANIAPLANET_DOCS_DIR%\LightmapsCopy"
exit /b