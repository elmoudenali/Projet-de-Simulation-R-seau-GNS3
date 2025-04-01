#!/bin/bash
# Configuration complète du serveur Ubuntu DMZ

# 1. Configuration réseau
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      addresses:
        - 10.0.0.3/24
      gateway4: 10.0.0.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply

# 2. Autoriser les pings (ICMP)
echo "net.ipv4.icmp_echo_ignore_all = 0" > /etc/sysctl.d/10-allow-pings.conf
sysctl -p /etc/sysctl.d/10-allow-pings.conf

# 3. Installation des services 
apt update
apt install -y apache2 openssh-server ufw

# 4. Configuration SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# 5. Configuration Apache
a2enmod ssl
a2ensite default-ssl
systemctl restart apache2

# 6. Configuration du pare-feu
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow icmp
ufw --force enable

# 7. Création d'une page web
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Serveur DMZ Ubuntu</title>
</head>
<body>
    <h1>Serveur Ubuntu DMZ</h1>
    <p>Ce serveur Ubuntu est correctement configuré dans la DMZ.</p>
    <p>Adresse IP: 10.0.0.3</p>
    <p>Services actifs: SSH, HTTP, HTTPS</p>
</body>
</html>
EOF

# 8. Création d'un utilisateur admin
useradd -m -s /bin/bash admin
echo "admin:Password123" | chpasswd
usermod -aG sudo admin

echo "Configuration serveur Ubuntu terminée."
