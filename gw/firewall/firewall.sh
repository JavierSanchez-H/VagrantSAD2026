#!/bin/bash
set -x
#Activar el ip forwarding
sysctl -w net.ipv4.ip_forward=1

#Limpiar reglas previas
iptables -F
iptables -t nat -F
iptables -Z 
iptables -t nat -Z

#AntiLock rule : Permitir el ssh atraves de eth0 para acceder con vagrant
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT

#Politicas por defecto
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

################################
#   Reglas de proteccion local
################################

################################
#   Reglas de preoteccion de red
################################

########### LOgs para depurar
iptables -A INPUT -j LOG --log-prefix "JSL-INPUT"
iptables -A OUTPUT -j LOG --log-prefix "JSL-OUTPUT"
iptables -A FORWARD -j LOG --log-prefix "JSL-FORWARD"