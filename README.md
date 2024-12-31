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


# Details

This repository contains a Bash and PowerShell script designed to manage the Alert Logic Agent's installation, configuration, and lifecycle on a Linux and Windows machine. For Windows, the script handles scenarios where the agent is already installed and ensures seamless installation of the latest version when required. Additionally, it includes support for a provisioning key (`prov_key`) based on an environment variable.

---

## Features

1. **Service Validation**:
   - Detects if the `al_agent` service is present.
   - Restarts the service if it's running.
   - Exits gracefully if the agent is already installed and running.

2. **Agent Cleanup**:
   - Stops the `al_agent` service.
   - Removes stale files from the previous installations.
   - Uninstalls older versions of the agent.

3. **Installation of Latest Agent**:
   - Downloads the latest MSI installer for the Alert Logic Agent.
   - Installs the agent with or without a provisioning key, based on the `PROV_KEY` environment variable.

4. **Post-Installation Configuration**:
   - Ensures the `al_agent` service is set to start automatically.
   - Restarts the service and verifies its status.

5. **System Proxy Management**:
   - Temporarily disables the Windows proxy during installation.
   - Re-enables the proxy after the process is complete.

6. **Error Handling**:
   - Silently continues operations if non-critical errors occur.

---

## Prerequisites

1. **Windows Operating System**:
   - Ensure the script is run on a supported Windows OS version.

2. **Administrator Privileges**:
   - The script requires administrator privileges to manage services and registry settings.

3. **PowerShell Version**:
   - Requires PowerShell version 5.1 or later.

4. **Environment Variable** (optional):
   - If provisioning is required, set the `PROV_KEY` environment variable with the desired provisioning key.

---

## Script Behavior

### 1. When `al_agent` Service Exists
- Restarts the service.
- Ensures the service is set to start automatically.
- Exits the script.

### 2. When `al_agent` Service Does Not Exist
- **Pre-installation**:
  - Stops any existing agent services.
  - Removes stale files.
  - Uninstalls any existing agent software.

- **Installation**:
  - Downloads the latest version of the Alert Logic Agent MSI.
  - Installs the agent with one of the following commands:
    - **Without Provisioning Key**:
      ```
      Start-Process msiexec -ArgumentList "/i C:\al_agent-LATEST.msi install_only=1 /q REBOOT=ReallySuppress" -Wait
      ```
    - **With Provisioning Key**:
      ```
      Start-Process msiexec -ArgumentList "/i C:\al_agent-LATEST.msi install_only=1 prov_key=<PROV_KEY> /q REBOOT=ReallySuppress" -Wait
      ```

- **Post-installation**:
  - Ensures the agent service is configured to start automatically.
  - Starts and restarts the service.
  - Deletes the MSI installer.

---

## How to Use

### 1. Download the Script
Save the PowerShell script (`InstallAlertLogicAgent.ps1`) to your local machine.

### 2. Set the `PROV_KEY` Environment Variable (if needed)
If a provisioning key is required for installation:

- Open a PowerShell terminal and run:
  ```powershell
  [System.Environment]::SetEnvironmentVariable("PROV_KEY", "<your_prov_key>", [System.EnvironmentVariableTarget]::Machine)
  ```

### 3. Run the Script
Run the script in a PowerShell terminal with administrator privileges:

```powershell
.\InstallAlertLogicAgent.ps1
```

### 4. Verify Installation
After execution, confirm that the `al_agent` service is:

- Installed.
- Running.
- Set to start automatically.

You can check the service status by running:

```powershell
Get-Service -Name al_agent
```

---

## Logging
The script includes optional logging for tracking execution steps. You can append `Write-Output` statements to log specific events to a file:

```powershell
Write-Output "Message" | Out-File "C:\AgentInstallLog.txt" -Append
```

---

## Troubleshooting

1. **Script Fails to Download the MSI File**:
   - Ensure internet connectivity.
   - Verify that the download URL is reachable.

2. **Service Fails to Start**:
   - Check the Windows Event Viewer for detailed logs.
   - Ensure no other applications are conflicting with the agent.

3. **Environment Variable Not Detected**:
   - Confirm the `PROV_KEY` environment variable is set correctly.
   - Restart the PowerShell session after setting the variable.

---

## Script Flow Diagram

```plaintext
[Start Script]
    |
    v
[Check al_agent Service]
    |
    +--[Service Exists]-->
    |       [Restart Service]-->
    |       [Set to Auto-Start]-->
    |       [Exit Script]
    |
    +--[Service Not Found]-->
            [Stop Service if Running]-->
            [Remove Stale Files]-->
            [Uninstall Old Agent]-->
            [Download Latest MSI]-->
            [Install Agent (With/Without PROV_KEY)]-->
            [Set Service to Auto-Start]-->
            [Start Service]-->
            [Delete MSI File]-->
            [Re-enable Proxy]-->
    |
    v
[End Script]
```

---

## License
This script is distributed under the MIT License. See `LICENSE` file for more details.

---

## Contact
For support or inquiries, please contact the administrator or file an issue in this repository.

---

Happy automating! 🚀


