# Download and Install Alert Logic Agent MSI

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Temporarily disable Windows Proxy

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0

# Define path variables
$agentUrl = "https://scc.alertlogic.net/software/al_agent-LATEST.msi"
$agentMsiPath = "C:\al_agent-LATEST.msi"

# Stop the Alert Logic agent
Stop-Service -Name al_agent -ErrorAction SilentlyContinue

# Remove the stale Alertlogic files
Remove-Item -Path "C:\Program Files (x86)\Common Files\AlertLogic" -Recurse -Force -ErrorAction SilentlyContinue

# Uninstall the Agent
wmic product where "name='AL Agent'" call uninstall /nointeractive

# Download latest Alert Logic Agent MSI
Invoke-WebRequest -Uri $agentUrl -OutFile $agentMsiPath

# Install latest Alert Logic agent
Start-Process msiexec -ArgumentList "/i $agentMsiPath install_only=1 /q REBOOT=ReallySuppress" -Wait

# Set Alert Logic Agent service to start automatically
Set-Service -Name al_agent -StartupType Automatic

# Start Alert Logic Agent service
Start-Service -Name al_agent

# Restart Alert Logic Agent service once more to ensure it is running
Restart-Service -Name al_agent

# Get Alert Logic Agent service status
Get-Service -Name al_agent

# Delete Alert Logic Agent MSI file
Remove-Item -Path $agentMsiPath -Force

# Enable Windows Proxy

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1
