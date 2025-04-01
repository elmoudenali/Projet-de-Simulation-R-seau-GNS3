# Configuration complète du serveur Windows DMZ

# 1. Configuration IP statique
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.0.2 -PrefixLength 24 -DefaultGateway 10.0.0.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8

# 2. Installation IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# 3. Création d'un certificat HTTPS
$cert = New-SelfSignedCertificate -DnsName "serverdmz.local" -CertStoreLocation "cert:\LocalMachine\My"
$thumbprint = $cert.Thumbprint
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
$binding = Get-WebBinding -Name "Default Web Site" -Protocol "https"
$binding.AddSslCertificate($thumbprint, "my")

# 4. Création d'une page web
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Serveur DMZ Windows</title>
</head>
<body>
    <h1>Serveur Windows DMZ</h1>
    <p>Ce serveur Windows est correctement configuré dans la DMZ.</p>
    <p>Adresse IP: 10.0.0.2</p>
    <p>Services actifs: HTTP, HTTPS</p>
</body>
</html>
"@
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $htmlContent

# 5. Installation OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# 6. Configuration du pare-feu
New-NetFirewallRule -Name "Allow-ICMP" -DisplayName "Allow ICMP" -Protocol ICMPv4 -IcmpType 8 -Enabled True -Direction Inbound -Action Allow
New-NetFirewallRule -Name "Allow-SSH" -DisplayName "Allow SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
New-NetFirewallRule -Name "Allow-HTTP" -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -Name "Allow-HTTPS" -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

# 7. Création d'un utilisateur admin
$securePassword = ConvertTo-SecureString "Password123" -AsPlainText -Force
New-LocalUser -Name "admin" -Password $securePassword -FullName "Administrator" -Description "Compte administrateur"
Add-LocalGroupMember -Group "Administrators" -Member "admin"

Write-Host "Configuration du serveur Windows DMZ terminée."
