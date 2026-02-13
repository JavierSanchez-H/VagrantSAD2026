#!/bin/sh

# El script se detiene si hay errores
set -e
echo "########################################"
echo " Aprovisionando adminpc "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apk update
apk add curl nmap tcpdump wget bash iputils

echo "[+] Configurando proxy para apk"
cat <<EOF > /etc/profile.d/proxy.sh
export http_proxy=http://$EMP_USERNAME:$EMP_PASS@172.1.99.2:3128
export https_proxy=http://$EMP_USERNAME:$EMP_PASS@172.1.99.2:3128
EOF

# Aplicar cambios
source /etc/profile


echo "------ FIN ------"