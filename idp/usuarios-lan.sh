#!/bin/bash

IP=$(ip -4 addr show dev eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PROXY="http://USUARIO_LDAP:CONTRASEÑA@172.1.99.2:3128"
PROXY_NO_AUTH="http://172.1.99.2:3128"

echo "###################################################"
echo "# Tests del proxy - Clientes LAN                  #"
echo "###################################################"
echo "Ejecutando tests desde $IP - $(cat /etc/hostname)"


# El proxy exige autenticación. - Esperado 407
url="http://www.google.com"
status=$(curl -s -o /dev/null -x "$PROXY_NO_AUTH" "$url" -w "%{http_code}")
echo -e "\n[*] El proxy exige autenticación.. Esperado: 407"
if [ "$status" -eq 407 ]; then
    echo "[OK] Proxy pide credenciales (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

# Usuario de LDAP y grupo proxy_users correctos. Esperado 200 Ok
url="http://www.google.com"
status=$(curl -s -o /dev/null -x "$PROXY" "$url" -w "%{http_code}")
echo -e "\n[*] Usuario de LDAP y grupo proxy_users correctos. Esperado 200 Ok"
if [ "$status" -eq 200 ]; then
    echo "[OK] Proxy pide credenciales (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

# El filtro de Redes Sociales funciona. Esperado 403 Forbidden
url="http://www.facebook.com"
status=$(curl -s -o /dev/null -x "$PROXY" "$url" -w "%{http_code}")
echo -e "\n[*] El filtro de Redes Sociales funciona. Esperado 403 Forbidden"
if [ "$status" -eq 403 ]; then
    echo "[OK] Proxy filtra redes sociales (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

# El filtro de expresiones prohibidas funciona. Esperado: 403
url="http://crackstation.com"
status=$(curl -s -o /dev/null -x "$PROXY" "$url" -w "%{http_code}")
echo -e "\n[*] El filtro de Redes Sociales funciona. Esperado 403 Forbidden"
if [ "$status" -eq 403 ]; then
    echo "[OK] Filtro de expresiones regulares funciona correctamente (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

