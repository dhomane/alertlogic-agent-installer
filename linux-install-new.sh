#!/bin/bash

set -e  # Exit immediately if a command fails

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

agent_rpm_url="https://scc.alertlogic.net/software/al-agent-LATEST-1.x86_64.rpm"
agent_rpm_file="/tmp/al-agent-LATEST-1.x86_64.rpm"

# Download AlertLogic agent RPM using curl
curl -o "$agent_rpm_file" "$agent_rpm_url"

# Install or upgrade AlertLogic agent
rpm -U "$agent_rpm_file"

# Remove existing AlertLogic Agent
yum remove -y al-agent

# Start AlertLogic agent
/etc/init.d/al-agent start

# Remove existing AlertLogic directory
rm -rf /var/alertlogic

# Check SELinux status and adjust port if necessary
selinux=$(getenforce)
if [ "$selinux" == "Enforcing" ]; then
    semanage port -a -t syslogd_port_t -p tcp 1514
fi

# Install rsyslog or syslog-ng if not installed
if ! rpm -q rsyslog >/dev/null 2>&1 && ! rpm -q syslog-ng >/dev/null 2>&1; then
  yum install -y rsyslog
  systemctl enable --now rsyslog
fi

# Configure rsyslog or syslog-ng to forward logs to AlertLogic if not already configured
if rpm -q rsyslog >/dev/null 2>&1; then
  if ! grep -q "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" /etc/rsyslog.conf; then
    echo -e "\n# AlertLogic config start\n*.* @@127.0.0.1:1514;RSYSLOG_FileFormat\n# AlertLogic config end\n" >> /etc/rsyslog.conf
    systemctl restart rsyslog
  fi
  syslog_daemon="rsyslog"
elif rpm -q syslog-ng >/dev/null 2>&1; then
  if ! grep -q "destination d_alertlogic {tcp(\"localhost\" port(1514));};" /etc/syslog-ng/syslog-ng.conf || 
       ! grep -q "log { source(s_sys); destination(d_alertlogic); };" /etc/syslog-ng/syslog-ng.conf; then
    echo 'destination d_alertlogic {tcp("localhost" port(1514));};' | tee -a /etc/syslog-ng/syslog-ng.conf
    echo 'log { source(s_sys); destination(d_alertlogic); };' | tee -a /etc/syslog-ng/syslog-ng.conf
    systemctl restart syslog-ng
  fi
  syslog_daemon="syslog-ng"
fi

# Display active syslog daemon
echo "Active syslog daemon: $syslog_daemon"

# Remove the AlertLogic agent RPM file
rm -f "$agent_rpm_file"

# Restart AlertLogic agent
/etc/init.d/al-agent restart

# Restart syslog daemon
if [ "$syslog_daemon" == "rsyslog" ]; then
  service rsyslog restart
elif [ "$syslog_daemon" == "syslog-ng" ]; then
  service syslog-ng restart
fi

# Display status of AlertLogic agent
/etc/init.d/al-agent status
