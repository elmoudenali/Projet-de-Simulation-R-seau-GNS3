#!/bin/bash
# Configuration d'un serveur proxy Squid sur Ubuntu Server dans la DMZ

echo "Installation de Squid Proxy..."
apt update
apt install -y squid apache2-utils

echo "Configuration de base de Squid..."
# Sauvegarde du fichier de configuration par défaut
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Création d'un nouveau fichier de configuration
cat > /etc/squid/squid.conf << EOF
# Configuration Squid pour la DMZ

# Port d'écoute standard (3128)
http_port 3128

# Nom du serveur proxy
visible_hostname proxy.dmz.local

# Définition des ACLs
acl localnet src 192.168.10.0/24  # VLAN 10
acl localnet src 192.168.20.0/24  # VLAN 20
acl localnet src 10.0.0.0/24      # DMZ

# Ports standard
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # ports non réservés
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http

# Règles d'accès
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager

# Règle pour autoriser l'accès au réseau local
http_access allow localnet
http_access allow localhost

# Règle par défaut - Tout refuser
http_access deny all

# Paramètres de cache
cache_dir ufs /var/spool/squid 1000 16 256
coredump_dir /var/spool/squid

# Logs
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log /var/log/squid/store.log

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOF

# Création d'un répertoire de cache
echo "Initialisation du répertoire de cache..."
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid

# Redémarrage de Squid pour appliquer la configuration
echo "Redémarrage du service Squid..."
systemctl restart squid
systemctl enable squid

# Configuration du pare-feu pour autoriser le trafic Squid
echo "Configuration du pare-feu..."
ufw allow 3128/tcp
ufw status

echo "Configuration des logs..."
# Rotation des logs
cat > /etc/logrotate.d/squid << EOF
/var/log/squid/*.log {
    weekly
    rotate 5
    compress
    delaycompress
    notifempty
    missingok
    create 640 proxy proxy
    sharedscripts
    postrotate
        test ! -e /var/run/squid.pid || systemctl reload squid
    endscript
}
EOF

echo "Création d'un script de suivi des statistiques..."
cat > /usr/local/bin/squid_stats.sh << EOF
#!/bin/bash
echo "=== Statistiques Squid ==="
echo "Top 10 des sites visités:"
cat /var/log/squid/access.log | awk '{print \$7}' | sort | uniq -c | sort -nr | head -10

echo ""
echo "Top 10 des utilisateurs (par IP):"
cat /var/log/squid/access.log | awk '{print \$3}' | sort | uniq -c | sort -nr | head -10
EOF
chmod +x /usr/local/bin/squid_stats.sh

echo "Installation terminée! Le proxy Squid est configuré sur 10.0.0.3:3128"
