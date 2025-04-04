#!/bin/bash

# URLs for different architectures
AGENT_RPM_X64_URL="https://scc.alertlogic.net/software/al-agent-LATEST-1.x86_64.rpm"
AGENT_RPM_ARM64_URL="https://scc.alertlogic.net/software/al-agent-LATEST-1.aarch64.rpm"
MIN_VERSION="2.20"

# Detect architecture
detect_architecture() {
  arch=$(uname -m)
  if [[ "$arch" == "x86_64" ]]; then
    echo "x86_64"
  elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    echo "aarch64"
  else
    echo "unsupported"
  fi
}

# Get architecture and set appropriate URLs
ARCHITECTURE=$(detect_architecture)
if [ "$ARCHITECTURE" == "unsupported" ]; then
  echo "Error: Unsupported architecture detected. Only x86_64 and arm64/aarch64 are supported."
  exit 1
fi

# Set URLs based on architecture
if [ "$ARCHITECTURE" == "x86_64" ]; then
  AGENT_RPM_URL="${AGENT_RPM_X64_URL}"
  AGENT_RPM_DEST="/tmp/al-agent-LATEST-1.x86_64.rpm"
else
  AGENT_RPM_URL="${AGENT_RPM_ARM64_URL}"
  AGENT_RPM_DEST="/tmp/al-agent-LATEST-1.aarch64.rpm"
fi

check_agent_installed() {
  rpm -qa | grep al-agent
}

check_agent_running() {
  if [ -f "/etc/init.d/al-agent" ]; then
    status_output=$(/etc/init.d/al-agent status 2>/dev/null)
    if [[ "$status_output" == *"al-agent is NOT running."* ]]; then
      echo "Agent is NOT running"
      return 1
    else
      echo "Agent is running"
      return 0
    fi
  else
    echo "Agent not found"
    return 1
  fi
}

get_agent_version() {
  rpm -qi al-agent 2>/dev/null | grep Version | awk '{print $3}'
}

check_rsyslog_running() {
  systemctl is-active rsyslog
}

install_rsyslog() {
  echo "Installing/ensuring rsyslog is available..."
  sudo yum install -y rsyslog
  sudo systemctl enable --now rsyslog
}

download_agent() {
  echo "Downloading AlertLogic agent for $ARCHITECTURE architecture..."
  echo "Using URL: $AGENT_RPM_URL"
  echo "Destination: $AGENT_RPM_DEST"
  
  # Verify the URL is not empty
  if [ -z "$AGENT_RPM_URL" ]; then
    echo "Error: Package URL is empty. Aborting download."
    exit 1
  fi
  
  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$AGENT_RPM_DEST")"
  
  # Download with proper error checking
  if ! curl -L -o "$AGENT_RPM_DEST" "$AGENT_RPM_URL"; then
    echo "Error: Failed to download agent package from $AGENT_RPM_URL"
    exit 1
  fi
  
  # Verify file exists and is not empty
  if [ ! -s "$AGENT_RPM_DEST" ]; then
    echo "Error: Downloaded package is empty or does not exist."
    exit 1
  fi
}

remove_existing_agent() {
  echo "Removing any existing AlertLogic agent..."
  if rpm -q al-agent >/dev/null 2>&1; then
    sudo yum remove -y al-agent
  fi
  sudo rm -rf /var/alertlogic
}

install_agent() {
  echo "Installing AlertLogic agent from $AGENT_RPM_DEST..."
  if [ ! -f "$AGENT_RPM_DEST" ]; then
    echo "Error: Package file not found at $AGENT_RPM_DEST"
    exit 1
  fi
  
  sudo yum install -y "$AGENT_RPM_DEST"
  
  # Check if installation was successful
  if ! rpm -q al-agent >/dev/null 2>&1; then
    echo "Error: Failed to install AlertLogic agent."
    exit 1
  fi
}

check_selinux_status() {
  getenforce
}

set_selinux_port() {
  echo "Setting SELinux port for AlertLogic..."
  sudo yum install -y policycoreutils-python-utils || sudo yum install -y policycoreutils-python
  sudo semanage port -a -t syslogd_port_t -p tcp 1514
}

