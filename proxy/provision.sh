#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando proxy "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y 
apt-get install -y net-tools iputils-ping curl tcpdump nmap squid
apt-get autoremove -y

# Copiamos los ficheros de configuración
echo '[*] Copiando ficheros de configuración'
cp /vagrant/proxy/conf/squid.conf /etc/squid/
cp /vagrant/proxy/conf/lan.conf /etc/squid/conf.d/
cp /vagrant/proxy/conf/dmz.conf /etc/squid/conf.d/

# Copiamos ficheros de dominios
echo '[*] Copiando ficheros de dominios'
cp /vagrant/proxy/block-exp /etc/squid/
cp /vagrant/proxy/dominios-denegados /etc/squid/
cp /vagrant/proxy/dominios-permitidos-dmz /etc/squid/

# Reiniciando squid
echo '[*] Recargando configuración de squid'
squid -k reconfigure


echo "Copiando configuracion principal"
cp /vagrant/proxy/conf/squid.conf /etc/squid/squid.conf

echo "Copiando configuraciones adicionales"
cp /vagrant/proxy/conf/lan.conf /etc/squid/conf.d/
cp /vagrant/proxy/conf/dmz.conf /etc/squid/conf.d/

echo "Copiando listas"
cp /vagrant/proxy/dominios-denegados /etc/squid/
cp /vagrant/proxy/block-exp /etc/squid/


echo "------ FIN ------"