# Download and Install Alert Logic Agent MSI

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Temporarily disable Windows Proxy

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0

$agent_url = "https://scc.alertlogic.net/software/al_agent-LATEST.msi"
$agent_msi_path = "C:\al_agent-LATEST.msi"

# Download Alert Logic Agent MSI
$download_result = Invoke-WebRequest -Uri $agent_url -OutFile $agent_msi_path -UseBasicParsing

# Install Alert Logic Agent

Start-Process msiexec -ArgumentList "/i $agent_msi_path install_only=1 /q REBOOT=ReallySuppress" -Wait


# Set Alert Logic Agent service to start automatically
Set-Service -Name al_agent -StartupType Automatic

# Start Alert Logic Agent service
Start-Service -Name al_agent

# Delete Alert Logic Agent MSI file from tmp
Remove-Item $agent_msi_path -Force

# Enable Windows Proxy

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 1
