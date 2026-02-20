#!/bin/bash
set -x


USERID=$1

if [ -z "$USERID" ]; then
    echo "Uso: $0 nombre_del_cliente"
    exit 1
fi

echo "[*] Generando certificado de cliente para $USERID"
cd /etc/openvpn/easy-rsa/
# Generamos par de claves para el cliente
/etc/openvpn/easy-rsa/easyrsa --batch gen-req ${USERID} nopass
# Generamos certificado con la clave pública del cliente y lo firmamos
/etc/openvpn/easy-rsa/easyrsa --batch sign-req client ${USERID}

# Copiamos ficheros generados
cp /etc/openvpn/easy-rsa/pki/issued/${USERID}.crt /etc/openvpn/client/keys
cp /etc/openvpn/easy-rsa/pki/private/${USERID}.key /etc/openvpn/client/keys

# Generamos fichero .ovpn
KEY_DIR=/etc/openvpn/client/keys
OUTPUT_DIR=/etc/openvpn/client/files
BASE_CONFIG=/etc/openvpn/client/client.conf

cat ${BASE_CONFIG} > ${OUTPUT_DIR}/${USERID}.ovpn
echo -e '<ca>' >> ${OUTPUT_DIR}/${USERID}.ovpn 
cat ${KEY_DIR}/ca.crt  >> ${OUTPUT_DIR}/${USERID}.ovpn
echo -e '</ca>\n<cert>' >> ${OUTPUT_DIR}/${USERID}.ovpn
cat ${KEY_DIR}/${USERID}.crt >> ${OUTPUT_DIR}/${USERID}.ovpn
echo -e '</cert>\n<key>' >> ${OUTPUT_DIR}/${USERID}.ovpn
cat ${KEY_DIR}/${USERID}.key >> ${OUTPUT_DIR}/${USERID}.ovpn
echo -e '</key>\n<tls-crypt>' >> ${OUTPUT_DIR}/${USERID}.ovpn
cat ${KEY_DIR}/ta.key >> ${OUTPUT_DIR}/${USERID}.ovpn
echo -e '</tls-crypt>' >> ${OUTPUT_DIR}/${USERID}.ovpn