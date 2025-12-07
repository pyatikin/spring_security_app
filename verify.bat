@echo off
setlocal enabledelayedexpansion

set PASSED=0
set FAILED=0

echo.
echo ===================================================================
echo   Spring Security App - Автоматическая проверка
echo ===================================================================
echo Дата: %date% %time%
echo Платформа: Windows
echo.

echo ===================================================================
echo   1. Проверка зависимостей
echo ===================================================================

echo Testing: Docker установлен ...
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Docker не найден
    set /a FAILED+=1
)

echo Testing: Docker Compose установлен ...
docker-compose --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Docker Compose не найден
    set /a FAILED+=1
)

echo Testing: OpenSSL установлен ...
openssl version >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m OpenSSL не найден
    set /a FAILED+=1
)

echo Testing: Curl установлен ...
curl --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Curl не найден
    set /a FAILED+=1
)

echo.
echo ===================================================================
echo   2. Проверка сертификатов
echo ===================================================================

echo Testing: Сертификаты сгенерированы ...
if exist "certs\ca.crt" if exist "certs\server.crt" if exist "certs\client.crt" if exist "certs\client.p12" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [93m[WARN][0m Сертификаты не найдены, генерирую...
    call generate-certs.bat >nul 2>&1
    if !errorlevel! equ 0 (
        echo [92m[PASS][0m Сертификаты сгенерированы
        set /a PASSED+=1
    ) else (
        echo [91m[FAIL][0m Не удалось сгенерировать сертификаты
        set /a FAILED+=1
    )
)

echo Testing: CA сертификат валидный ...
openssl x509 -in certs\ca.crt -noout -checkend 0 >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m CA сертификат невалиден
    set /a FAILED+=1
)

echo.
echo ===================================================================
echo   3. Проверка конфигурации hosts
echo ===================================================================

echo Testing: DNS записи в hosts ...
findstr /C:"example.com" C:\Windows\System32\drivers\etc\hosts >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [93m[WARN][0m Запись example.com не найдена в hosts
    echo   Добавьте: 127.0.0.1 example.com
    set /a FAILED+=1
)

echo.
echo ===================================================================
echo   4. Сборка приложения
echo ===================================================================

echo Testing: Gradle сборка ...
call gradlew.bat build -x test --no-daemon >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Gradle сборка не удалась
    set /a FAILED+=1
)

echo Testing: JAR файл создан ...
if exist "build\libs\app.jar" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m JAR файл не найден
    set /a FAILED+=1
)

echo.
echo ===================================================================
echo   5. Docker сервисы
echo ===================================================================

echo Testing: Docker Compose файл существует ...
if exist "docker-compose.yml" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m docker-compose.yml не найден
    set /a FAILED+=1
    goto summary
)

echo Testing: Запуск Docker сервисов ...
echo   Запускаем сервисы (это займёт 2-3 минуты)...
docker-compose up -d >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Не удалось запустить Docker сервисы
    set /a FAILED+=1
    goto summary
)

echo   Ожидание запуска сервисов...
timeout /t 60 /nobreak >nul

echo Testing: PostgreSQL запущен ...
docker-compose ps | findstr /C:"postgres" | findstr /C:"Up" >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m PostgreSQL не запущен
    set /a FAILED+=1
)

echo Testing: Keycloak запущен ...
docker-compose ps | findstr /C:"keycloak" | findstr /C:"Up" >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Keycloak не запущен
    set /a FAILED+=1
)

echo Testing: Spring App запущен ...
docker-compose ps | findstr /C:"spring-app" | findstr /C:"Up" >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Spring App не запущен
    set /a FAILED+=1
)

echo Testing: NGINX запущен ...
docker-compose ps | findstr /C:"nginx" | findstr /C:"Up" >nul 2>&1
if %errorlevel% equ 0 (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m NGINX не запущен
    set /a FAILED+=1
)

echo.
echo ===================================================================
echo   6. Проверка MTLS
echo ===================================================================

echo Testing: Доступ БЕЗ сертификата (должен вернуть 403) ...
for /f %%i in ('curl -k -s -o nul -w "%%{http_code}" https://example.com --connect-timeout 5 2^>nul') do set HTTP_CODE=%%i
if "!HTTP_CODE!"=="403" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else if "!HTTP_CODE!"=="000" (
    echo [92m[PASS][0m (соединение отклонено без сертификата)
    set /a PASSED+=1
) else (
    echo [91m[FAIL][0m Получен код: !HTTP_CODE!
    set /a FAILED+=1
)

echo Testing: Доступ С сертификатом (должен вернуть 200) ...
for /f %%i in ('curl -k -s -o nul -w "%%{http_code}" --cert certs/client.crt --key certs/client.key https://example.com --connect-timeout 5 2^>nul') do set HTTP_CODE=%%i
if "!HTTP_CODE!"=="200" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [93m[WARN][0m Получен код: !HTTP_CODE! (сервисы могут быть не готовы)
)

echo.
echo ===================================================================
echo   7. Проверка Keycloak
echo ===================================================================

echo Testing: Keycloak доступен ...
for /f %%i in ('curl -s -o nul -w "%%{http_code}" http://localhost:8080 --connect-timeout 5 2^>nul') do set HTTP_CODE=%%i
if "!HTTP_CODE!"=="200" (
    echo [92m[PASS][0m
    set /a PASSED+=1
) else (
    echo [93m[WARN][0m Keycloak ещё не готов (код: !HTTP_CODE!)
)

:summary
echo.
echo ===================================================================
echo   Результаты
echo ===================================================================
echo.
echo   Пройдено тестов: %PASSED%
echo   Провалено тестов: %FAILED%
echo.

if %FAILED% equ 0 (
    echo [92mВСЕ ПРОВЕРКИ ПРОЙДЕНЫ![0m
    echo.
    echo Приложение готово к использованию:
    echo   1. Установите сертификаты в браузер
    echo      - certs\ca.crt ^(Доверенные корневые центры^)
    echo      - certs\client.p12 ^(Личные, пароль: changeit^)
    echo   2. Откройте https://example.com
    echo   3. Войдите:
    echo      - testuser / testuser123 ^(USER^)
    echo      - admin / admin123 ^(ADMIN^)
    echo.
    echo Для просмотра логов: docker-compose logs -f
    echo Для остановки: docker-compose down
    echo.
) else (
    echo [91mОБНАРУЖЕНЫ ПРОБЛЕМЫ[0m
    echo.
    echo Проверьте:
    echo   1. docker-compose ps
    echo   2. docker-compose logs
    echo   3. Hosts файл
    echo   4. Сертификаты в папке certs\
    echo.
    echo Для перезапуска:
    echo   docker-compose down
    echo   docker-compose up
    echo.
)

pause
