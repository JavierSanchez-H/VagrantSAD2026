set -x
# Activar el IP forwarding

sysctl -w net.ipv4.ip_forward=1

# Limpiar reglas previas 
iptables -F
iptables -t nat -F
iptables -Z


# ANTI -LOCK RULES : Permitir ssh de la red de  eth0 para acceder a vagrant
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT


# Política por defecto:
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

################################
# Reglas de protección local
################################

#L1. Permitir tráfico de loopback

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

#L2. Ping a cualquier host
iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

#L3. Permitir que me hagan ping desde la LAN Y DMZ
iptables -A INPUT -i eth2 -s 172.1.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i eth3 -s 172.2.9.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o eth2 -s 172.1.9.1 -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o eth3 -s 172.2.9.1 -p icmp --icmp-type echo-reply -j ACCEPT

#L4. Permitir consultas DNS
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT

#L5. Permitir HTTP/HTTPS PARA actualizar y nevegar
iptables -A OUTPUT -o eth0 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#L.5 Permitir acceso ssh para admincpc
iptables -A INPUT -i eth3 -s 172.2.9.10 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth3 -s 172.2.9.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

################################
# Reglas de protección de red
################################


#R1. Se debe hacer NAT del trafico saliente
iptables -t nat -A POSTROUTING -s 172.2.9.0/24 -o eth0 -j MASQUERADE

#R2Permitir acceso desde la WAN a WWW a traves del 80 haciendo part forwarding
iptables -A FORWARD -i eth0 -o eth2 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#R3.a.Usuario de lña LAN pueden acceder a internet por 80 y 443
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.3 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.3 -d 172.2.9.0/24 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.0/24 -d 172.1.9.3 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.3 -d 172.2.9.0/24 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#R3.b. adminpc debe poder acceder por ssh a cualquier maquina de DMZ
iptables -A FORWARD -i eth3 -o eth2 -s 172.2.9.10 -d 172.1.9.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth3 -s 172.1.9.0/24 -d 172.2.9.10 -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

#R5 pERMITIR SALIR TRAFICO DESDE LA DMZ (SOLO HTTTP/HTTPS/DNS/NTP)
                        # Permitir tráfico HTTP desde la DMZ
iptables -A FORWARD -i eth2 -o eth0 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                        # Permitir tráfico HTTPS desde la DMZ
iptables -A FORWARD -i eth2 -o eth0 -p tcp --dport 443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -p tcp --sport 443 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                        # Permitir consultas DNS desde la DMZ
iptables -A FORWARD -i eth2 -o eth0 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -p udp --sport 53 -m conntrack --ctstate ESTABLISHED -j ACCEPT
                        # Permitir tráfico NTP desde la DMZ
iptables -A FORWARD -i eth2 -o eth0 -p udp --dport 123 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth0 -o eth2 -p udp --sport 123 -m conntrack --ctstate ESTABLISHED -j ACCEPT


#R4. Permitir tráfico  desde la LAN
iptables -A FORWARD -i eth3 -o eth0 -s 172.2.9.0/24 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth3 -d 172.2.9.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


#### Logs para depurar ####
iptables -A INPUT -j LOG --log-prefix "JSL-INPUT" 
iptables -A OUTPUT -j LOG --log-prefix "JSL-OUTPUT"
iptables -A FORWARD -j LOG --log-prefix "JSL-FORWARD"ls
