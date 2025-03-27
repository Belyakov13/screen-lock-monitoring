@echo off
echo ===================================================
echo = Установка мониторинга времени блокировки для Zabbix =
echo ===================================================
echo.

:: Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ОШИБКА: Запустите этот файл от имени администратора!
    echo Щелкните правой кнопкой мыши на install.bat и выберите "Запуск от имени администратора"
    echo.
    pause
    exit /b 1
)

echo Запуск установки...
echo.

:: Запуск PowerShell скрипта установки
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_lock_time_tracker.ps1"

echo.
echo Установка завершена!
echo.
echo Для проверки работы:
echo 1. Заблокируйте компьютер (Win+L)
echo 2. Подождите несколько секунд
echo 3. Разблокируйте компьютер
echo 4. Проверьте файлы в директории C:\ProgramData\PC_Lock_Monitor\
echo.
pause
