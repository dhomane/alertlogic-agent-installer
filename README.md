# Alert Logic Installer Scripts

# Linux

``` 
curl -sSL https://raw.githubusercontent.com/dhomane/alertlogic-agent-installer/main/linux-install.sh | bash -x 
```

# Windows

```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dhomane/alertlogic-agent-installer/main/windows-install.ps1" -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-Command -ScriptBlock ([ScriptBlock]::Create($scriptContent))
```
