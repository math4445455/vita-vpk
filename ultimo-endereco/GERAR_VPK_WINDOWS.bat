@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
echo =================================================
echo       O ULTIMO ENDERECO - PORT NATIVO VITA
echo =================================================
echo.
echo Arraste eboot_safe.bin OFICIAL do Lua Player Plus Vita
echo sobre este .bat ou informe o caminho completo.
echo Tambem aceita o VPK original do LPP-Vita.
echo.
if not "%~1"=="" (
  set "LPPVPK=%~1"
) else (
  set /p "LPPVPK=Caminho do eboot_safe.bin (ou VPK original): "
)
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0build_vpk.py" "%LPPVPK%"
) else (
  python "%~dp0build_vpk.py" "%LPPVPK%"
)
if errorlevel 1 (
  echo.
  echo Falha ao gerar o VPK. Confira o caminho e se o Python esta instalado.
) else (
  echo.
  echo Pronto! Instale O_ULTIMO_ENDERECO_VITA.vpk pelo VitaShell.
)
pause
