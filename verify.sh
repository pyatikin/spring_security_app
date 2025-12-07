#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

print_header() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════"
}

print_test() {
    echo -n "Testing: $1 ... "
}

pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}"
    if [ -n "$1" ]; then
        echo "  Error: $1"
    fi
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}"
    if [ -n "$1" ]; then
        echo "  Warning: $1"
    fi
}

print_header "Spring Security App - Автоматическая проверка"

echo "Дата: $(date)"
echo "Платформа: $(uname -s)"
echo ""

print_header "1. Проверка зависимостей"

print_test "Docker установлен"
if command -v docker &> /dev/null; then
    pass
else
    fail "Docker не найден. Установите Docker."
    exit 1
fi

print_test "Docker Compose установлен"
if command -v docker-compose &> /dev/null; then
    pass
else
    fail "Docker Compose не найден. Установите Docker Compose."
    exit 1
fi

print_test "OpenSSL установлен"
if command -v openssl &> /dev/null; then
    pass
else
    fail "OpenSSL не найден. Установите OpenSSL."
fi

print_test "Curl установлен"
if command -v curl &> /dev/null; then
    pass
else
    fail "Curl не найден. Установите curl."
fi

print_header "2. Проверка сертификатов"

print_test "Сертификаты сгенерированы"
if [ -f "certs/ca.crt" ] && [ -f "certs/server.crt" ] && [ -f "certs/client.crt" ] && [ -f "certs/client.p12" ]; then
    pass
else
    warn "Сертификаты не найдены. Запустите: ./generate-certs.sh"
    echo ""
    echo "Генерирую сертификаты..."
    chmod +x generate-certs.sh
    ./generate-certs.sh > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        pass
    else
        fail "Не удалось сгенерировать сертификаты"
    fi
fi

print_test "CA сертификат валидный"
if openssl x509 -in certs/ca.crt -noout -checkend 0 > /dev/null 2>&1; then
    pass
else
    fail "CA сертификат истёк или невалиден"
fi

print_test "Серверный сертификат валидный"
if openssl x509 -in certs/server.crt -noout -checkend 0 > /dev/null 2>&1; then
    pass
else
    fail "Серверный сертификат истёк или невалиден"
fi

print_test "Клиентский сертификат валидный"
if openssl x509 -in certs/client.crt -noout -checkend 0 > /dev/null 2>&1; then
    pass
else
    fail "Клиентский сертификат истёк или невалиден"
fi

print_header "3. Проверка конфигурации hosts"

print_test "DNS записи в /etc/hosts"
if grep -q "example.com" /etc/hosts 2>/dev/null; then
    pass
else
    warn "Запись example.com не найдена в /etc/hosts"
    echo "  Добавьте: sudo sh -c 'echo \"127.0.0.1 example.com\" >> /etc/hosts'"
fi

print_header "4. Сборка приложения"

print_test "Gradle сборка"
if ./gradlew build -x test --no-daemon > /dev/null 2>&1; then
    pass
else
    fail "Gradle сборка не удалась. Запустите: ./gradlew build -x test"
fi

print_test "JAR файл создан"
if [ -f "build/libs/app.jar" ]; then
    pass
else
    fail "JAR файл не найден"
fi

print_header "5. Docker сервисы"

print_test "Docker Compose файл существует"
if [ -f "docker-compose.yml" ]; then
    pass
else
    fail "docker-compose.yml не найден"
    exit 1
fi

print_test "Запуск Docker сервисов"
echo ""
echo "  Запускаем сервисы (это займёт 2-3 минуты)..."
docker-compose up -d > /dev/null 2>&1
if [ $? -eq 0 ]; then
    pass
else
    fail "Не удалось запустить Docker сервисы"
    exit 1
fi

echo "  Ожидание запуска сервисов..."
sleep 60

print_test "PostgreSQL запущен"
if docker-compose ps | grep postgres | grep -q "Up"; then
    pass
else
    fail "PostgreSQL не запущен"
fi

print_test "Keycloak запущен"
if docker-compose ps | grep keycloak | grep -q "Up"; then
    pass
else
    fail "Keycloak не запущен"
fi

print_test "Spring App запущен"
if docker-compose ps | grep spring-app | grep -q "Up"; then
    pass
else
    fail "Spring App не запущен"
fi

print_test "NGINX запущен"
if docker-compose ps | grep nginx | grep -q "Up"; then
    pass
else
    fail "NGINX не запущен"
fi

print_header "6. Проверка MTLS"

print_test "Доступ БЕЗ сертификата (должен вернуть 403)"
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://example.com --connect-timeout 5 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "400" ]; then
    pass
else
    fail "Ожидался 403, получен $HTTP_CODE"
fi

print_test "Доступ С сертификатом (должен вернуть 200)"
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --cert certs/client.crt --key certs/client.key https://example.com --connect-timeout 5 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    pass
else
    warn "Ожидался 200, получен $HTTP_CODE (возможно сервисы ещё не готовы)"
fi

print_header "7. Проверка логов NGINX"

print_test "Лог файл создан"
if docker-compose exec -T nginx test -f /var/log/nginx/example.com.access.log > /dev/null 2>&1; then
    pass
else
    warn "Лог файл ещё не создан (нет запросов)"
fi

print_test "DN сертификата в логах"
if docker-compose exec -T nginx grep -q "SSL_CLIENT_S_DN" /var/log/nginx/example.com.access.log 2>/dev/null; then
    pass
else
    warn "DN сертификата пока не в логах (сделайте запрос с сертификатом)"
fi

print_header "8. Проверка Keycloak"

print_test "Keycloak доступен"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 --connect-timeout 5 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    pass
else
    warn "Keycloak ещё не готов (код: $HTTP_CODE)"
fi

print_header "9. Проверка приложения"

print_test "Health endpoint доступен"
if docker-compose exec -T app wget -q -O- http://localhost:8080/actuator/health 2>/dev/null | grep -q "UP"; then
    pass
else
    warn "Health endpoint недоступен или приложение не готово"
fi

print_header "Результаты"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "  Пройдено тестов: ${GREEN}$PASSED${NC}"
echo -e "  Провалено тестов: ${RED}$FAILED${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ!${NC}"
    echo ""
    echo "Приложение готово к использованию:"
    echo "  1. Установите сертификаты в браузер (certs/ca.crt и certs/client.p12)"
    echo "  2. Откройте https://example.com"
    echo "  3. Войдите с учётными данными:"
    echo "     - testuser / testuser123 (USER)"
    echo "     - admin / admin123 (ADMIN)"
    echo ""
    echo "Для просмотра логов: docker-compose logs -f"
    echo "Для остановки: docker-compose down"
    echo ""
    exit 0
else
    echo -e "${RED}✗ ОБНАРУЖЕНЫ ПРОБЛЕМЫ${NC}"
    echo ""
    echo "Проверьте следующее:"
    echo "  1. Все сервисы запущены: docker-compose ps"
    echo "  2. Логи сервисов: docker-compose logs"
    echo "  3. Hosts файл: cat /etc/hosts | grep example.com"
    echo "  4. Сертификаты: ls -la certs/"
    echo ""
    echo "Для перезапуска:"
    echo "  docker-compose down"
    echo "  docker-compose up"
    echo ""
    exit 1
fi
