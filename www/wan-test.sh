#!/bin/bash
NUM=99
SERVIDOR_WEB="203.0.113.254" # Se está redireccionando a través de la WAN del fw
FW="203.0.113.254"
HOST_LAN_PC="172.2.$NUM.10"
echo "=== WAN Test Script ==="
IP=$(ip -4 addr show dev eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "Ejecutando tests desde $IP - $(cat /etc/hostname)"

# 1. Probar que el tráfico HTTP dirigido a la DMZ es redirigido y llega al servidor web
echo -e "\nProbando conexión HTTP a servidor web DMZ ($SERVIDOR_WEB)..."
curl -s --connect-timeout 5 http://$SERVIDOR_WEB && echo "[*] OK!!!  HTTP OK" || echo "[!] FALLO!!!  HTTP fallido"

# 2. Probar que el acceso SSH al firewall está bloqueado (suponiendo que la IP del firewall en WAN es 192.168.N.254)
echo -e "\nProbando conexión SSH al firewall ($FW:22)..."
timeout 5 bash -c "echo > /dev/tcp/$FW/22" \
  && echo "[!] FALLO!!!  Puerto 22 abierto" \
  || echo "[*] OK!!!  Puerto 22 cerrado"

# 3. Probar que la conectividad a la LAN está bloqueada
echo -e "\nProbando ping a un host de la LAN (por ejemplo, $HOST_LAN_PC)... Espera un poco ..."
ping -c 2 $HOST_LAN_PC > /dev/null && echo "[!] FALLO!!!   Ping exitoso" || echo "[*] OK!!!  Ping bloqueado"
