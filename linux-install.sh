#!/bin/bash

agent_rpm_url="https://scc.alertlogic.net/software/al-agent-LATEST-1.x86_64.rpm"

# Download AlertLogic agent RPM
wget -O /tmp/al-agent-LATEST-1.x86_64.rpm "$agent_rpm_url"


# Check if al_agent is installed
if rpm -q al-agent >/dev/null 2>&1; then
  agent_installed=1
else
  agent_installed=0
fi

# Check if rsyslog is installed
if rpm -q rsyslog >/dev/null 2>&1; then
  rsyslog_installed=1
else
  rsyslog_installed=0
fi

# Check if syslog-ng is installed
if rpm -q syslog-ng >/dev/null 2>&1; then
  syslog_ng_installed=1
else
  syslog_ng_installed=0
fi


# Remove existing AlertLogic Agent
yum remove -y al-agent

# Remove existing AlertLogic directory
rm -rf /var/alertlogic

# Check SELinux status

selinux=$(getenforce)

if [ "$selinux" == "Enforcing" ]; then
    semanage port -a -t syslogd_port_t -p tcp 1514
fi

# Installing the Agent
rpm -U /tmp/al-agent-LATEST-1.x86_64.rpm

# Start AlertLogic agent
/etc/init.d/al-agent start

# Check if rsyslog daemon is active
rsyslog_status=$(systemctl is-active rsyslog 2>/dev/null)

# Check if syslog-ng daemon is active
syslog_ng_status=$(systemctl is-active syslog-ng 2>/dev/null)

# Set fact for rsyslog daemon
if [[ "$rsyslog_status" == "active" ]] && [[ "$syslog_ng_status" != "active" ]]; then
  syslog_daemon="rsyslog"
fi

# Set fact for syslog-ng daemon
if [[ "$syslog_ng_status" == "active" ]] && [[ "$rsyslog_status" != "active" ]]; then
  syslog_daemon="syslog-ng"
fi

# Set fact for rsyslog as active daemon when both are active
if [[ "$rsyslog_status" == "active" ]] && [[ "$syslog_ng_status" == "active" ]]; then
  syslog_daemon="rsyslog"
fi


# Install rsyslog is no logging daemon present
if [[ $syslog_ng_installed == 0 ]] && [[ $rsyslog_installed == 0 ]]; then
  yum install -y rsyslog
  sudo systemctl enable --now rsyslog
  syslog_daemon="rsyslog"
fi

# Print the active syslog daemon
echo "Active syslog daemon: $syslog_daemon"

# Add setting in rsyslog.conf
if [[ "$syslog_daemon" == "rsyslog" ]]; then
  if ! grep -q "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" /etc/rsyslog.conf; then
    if sudo systemctl stop rsyslog && echo "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" >> /etc/rsyslog.conf && sudo systemctl start rsyslog; then
      echo "rsyslog settings added and restarted successfully."
    else
      echo "Error adding rsyslog settings."
      exit 1
    fi
  else
    echo "rsyslog settings already present in /etc/rsyslog.conf. Skipping addition."
  fi
fi

# Add settings in syslog-ng.conf
if [[ "$syslog_daemon" == "syslog-ng" ]]; then
  if ! grep -q "destination d_alertlogic {tcp(\"localhost\" port(1514));};" /etc/syslog-ng/syslog-ng.conf || 
       ! grep -q "log { source(s_sys); destination(d_alertlogic); };" /etc/syslog-ng/syslog-ng.conf; then
    if echo 'destination d_alertlogic {tcp("localhost" port(1514));};' | tee -a /etc/syslog-ng/syslog-ng.conf &&
       echo 'log { source(s_sys); destination(d_alertlogic); };' | tee -a /etc/syslog-ng/syslog-ng.conf &&
       systemctl restart syslog-ng; then
      echo "syslog-ng settings added and restarted successfully."
    else
      echo "Error adding syslog-ng settings."
      exit 1
    fi
  else
    echo "syslog-ng settings already present in /etc/syslog-ng/syslog-ng.conf. Skipping addition."
  fi
fi


# Delete al-agent rpm file from tmp
rm -f /tmp/al-agent-LATEST-1.x86_64.rpm


# Restart AlertLogic agent
/etc/init.d/al-agent restart


# Restart the active syslog daemon
if [[ "$syslog_daemon" == "rsyslog" ]]; then
  sudo systemctl stop rsyslog ; sleep 2 ; sudo systemctl start rsyslog
  echo "rsyslog daemon restarted successfully."
elif [[ "$syslog_daemon" == "syslog-ng" ]]; then
  sudo systemctl stop syslog-ng ; sleep 2 ; sudo systemctl start syslog-ng
  echo "syslog-ng daemon restarted successfully."
fi


# Restart the active syslog daemon
if [[ "$syslog_daemon" == "rsyslog" ]]; then
  sudo systemctl stop rsyslog ; sleep 10 ; sudo systemctl start rsyslog ; sudo systemctl status rsyslog --no-pager
  echo "rsyslog daemon restarted successfully."
elif [[ "$syslog_daemon" == "syslog-ng" ]]; then
  sudo systemctl stop syslog-ng ; sleep 10 ; sudo systemctl start syslog-ng ; sudo systemctl status syslog-ng --no-pager
  echo "syslog-ng daemon restarted successfully."
fi




# Display status
/etc/init.d/al-agent status






