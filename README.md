## Быстрый старт

```bash
# 1. Генерация сертификатов
./generate-certs.sh  # Linux/Mac
# или
generate-certs.bat   # Windows

# 2. Добавить в hosts файл
# Linux/Mac: /etc/hosts
# Windows: C:\Windows\System32\drivers\etc\hosts
127.0.0.1 example.com
127.0.0.1 api.example.com

# 3. Запустить всё
docker-compose up

# 4. Установить сертификаты в браузер (см. раздел "Установка сертификатов")

# 5. Открыть https://example.com
```

## Установка и запуск

### Шаг 1: Генерация сертификатов

**Linux/Mac:**
```bash
chmod +x generate-certs.sh
./generate-certs.sh
```

**Windows:**
```cmd
generate-certs.bat
```

Будут созданы:
- `certs/ca.crt` - корневой CA сертификат
- `certs/server.crt`, `certs/server.key` - серверные сертификаты
- `certs/client.p12` - клиентский сертификат (пароль: `changeit`)

### Шаг 2: Настройка DNS

Добавьте в hosts файл:

**Linux/Mac:**
```bash
sudo nano /etc/hosts
```

**Windows (PowerShell от администратора):**
```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

Добавьте строки:
```
127.0.0.1 example.com
127.0.0.1 api.example.com
```

### Шаг 3: Запуск сервисов

```bash
docker-compose up
```

### Шаг 4: Установка сертификатов в браузер

#### Chrome/Edge:
1. Настройки → Конфиденциальность → Безопасность → Управление сертификатами
2. **Доверенные корневые центры** → Импорт → `certs/ca.crt` → Доверять для веб-сайтов
3. **Личные** → Импорт → `certs/client.p12` (пароль: `changeit`)

### Шаг 5: Доступ к приложению

Откройте https://example.com в браузере. Браузер запросит выбор клиентского сертификата - выберите "Client Certificate".


## Функциональность

### Страницы приложения

| URL | Доступ | Описание |
|-----|--------|----------|
| `/` или `/home` | Все | Главная страница (лендинг) |
| `/public` | Все | Публичная информация |
| `/profile` | USER, ADMIN | Личный кабинет пользователя |
| `/admin` | ADMIN | Панель администратора |

### Учетные записи

#### Keycloak Admin
- URL: http://localhost:8080
- Логин: `admin`
- Пароль: `admin`

#### Пользователи приложения

| Логин | Пароль | Роли | Доступ |
|-------|--------|------|--------|
| testuser | testuser123 | USER | Профиль |
| admin | admin123 | USER, ADMIN | Профиль + Админка |

### Демонстрация работы

Перейдем в наше приложение по адресу https://example.com/ в браузере с импортированными сертификатами

![img.png](img.png)

Далее зарегистрируем нового пользователя с помощью keycloak

![img_1.png](img_1.png)

После войдем в приложение с новым пользователем

![img_2.png](img_2.png)







**1. Войдите как testuser:**
```
Логин: testuser
Пароль: testuser123
```
- Доступен `/profile` ✅
- `/admin` вернет 403 Forbidden ❌

**2. Назначьте роль ADMIN в Keycloak:**
- Откройте http://localhost:8080
- Войдите как admin/admin
- Users → testuser → Role Mappings
- Assign role → admin → Assign

**3. Выйдите и войдите снова как testuser:**
- Теперь доступен `/admin` ✅
- Роли в профиле: ROLE_USER, ROLE_ADMIN

## Тестирование

### Автоматическое тестирование

Запустите скрипт проверки:

```bash
./verify.sh  # Linux/Mac
```

```cmd
verify.bat   # Windows
```

Скрипт проверит:
- ✅ Сборку приложения
- ✅ Запуск Docker сервисов
- ✅ MTLS (403 без сертификата, 200 с сертификатом)
- ✅ Логирование DN сертификата в NGINX
- ✅ Доступность Keycloak
- ✅ Работу health endpoints

### Ручное тестирование

#### Тест 1: MTLS без сертификата (должен вернуть 403)
```bash
curl -k https://example.com
```
**Ожидается:** 403 Forbidden

#### Тест 2: MTLS с сертификатом (должен вернуть 200)
```bash
curl -k --cert certs/client.crt --key certs/client.key https://example.com
```
**Ожидается:** 200 OK с HTML

#### Тест 3: Проверка DN в логах NGINX
```bash
docker-compose exec nginx tail /var/log/nginx/example.com.access.log
```
**Ожидается:** В логах присутствует `SSL_CLIENT_S_DN="CN=Client Certificate..."`

#### Тест 4: Публичный доступ
Откройте https://example.com - должна загрузиться главная страница без входа.

#### Тест 5: Защищенные страницы
Откройте https://example.com/profile - должен перенаправить на Keycloak для входа.

#### Тест 6: Роли
- Войдите как `testuser` → попробуйте `/admin` → 403 Forbidden
- Войдите как `admin` → откройте `/admin` → доступ разрешен

### Сборка и тесты

```bash
# Сборка без тестов
./gradlew build -x test

