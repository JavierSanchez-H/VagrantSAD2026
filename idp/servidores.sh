#!/bin/bash


PROXY="http://172.1.99.2:3128"
IP=$(ip -4 addr show dev eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "###################################################"
echo "# Tests del proxy - Servidores                    #"
echo "###################################################"
echo "Ejecutando tests desde $IP - $(cat /etc/hostname)"

url="http://security.ubuntu.com"
status=$(curl -s -o /dev/null -x "$PROXY" "$url" -w "%{http_code}")
echo -e "\n[*] El filtro de dominios permite actualizaciones. Esperado: 200 OK"
if [ "$status" -eq 301 ]; then
    echo "[OK] Acceso concedido a $url (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

url="http://www.google.com"
status=$(curl -s -o /dev/null -x "$PROXY" "$url" -w "%{http_code}")
echo -e "\n[*] El proxy bloquea sitios no esenciales. Esperado 403 Forbidden."
if [ "$status" -eq 403 ]; then
    echo "[OK] Acceso concedido a $url (Código: $status)"
else
    echo "[FALLO] Error inesperado o de red. Código: $status"
fi

url="http://www.ubuntu.com"
echo -e "\n[*] El Firewall impide salir a Internet sin pasar por el Proxy. Timeout de 5 segundos..."
curl -s -o /dev/null "$url" --connect-timeout 5
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "[FALLO] Conexión a $url ha salido sin pasar por el proxy"
else
    echo "[OK] Paquete descartado"
fi