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
export http_proxy=http://$EMP_USERNAME:$EMP_PASS@172.1.9.2:3128
export https_proxy=http://$EMP_USERNAME:$EMP_PASS@172.1.9.2:3128
EOF

# Aplicar cambios
source /etc/profile
echo "[*] Verificando contraseña..."
ldapwhoami -x -D "cn=admin,dc=venezuela,dc=org" -w "$LDAP_PASS"

echo "--$LDAP_PASS--"

# Acceso web a través del proxy
echo "[*] Configurando acceso web a través del proxy"
cat <<EOF > /etc/apt/apt.conf.d/9proxy
Acquire::http::Proxy "http://172.1.9.2:3128/";
Acquire::https::Proxy "http://172.1.9.2:3128/";
EOF

echo "------ FIN ------"


echo "------ FIN ------"