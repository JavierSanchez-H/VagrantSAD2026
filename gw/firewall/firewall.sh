#!/bin/bash
set -x
# Activar el IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Limpiar reglas previas 
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z

# ANTI -LOCK RULES : Permitir ssh de la red de eth0 para acceder a vagrant
iptables -A INPUT  -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT

# Política por defecto:
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

################################
# Reglas de protección local
################################

# L1. Permitir tráfico de loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT

# L2. Ping a cualquier host
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT  -p icmp --icmp-type echo-reply  -j ACCEPT

# L3. Permitir que me hagan ping desde la LAN y DMZ
iptables -A INPUT  -i eth2 -s 172.1.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT  -i eth3 -s 172.2.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o eth2 -s 172.1.9.1   -p icmp --icmp-type echo-reply   -j ACCEPT
iptables -A OUTPUT -o eth3 -s 172.2.9.1   -p icmp --icmp-type echo-reply   -j ACCEPT

# L4. Permitir consultas DNS desde el propio firewall
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW         -j ACCEPT
iptables -A INPUT  -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT

# L5. Permitir HTTP/HTTPS para actualizar y navegar desde el firewall
iptables -A OUTPUT -o eth0 -p tcp --dport 80  -m conntrack --ctstate NEW,ESTABLISHED       -j ACCEPT
iptables -A INPUT  -i eth0 -p tcp --sport 80  -m conntrack --ctstate ESTABLISHED,RELATED   -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED       -j ACCEPT
iptables -A INPUT  -i eth0 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED   -j ACCEPT

# L5 bis. Permitir acceso ssh para adminpc
iptables -A INPUT  -i eth3 -s 172.2.9.10 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A OUTPUT -o eth3 -d 172.2.9.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

################################
# Reglas de protección de red
################################

# R1. NAT del tráfico saliente LAN y DMZ
iptables -t nat -A POSTROUTING -s 172.2.9.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.1.9.0/24 -o eth0 -j MASQUERADE

# R2. Permitir acceso desde la WAN a WWW de la DMZ (port forwarding 80)
iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 80 -j DNAT --to 172.1.9.3:80
iptables -A FORWARD -i eth1 -o eth2 -d 172.1.9.3 -p tcp --dport 80  -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -s 172.1.9.3 -p tcp --sport 80  -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R3.a. Usuarios de la LAN pueden acceder a WWW (80/443) en la DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.3 -p tcp --dport 80  -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.3   -d 172.2.9.0/24 -p tcp --sport 80  -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.3 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.3   -d 172.2.9.0/24 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R3.b. adminpc debe poder acceder por ssh a cualquier máquina de DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.10 -d 172.1.9.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.0/24 -d 172.2.9.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R4.V2. Permitir salir tráfico procedente de la LAN

# R4.V2.1. Tráfico web saliente ha de pasar por el proxy (LAN → DMZ)
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.2 -p tcp --dport 3128 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.2   -d 172.2.9.0/24 -p tcp --sport 3128 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R4.V2.2. DNS directas desde LAN a Internet
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.9.0/24 -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.9.0/24 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.9.0/24 -p tcp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.9.0/24 -p tcp --sport 53 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R4.V2.3. NTP desde LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.9.0/24 -p udp --dport 123 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.9.0/24 -p udp --sport 123 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R4.V2.4. Pings salientes desde LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.9.0/24 -p icmp --icmp-type echo-reply  -j ACCEPT

# R5. Salida de tráfico de la DMZ

# R5.1. Permitir salida de tráfico web desde DMZ
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.2 -p tcp -m multiport --dports 80,443  -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.2 -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R5.2. DNS desde DMZ
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.0/24 -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.0/24 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.0/24 -p tcp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.0/24 -p tcp --sport 53 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R5.3. NTP desde DMZ
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.0/24 -p udp --dport 123 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.0/24 -p udp --sport 123 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R5.4. Pings salientes desde DMZ
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.0/24 -p icmp --icmp-type echo-reply  -j ACCEPT

# P4. Permitir tráfico a LDAP desde DMZ hacia IDP (LAN)
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.0/24 -d 172.2.9.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.2   -d 172.1.9.0/24 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# Regla P4.2.1 Permitir acceso WAN (eth1) a servidor VPN
iptables -A INPUT  -i eth1 -p udp --dport 1194 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A OUTPUT -o eth1 -p udp --sport 1194 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# R4.V2.5.Permitir icmp de tun0 a eth3 viceversa
iptables -A FORWARD -i tun0 -o eth3 -s 172.3.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i eth3 -o tun0 -d 172.3.9.0/24 -p icmp --icmp-type echo-reply  -j ACCEPT

# Permitir que el openvpn en el GW consulte al servidor LDAP (IDP)
iptables -A OUTPUT -o eth3 -d 172.2.9.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A INPUT  -i eth3 -s 172.2.9.2 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# Regla P4.2.2 Permitir acceso de VPN-net a http de la DMZ
iptables -A FORWARD -i tun0 -o eth2 -s 172.3.9.0/24 -d 172.1.9.3 -p tcp -m multiport --dports 80,443  -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o tun0 -s 172.1.9.3   -d 172.3.9.0/24 -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# Regla P4.2.3 Permitir acceso de tun0-net al servidor LDAP de la DMZ
iptables -A FORWARD -i tun0 -o eth3 -s 172.3.9.0/24 -d 172.2.9.2 -p tcp --dport 389 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth3 -o tun0 -s 172.2.9.2   -d 172.3.9.0/24 -p tcp --sport 389 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# Regla P6. Permitir acceso de la LAN al squid de la DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.2 -p tcp --dport 3128 -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.2   -d 172.2.9.0/24 -p tcp --sport 3128 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

# Regla P6.b Permitir acceso del proxy a Internet
iptables -A FORWARD -i eth2 -o eth0 -s 172.1.9.2 -p tcp -m multiport --dports 80,443  -m conntrack --ctstate NEW,ESTABLISHED      -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -d 172.1.9.2 -p tcp -m multiport --sports 80,443 -m conntrack --ctstate ESTABLISHED,RELATED  -j ACCEPT

#### Logs para depurar ####
iptables -A INPUT   -j LOG --log-prefix "JSL-INPUT "
iptables -A OUTPUT  -j LOG --log-prefix "JSL-OUTPUT "
iptables -A FORWARD -j LOG --log-prefix "JSL-FORWARD "
