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
# L1. Permitir trafico de loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

# L2. Permitir a cualquier maquina interna y externa
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# L3. Permitir que me hagan ping desde lan y dmz
iptables -A INPUT -i eth2 -s 172.1.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i eth3 -s 172.2.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o eth2 -s 172.1.9.1 -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o eth3 -s 172.2.9.1 -p icmp --icmp-type echo-reply -j ACCEPT

# sudo tail -f /var/log/kern.log


# L4. Permitir consultas por DNS
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED  -j ACCEPT



################################
#   Reglas de preoteccion de red
################################

########### LOgs para depurar
iptables -A INPUT -j LOG --log-prefix "JSL-INPUT"
iptables -A OUTPUT -j LOG --log-prefix "JSL-OUTPUT"
iptables -A FORWARD -j LOG --log-prefix "JSL-FORWARD"