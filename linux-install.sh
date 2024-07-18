#!/bin/bash

AGENT_RPM_URL="https://scc.alertlogic.net/software/al-agent-LATEST-1.x86_64.rpm"
AGENT_RPM_DEST="/tmp/al-agent-LATEST-1.x86_64.rpm"
MIN_VERSION="2.20"

check_agent_installed() {
  rpm -qa | grep al-agent
}

check_agent_running() {
  /etc/init.d/al-agent status
}

get_agent_version() {
  rpm -qi al-agent | grep Version | awk '{print $3}'
}

install_rsyslog() {
  sudo yum install -y rsyslog
  sudo systemctl enable --now rsyslog
}

download_agent() {
  curl -o "${AGENT_RPM_DEST}" "${AGENT_RPM_URL}"
}

remove_existing_agent() {
  sudo yum remove -y al-agent
  sudo rm -rf /var/alertlogic
}

install_agent() {
  sudo yum install -y "${AGENT_RPM_DEST}"
}

check_selinux_status() {
  getenforce
}

set_selinux_port() {
  sudo semanage port -a -t syslogd_port_t -p tcp 1514
}

start_agent() {
  sudo /etc/init.d/al-agent start
}

check_syslog_status() {
  systemctl is-active rsyslog
}

check_syslog_ng_status() {
  systemctl is-active syslog-ng
}

configure_rsyslog() {
  sudo sed -i '/^\*.\* @@127.0.0.1:1514;RSYSLOG_FileFormat/d' /etc/rsyslog.conf
  echo "*.* @@127.0.0.1:1514;RSYSLOG_FileFormat" | sudo tee -a /etc/rsyslog.conf
  sudo systemctl restart rsyslog
}

configure_syslog_ng() {
  sudo sed -i '/destination d_alertlogic {tcp("localhost" port(1514));};/d' /etc/syslog-ng/syslog-ng.conf
  sudo sed -i '/log { source(s_sys); destination(d_alertlogic); };/d' /etc/syslog-ng/syslog-ng.conf
  echo 'destination d_alertlogic {tcp("localhost" port(1514));};' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  echo 'log { source(s_sys); destination(d_alertlogic); };' | sudo tee -a /etc/syslog-ng/syslog-ng.conf
  sudo systemctl restart syslog-ng
}

cleanup_agent_rpm() {
  rm -f "${AGENT_RPM_DEST}"
}

display_status() {
  if [ -z "$(check_agent_installed)" ]; then
    echo "AlertLogic Agent is NOT Installed"
  else
    echo "AlertLogic Agent is Installed"
    if [ -z "$(check_agent_running)" ]; then
      echo "AlertLogic Agent is NOT Running"
    else
      echo "AlertLogic Agent is Running"
    fi
  fi
}

main() {
  AGENT_INSTALLED=$(check_agent_installed)
  if [ -n "${AGENT_INSTALLED}" ]; then
    AGENT_RUNNING=$(check_agent_running)
    AGENT_VERSION=$(get_agent_version)
    if [ -n "${AGENT_RUNNING}" ] && [ "$(printf '%s\n' "$MIN_VERSION" "$AGENT_VERSION" | sort -V | head -n1)" == "$MIN_VERSION" ]; then
      echo "AlertLogic Agent is installed, running, and above version ${MIN_VERSION}"
      exit 0
    fi
  fi

  install_rsyslog
  download_agent
  remove_existing_agent
  install_agent

  SELINUX_STATUS=$(check_selinux_status)
  if [ "${SELINUX_STATUS}" == "Enforcing" ]; then
    set_selinux_port
  fi

  start_agent

  RSYSLOG_STATUS=$(check_syslog_status)
  SYSLOG_NG_STATUS=$(check_syslog_ng_status)
  if [ "${RSYSLOG_STATUS}" == "active" ]; then
    configure_rsyslog
  elif [ "${SYSLOG_NG_STATUS}" == "active" ]; then
    configure_syslog_ng
  fi

  cleanup_agent_rpm
  display_status
}

main
