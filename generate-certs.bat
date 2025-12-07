@echo off
setlocal enabledelayedexpansion

set CERTS_DIR=.\certs
if not exist "%CERTS_DIR%" mkdir "%CERTS_DIR%"

echo Generating certificates for MTLS...
echo.

echo 1. Generating CA private key and certificate...
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -keyout "%CERTS_DIR%\ca.key" -out "%CERTS_DIR%\ca.crt" -subj "/C=US/ST=State/L=City/O=SecureApp/OU=IT/CN=SecureApp Root CA"

echo 2. Generating server private key...
openssl genrsa -out "%CERTS_DIR%\server.key" 4096

echo 3. Generating server certificate signing request...
openssl req -new -key "%CERTS_DIR%\server.key" -out "%CERTS_DIR%\server.csr" -subj "/C=US/ST=State/L=City/O=SecureApp/OU=IT/CN=example.com"

echo 4. Creating server certificate extensions...
(
echo authorityKeyIdentifier=keyid,issuer
echo basicConstraints=CA:FALSE
echo keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
echo subjectAltName = @alt_names
echo.
echo [alt_names]
echo DNS.1 = example.com
echo DNS.2 = api.example.com
echo DNS.3 = localhost
echo DNS.4 = *.example.com
echo IP.1 = 127.0.0.1
) > "%CERTS_DIR%\server.ext"

echo 5. Signing server certificate with CA...
openssl x509 -req -in "%CERTS_DIR%\server.csr" -CA "%CERTS_DIR%\ca.crt" -CAkey "%CERTS_DIR%\ca.key" -CAcreateserial -out "%CERTS_DIR%\server.crt" -days 365 -extfile "%CERTS_DIR%\server.ext"

echo 6. Generating client private key...
openssl genrsa -out "%CERTS_DIR%\client.key" 4096

echo 7. Generating client certificate signing request...
openssl req -new -key "%CERTS_DIR%\client.key" -out "%CERTS_DIR%\client.csr" -subj "/C=US/ST=State/L=City/O=SecureApp/OU=IT/CN=Client Certificate"

echo 8. Creating client certificate extensions...
(
echo authorityKeyIdentifier=keyid,issuer
echo basicConstraints=CA:FALSE
echo keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
echo extendedKeyUsage = clientAuth
) > "%CERTS_DIR%\client.ext"

echo 9. Signing client certificate with CA...
openssl x509 -req -in "%CERTS_DIR%\client.csr" -CA "%CERTS_DIR%\ca.crt" -CAkey "%CERTS_DIR%\ca.key" -CAcreateserial -out "%CERTS_DIR%\client.crt" -days 365 -extfile "%CERTS_DIR%\client.ext"

echo 10. Creating PKCS#12 bundle for client certificate...
openssl pkcs12 -export -out "%CERTS_DIR%\client.p12" -inkey "%CERTS_DIR%\client.key" -in "%CERTS_DIR%\client.crt" -certfile "%CERTS_DIR%\ca.crt" -passout pass:changeit

echo 11. Cleaning up temporary files...
del /q "%CERTS_DIR%\server.csr" "%CERTS_DIR%\server.ext" "%CERTS_DIR%\client.csr" "%CERTS_DIR%\client.ext" "%CERTS_DIR%\ca.srl" 2>nul

echo.
echo Certificate generation completed!
echo.
echo Generated files:
echo   - CA Certificate: %CERTS_DIR%\ca.crt
echo   - CA Private Key: %CERTS_DIR%\ca.key
echo   - Server Certificate: %CERTS_DIR%\server.crt
echo   - Server Private Key: %CERTS_DIR%\server.key
echo   - Client Certificate: %CERTS_DIR%\client.crt
echo   - Client Private Key: %CERTS_DIR%\client.key
echo   - Client PKCS#12 Bundle: %CERTS_DIR%\client.p12 (password: changeit)
echo.
echo To install the client certificate in your browser:
echo   1. Import %CERTS_DIR%\client.p12 (password: changeit)
echo   2. Import %CERTS_DIR%\ca.crt as a trusted root CA
echo.
echo To add DNS entries, add these lines to C:\Windows\System32\drivers\etc\hosts:
echo   127.0.0.1 example.com
echo   127.0.0.1 api.example.com
echo.

pause
