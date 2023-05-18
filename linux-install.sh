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

# Print the active syslog daemon
echo "Active syslog daemon: $syslog_daemon"

# Add setting in rsyslog.conf
if [[ "$syslog_daemon" == "rsyslog" ]] && [[ $agent_installed == 0 ]] ; then
  echo "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" >> /etc/rsyslog.conf
  sudo systemctl restart rsyslog
fi

# Add settings in syslog-ng.conf
if [[ "$syslog_daemon" == "syslog-ng" ]] && [[ $agent_installed == 0 ]] ; then
  echo 'destination d_alertlogic {tcp("localhost" port(1514));};' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  echo 'log { source(s_sys); destination(d_alertlogic); };' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  sudo systemctl restart syslog-ng
fi


# Delete al-agent rpm file from tmp
rm -f /tmp/al-agent-LATEST-1.x86_64.rpm

# Display status

/etc/init.d/al-agent status