# Запуск тестов (требуется запущенный Keycloak)
./gradlew test
```

## Структура проекта

```
spring_security_app/
├── src/
│   ├── main/
│   │   ├── java/com/pyatkin/
│   │   │   ├── SpringSecurityApplication.java       # Main
│   │   │   ├── config/
│   │   │   │   ├── SecurityConfig.java             # Security + OAuth2
│   │   │   │   └── CorsConfig.java                 # CORS
│   │   │   └── controller/
│   │   │       ├── HomeController.java             # Публичные страницы
│   │   │       ├── UserController.java             # Профиль
│   │   │       └── AdminController.java            # Админка
│   │   └── resources/
│   │       ├── application.yml                     # Конфигурация
│   │       └── templates/                          # HTML шаблоны
│   └── test/
│       └── java/com/pyatkin/                       # Тесты
├── nginx/
│   ├── nginx.conf                                  # NGINX конфигурация
│   └── conf.d/default.conf                         # Virtual hosts + MTLS
├── keycloak/
│   └── realm-export.json                           # Realm с пользователями
├── certs/                                          # Сертификаты (генерируются)
├── docker-compose.yml                              # Все сервисы
├── Dockerfile                                      # Spring App
├── build.gradle                                    # Сборка
├── generate-certs.sh / .bat                        # Генерация сертификатов
├── verify.sh / .bat                                # Автотесты
└── README.md                                       # Этот файл
```

## Устранение проблем

### Проблема: Сертификат не доверенный

**Решение:**
1. Убедитесь что `ca.crt` импортирован в доверенные корневые центры
2. Перезапустите браузер после установки
3. Проверьте что выбран правильный сертификат

### Проблема: 403 Forbidden в браузере

**Решение:**
1. Убедитесь что `client.p12` установлен в личные сертификаты
2. При запросе браузера выберите "Client Certificate"
3. Проверьте что сертификат не истёк (срок действия 365 дней)

### Проблема: Keycloak не запускается

**Решение:**
```bash
# Посмотрите логи
docker-compose logs keycloak

# Keycloak стартует 1-2 минуты, подождите
```

### Проблема: Не открывается https://example.com

**Решение:**
1. Проверьте hosts файл: `cat /etc/hosts | grep example.com`
2. Проверьте что NGINX запущен: `docker-compose ps nginx`
3. Проверьте логи: `docker-compose logs nginx`

### Проблема: Тесты падают

**Решение:**
Тесты требуют запущенного Keycloak. Используйте:
```bash
./gradlew build -x test  # Сборка без тестов
```

Для полного тестирования запустите сначала `docker-compose up`, затем `./gradlew test`.

### Проблема: Ошибка OpenSSL при генерации сертификатов

**Решение Windows:**
1. Установите OpenSSL: https://slproweb.com/products/Win32OpenSSL.html
2. Добавьте в PATH: `C:\Program Files\OpenSSL-Win64\bin`
3. Перезапустите PowerShell

**Решение Linux/Mac:**
```bash
# Ubuntu/Debian
sudo apt-get install openssl

# MacOS
brew install openssl
```

## Команды

### Управление сервисами

```bash
# Запуск
docker-compose up

# Запуск в фоне
docker-compose up -d

# Остановка
docker-compose down

# Остановка с удалением volumes
docker-compose down -v

# Просмотр логов
docker-compose logs -f

# Просмотр логов конкретного сервиса
docker-compose logs -f app
docker-compose logs -f keycloak
docker-compose logs -f nginx

# Перезапуск сервиса
docker-compose restart app
```

### Сборка приложения

```bash
# Полная сборка
./gradlew clean build

# Сборка без тестов
./gradlew build -x test

# Только компиляция
./gradlew compileJava

# Только тесты
./gradlew test
```

### Проверка

```bash
# Статус контейнеров
docker-compose ps

# Проверка сертификата
openssl x509 -in certs/ca.crt -text -noout

# Проверка клиентского сертификата
openssl pkcs12 -info -in certs/client.p12 -nodes -passin pass:changeit

# Тест MTLS
curl -k --cert certs/client.crt --key certs/client.key https://example.com

# Проверка health
curl http://localhost:8080/actuator/health
```

## Особенности реализации

### CSRF защита
- Включена в `SecurityConfig.java`
- Cookie-based токены
- Автоматически добавляются в формы через Thymeleaf

### CORS
- Настроены в `CorsConfig.java`
- Разрешены origins: `example.com`, `api.example.com`
- Поддержка credentials

### MTLS
- Настроен в `nginx/conf.d/default.conf`
- Требуется валидный клиентский сертификат
- DN сертификата логируется: `$ssl_client_s_dn`

### OAuth2 Flow
1. Пользователь → NGINX (проверка MTLS)
2. NGINX → Spring App
3. Spring App → redirect на Keycloak
4. Пользователь → аутентификация в Keycloak
5. Keycloak → authorization code → Spring App
6. Spring App → обмен code на JWT token
7. Spring App → создание сессии → доступ к ресурсам

## Требования из задания

Все 10 требований из `task.txt` выполнены:

1. ✅ **Веб-приложение Spring** с 4 страницами
2. ✅ **Spring Security + Keycloak** с ролями user и admin
3. ✅ **Docker Compose** - запуск одной командой
4. ✅ **Документация** с демонстрацией пользовательского пути
5. ✅ **CSRF защита** настроена
6. ✅ **CORS Policy** настроены
7. ✅ **NGINX** как единственная точка входа с DNS
8. ✅ **MTLS на NGINX** с CA (403 без сертификата)
9. ✅ **Логи NGINX** с DN сертификата ($ssl_client_s_dn)
10. ✅ **Клиентский сертификат** выпущен и установлен

## Очистка

Для полной очистки:

```bash
# Остановить и удалить всё
docker-compose down -v

# Удалить сертификаты
rm -rf certs/

# Удалить build артефакты
./gradlew clean
```

## Лицензия

Учебный проект для демонстрации enterprise security паттернов.