start_agent() {
  echo "Starting AlertLogic agent..."
  if [ -f "/etc/init.d/al-agent" ]; then
    sudo /etc/init.d/al-agent start
  elif [ -f "/usr/bin/al-agent" ]; then
    sudo /usr/bin/al-agent start
  else
    echo "Error: AlertLogic agent startup script not found."
    return 1
  fi
}

check_syslog_ng_status() {
  systemctl is-active syslog-ng
}

configure_rsyslog() {
  echo "Configuring rsyslog for AlertLogic..."
  sudo sed -i '/^\*.\* @@127.0.0.1:1514;RSYSLOG_FileFormat/d' /etc/rsyslog.conf
  echo "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" | sudo tee -a /etc/rsyslog.conf
}

configure_syslog_ng() {
  echo "Configuring syslog-ng for AlertLogic..."
  sudo sed -i '/destination d_alertlogic {tcp("localhost" port(1514));};/d' /etc/syslog-ng/syslog-ng.conf
  sudo sed -i '/log { source(s_sys); destination(d_alertlogic); };/d' /etc/syslog-ng/syslog-ng.conf
  echo 'destination d_alertlogic {tcp("localhost" port(1514));};' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  echo 'log { source(s_sys); destination(d_alertlogic); };' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  sudo systemctl restart syslog-ng
}

restart_rsyslog() {
  echo "Restarting rsyslog service..."
  sudo systemctl restart rsyslog
}

cleanup_agent_rpm() {
  echo "Cleaning up temporary files..."
  rm -f "$AGENT_RPM_DEST"
}

display_status() {
  echo "------------------------"
  echo "AlertLogic Agent Status:"
  echo "------------------------"
  echo "Architecture: $ARCHITECTURE"
  
  if rpm -q al-agent >/dev/null 2>&1; then
    echo "AlertLogic Agent: INSTALLED"
    VERSION=$(get_agent_version)
    echo "Agent Version: $VERSION"
    
    if [ -f "/etc/init.d/al-agent" ]; then
      STATUS=$(/etc/init.d/al-agent status 2>/dev/null || echo "Status check failed")
      echo "Status: $STATUS"
    else
      echo "Status: Unknown (agent script not found)"
    fi
  else
    echo "AlertLogic Agent: NOT INSTALLED"
  fi
  
  RSYSLOG_STATUS=$(systemctl is-active rsyslog)
  echo "Rsyslog Status: $RSYSLOG_STATUS"
  echo "------------------------"
}

main() {
  echo "Starting AlertLogic Agent installation for $ARCHITECTURE architecture..."
  
  AGENT_INSTALLED=$(check_agent_installed)
  RSYSLOG_STATUS=$(check_rsyslog_running)
  
  if [ -n "${AGENT_INSTALLED}" ]; then
    check_agent_running
    AGENT_RUNNING=$?
    AGENT_VERSION=$(get_agent_version)
    
    if [ $AGENT_RUNNING -eq 0 ] && [ "$(printf '%s\n' "$MIN_VERSION" "$AGENT_VERSION" | sort -V | head -n1)" == "$MIN_VERSION" ] && [ "${RSYSLOG_STATUS}" == "active" ]; then
      echo "AlertLogic Agent is installed, running, and above version ${MIN_VERSION}, and rsyslog is running"
      display_status
      exit 0
    fi
  fi

  # Main installation steps
  install_rsyslog
  download_agent
  remove_existing_agent
  install_agent

  SELINUX_STATUS=$(check_selinux_status)
  if [ "${SELINUX_STATUS}" == "Enforcing" ]; then
    set_selinux_port
  fi

  start_agent

  RSYSLOG_STATUS=$(check_rsyslog_running)
  SYSLOG_NG_STATUS=$(check_syslog_ng_status)
  
  if [ "${RSYSLOG_STATUS}" == "active" ]; then
    configure_rsyslog
    restart_rsyslog
  elif [ "${SYSLOG_NG_STATUS}" == "active" ]; then
    configure_syslog_ng
  fi

  # Final cleanup and status
  cleanup_agent_rpm
  display_status
  
  # Verify final status of the installation
  if rpm -q al-agent >/dev/null 2>&1; then
    echo "AlertLogic Agent installation completed successfully."
  else
    echo "AlertLogic Agent installation failed."
    exit 1
  fi
}

main
