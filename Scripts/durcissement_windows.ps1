# Script pour appliquer le durcissement de sécurité sur Windows Server
# À exécuter avec des privilèges d'administrateur

Write-Host "===== Application du durcissement de sécurité pour Windows Server =====" -ForegroundColor Green

# Vérifier si le script s'exécute en tant qu'administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "Ce script doit être exécuté en tant qu'administrateur!" -ForegroundColor Red
    exit 1
}

# 1. Configurer les politiques de mot de passe
Write-Host "1. Configuration des politiques de mot de passe..." -ForegroundColor Cyan
net accounts /minpwlen:12 /maxpwage:60 /minpwage:1 /uniquepw:5 /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:30

# 2. Désactiver les comptes invités et administrateur par défaut
Write-Host "2. Désactivation des comptes par défaut..." -ForegroundColor Cyan
net user Guest /active:no
net user Administrator /active:no

# 3. Activer le pare-feu Windows
Write-Host "3. Activation du pare-feu Windows..." -ForegroundColor Cyan
netsh advfirewall set allprofiles state on
# Bloquer les connexions entrantes par défaut
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

# 4. Désactiver SMBv1 (vulnérable)
Write-Host "4. Désactivation de SMBv1..." -ForegroundColor Cyan
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# 5. Configurer l'audit de sécurité
Write-Host "5. Configuration de l'audit de sécurité..." -ForegroundColor Cyan
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /category:"System" /success:enable /failure:enable

# 6. Sécuriser RDP (si activé)
Write-Host "6. Sécurisation de RDP..." -ForegroundColor Cyan
$rdpStatus = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections").fDenyTSConnections
if ($rdpStatus -eq 0) {
    # RDP est activé, sécurisons-le
    # Activer l'authentification NLA (Network Level Authentication)
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value 2
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
    # Limiter les connexions RDP aux administrateurs
    $rdpGrp = "Remote Desktop Users"
    net localgroup "$rdpGrp" /delete 2>$null
    net localgroup "$rdpGrp" /add
    Write-Host "RDP sécurisé. Utilisez 'net localgroup "$rdpGrp" username /add' pour autoriser des utilisateurs spécifiques à se connecter via RDP." -ForegroundColor Yellow
} else {
    Write-Host "RDP est désactivé (OK)" -ForegroundColor Green
}

# 7. Désactiver les services inutiles
Write-Host "7. Désactivation des services inutiles..." -ForegroundColor Cyan
$servicesToDisable = @(
    "PushToInstall", # Service Windows Store
    "RemoteRegistry", # Registre à distance
    "SharedAccess", # Partage de connexion Internet
    "SNMPTRAP", # SNMP Trap (si non utilisé)
    "TlntSvr", # Telnet (service obsolète)
    "SSDPSRV", # Universal Plug and Play
    "upnphost", # Universal Plug and Play
    "WMPNetworkSvc", # Windows Media Player Network Sharing
    "XblAuthManager", # Xbox Live Auth Manager
    "XblGameSave", # Xbox Live Game Save
    "XboxNetApiSvc" # Xbox Live Networking
)

foreach ($service in $servicesToDisable) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc -ne $null) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "Service désactivé: $service" -ForegroundColor Yellow
    }
}

# 8. Durcir la configuration du registre
Write-Host "8. Durcissement des paramètres de registre..." -ForegroundColor Cyan

# Désactiver l'auto-login
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0" -Type String

# Activer UAC
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value "1" -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value "2" -Type DWord

# 9. Activer Windows Defender
Write-Host "9. Configuration de Windows Defender..." -ForegroundColor Cyan
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableIOAVProtection $false
Set-MpPreference -DisableBehaviorMonitoring $false
Set-MpPreference -DisableScriptScanning $false
Set-MpPreference -SubmitSamplesConsent 1

# 10. Limiter les droits utilisateurs
Write-Host "10. Limitation des droits utilisateurs..." -ForegroundColor Cyan
# Désactiver l'exécution de PowerShell pour les utilisateurs standards
$path = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds"
Set-ItemProperty -Path $path -Name "ExecutionPolicy" -Value "RemoteSigned"

Write-Host "===== Durcissement de sécurité terminé =====" -ForegroundColor Green
Write-Host "Un redémarrage est recommandé pour appliquer tous les changements." -ForegroundColor Yellow
