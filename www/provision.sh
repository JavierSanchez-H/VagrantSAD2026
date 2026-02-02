#!/bin/sh

echo "########################################"
echo "Aprovisionando WWW"
echo "########################################"

# 1. Limpieza y actualización
apk update
# 2. Instalación de Nginx, OpenSSL y PHP 8.1
# Instalamos php81-fpm (el motor) y php81 (el lenguaje)
apk add nginx openssl php81 php81-fpm php81-opcache php81-gd php81-mysqli php81-curl php81-json nmap nano

# 3. Certificados SSL (Igual que antes)
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt \
  -subj "/C=ES/ST=Almeria/L=Almeria/O=IES_CELIA_VINAS/OU=IT/CN=localhost"

# 4. Configuración de Nginx para soportar PHP
rm -f /etc/nginx/http.d/default.conf

cat <<EOF > /etc/nginx/http.d/servidor_web.conf
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name localhost;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    root /var/www/localhost/htdocs;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Configuración para procesar archivos PHP
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi.conf;
    }
}
EOF

# 5. Configurar PHP-FPM para que escuche correctamente
# Por defecto en Alpine suele venir configurado, pero aseguramos permisos
sed -i 's/user = nobody/user = nginx/g' /etc/php81/php-fpm.d/www.conf
sed -i 's/group = nobody/group = nginx/g' /etc/php81/php-fpm.d/www.conf

# 6. Preparar el directorio web y archivo de prueba PHP
mkdir -p /var/www/localhost/htdocs
cat > /var/www/localhost/htdocs/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Servidor WWW - DMZ</title>
</head>
<body>
    <h1>¡Hola! Estás en el servidor WWW</h1>
    <p>Dirección IP del servidor: <?php echo $_SERVER['SERVER_ADDR']; ?></p>
    <p><a href="info.php">Ver PHP Info</a></p>
</body>
</html>
EOF
echo "<?php phpinfo(); ?>" > /var/www/localhost/htdocs/info.php
chown -R nginx:nginx /var/www/localhost/htdocs

# 7. Iniciar los servicios
rc-update add nginx default
rc-update add php-fpm81 default
rc-service php-fpm81 restart
rc-service nginx restart

echo "------ FIN ------"