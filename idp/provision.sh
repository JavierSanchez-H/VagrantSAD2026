#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando idp "
echo "########################################"
echo "Actualizando repositorios"
apt-get update -y 
apt-get install -y net-tools iputils-ping curl tcpdump nmap

echo "--------------------------------- $LDAP_PASS -------------------------------"

# --- PARTE 1: Nuestros datos – sustituye con tus datos
DOMAIN="venezuela.org"
ORGANIZACION="Venezuela"
DB_DIR="/vagrant/idp/sldapdb"

# Cargamos datos en debconf para que no se nos pidan durante la configuración
sudo debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string ${DOMAIN}
slapd slapd/organization string ${ORGANIZACION}
slapd slapd/purge_database boolean true
EOF
# Instalamos paquetes necesarios para openldap
apt-get install -y slapd ldap-utils
apt-get autoremove -y
# Esto ignora cualquier fallo de debconf y pone la clave que viene de Vagrant
echo "[*] Forzando contraseña de administrador..."
# Generamos el hash porque openldap está dando mucha lata al cogerla directamente del entorno
SECURE_HASH=$(slappasswd -s "$LDAP_PASS")
cat <<EOF > /tmp/set_pass.ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $SECURE_HASH
EOF
# Usamos -Y EXTERNAL para entrar como root del sistema, sin contraseña
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/set_pass.ldif
# Cargamos datos
echo "[*] Cargando base..."
ldapadd -x -D "cn=admin,dc=venezuela,dc=org" -w $LDAP_PASS -f "$DB_DIR/basedn.ldif" -c
echo "[*] Cargando grupos..."
ldapadd -x -D "cn=admin,dc=venezuela,dc=org" -w $LDAP_PASS -f "$DB_DIR/grupos.ldif" -c
echo "[*] Cargando usuarios..."
ldapadd -x -D "cn=admin,dc=venezuela,dc=org" -w $LDAP_PASS -f "$DB_DIR/usr.ldif" -c
echo "[*] Cargando usuarios de proxy ..."
ldapadd -x -D "cn=admin,dc=venezuela,dc=org" -w $LDAP_PASS -f "$DB_DIR/proxy_users.ldif" -c
echo "[*] Cargando usuarios de vpn..."
ldapadd -x -D "cn=admin,dc=venezuela,dc=org" -w $LDAP_PASS -f "$DB_DIR/vpn_user.ldif" -c


# Acceso web a través del proxy
echo "[*] Configurando acceso web a través del proxy"
cat <<EOF > /etc/apt/apt.conf.d/9proxy
Acquire::http::Proxy "http://172.1.9.2:3128/";
Acquire::https::Proxy "http://172.1.9.2:3128/"; 
EOF
echo "------ FIN ------"