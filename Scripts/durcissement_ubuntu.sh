#!/bin/bash
# Script pour appliquer le durcissement de sécurité sur Ubuntu Server

echo -e "\e[1;32m===== Application du durcissement de sécurité pour Ubuntu Server =====\e[0m"

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31mCe script doit être exécuté en tant que root!\e[0m"
  echo "Utilisez: sudo $0"
  exit 1
fi

# 1. Mettre à jour le système
echo -e "\e[1;36m1. Mise à jour du système...\e[0m"
apt update
apt upgrade -y

# 2. Installer les outils de sécurité essentiels
echo -e "\e[1;36m2. Installation des outils de sécurité...\e[0m"
apt install -y fail2ban ufw rkhunter lynis unattended-upgrades apt-listchanges

# 3. Configurer le pare-feu UFW
echo -e "\e[1;36m3. Configuration du pare-feu UFW...\e[0m"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
# Ne pas activer le pare-feu automatiquement, car cela risque de couper la connexion SSH
echo -e "\e[1;33mPour activer le pare-feu UFW, exécutez: sudo ufw enable\e[0m"

# 4. Configurer SSH de manière sécurisée
echo -e "\e[1;36m4. Sécurisation de SSH...\e[0m"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config
systemctl restart ssh

# 5. Configurer fail2ban pour SSH
echo -e "\e[1;36m5. Configuration de fail2ban...\e[0m"
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
systemctl restart fail2ban

# 6. Configurer les mises à jour automatiques
echo -e "\e[1;36m6. Configuration des mises à jour automatiques...\e[0m"
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# 7. Durcir la configuration du système
echo -e "\e[1;36m7. Durcissement de la configuration système...\e[0m"
cat > /etc/sysctl.d/99-security.conf << EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
EOF
sysctl -p /etc/sysctl.d/99-security.conf

# 8. Limiter l'accès SSH à certains utilisateurs (option)
echo -e "\e[1;36m8. Configuration des utilisateurs autorisés pour SSH...\e[0m"
read -p "Voulez-vous limiter l'accès SSH à certains utilisateurs? (o/n): " response
if [ "$response" = "o" ]; then
    read -p "Entrez les noms d'utilisateurs autorisés (séparés par des espaces): " users
    echo "AllowUsers $users" >> /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Accès SSH limité aux utilisateurs: $users"
fi

# 9. Durcir les permissions des fichiers
echo -e "\e[1;36m9. Durcissement des permissions des fichiers...\e[0m"
chmod 640 /etc/shadow
chmod 644 /etc/passwd
chmod 600 /boot/grub/grub.cfg

# 10. Configuration d'auditd pour la journalisation avancée
echo -e "\e[1;36m10. Configuration d'auditd...\e[0m"
apt install -y auditd
cat > /etc/audit/rules.d/audit.rules << EOF
# Monitorer les appels système
-a always,exit -F arch=b64 -S execve -k exec

# Surveiller les modifications des fichiers de configuration
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Surveiller le chargement/déchargement des modules
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
EOF

systemctl restart auditd

echo -e "\e[1;32m===== Durcissement de sécurité terminé =====\e[0m"
echo -e "\e[1;33mUn redémarrage est recommandé pour appliquer tous les changements.\e[0m"
echo -e "\e[1;33mExécutez 'sudo lynis audit system' pour une analyse complète de sécurité.\e[0m"
