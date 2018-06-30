#!/bin/bash
#
### Description: Script for zabbix agent automation installation on ubuntu server.
### This version is Ubuntu server 16.04 compatible.
### Version: 0.2
### Written by: Kirill Kazarin, Russia, SPB, 06-2018 - kazarin.ka@yandex.ru
### Usage: bash *scriptname* zabbix_server-address (fqdn or ip)
#
LOG_FILE="install.log"
ZABBIX_SERVER_ADDR=$1

# intall packet into non interactive mode
export DEBIAN_FRONTEND=noninteractive

## check result of operation
operation_result()
{
  # arguments:
  #   $1 - return code
  #   $2 - action name

  if [ ! "$1" -eq 0 ]; then
    printf " * There was a problem during [%s] \nSee $LOG_FILE for more information!\n" "$2"
    exit 1
  fi
  printf " * [%s] - Done!\n" "$2"
}

## Check that script running with root privileges
if [ "$EUID" -ne 0 ]; then
  printf "Please run as root \n Run 'sudo -s' and after it run 'bash scriptname server_addr'\n"
  exit 1
fi

## Check that user don't forget about server address
if [ "$#" -ne 1 ]; then
    printf "Illegal number of parameters \nDon't forget about Zabbix server address!\n"
    exit 1
  else
    printf "Zabbix agent will be configured working with [%s] zabbix server\n\n" "$ZABBIX_SERVER_ADDR"
fi

## Start installation and configuration
printf "Starting...\n"

## Install zabbix-agent package
wget -q http://repo.zabbix.com/zabbix/3.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.4-1+"$(lsb_release -c | awk '{print $2}')"_all.deb  \
  -O zabbix-install.deb &>> "$LOG_FILE"

dpkg -i zabbix-install.deb &>> "$LOG_FILE" \
  && apt-get update &>> "$LOG_FILE" \
  && apt-get install -y zabbix-agent &>> "$LOG_FILE"

operation_result $? "Zabbix agent installation"

rm -rf zabbix-install.deb &>> "$LOG_FILE"

## Stop agent before configuration change
service zabbix-agent stop &>> "$LOG_FILE"

## Generating crypto keys for secure connection
openssl rand -hex 32 > /etc/zabbix/zabbix_agentd.psk \
  && chown zabbix:zabbix /etc/zabbix/zabbix_agentd.psk \
  && chmod 0500 /etc/zabbix/zabbix_agentd.psk \
  && TLSPSK_ID="$(openssl rand -hex 5)"

operation_result $? "Generating crypto keys"

## Create new config for zabbix agent
mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.original

cat << EOF > /etc/zabbix/zabbix_agentd.conf
# List of comma delimited IP addresses (or hostnames) of ZABBIX servers.
Server=$ZABBIX_SERVER_ADDR

# Server port for sending active checks
#ServerPort=10051

# Unique hostname. Required for active checks.
Hostname=$(hostname)

# Listen port. Default is 10050
ListenPort=10050

# IP address to bind agent
# If missing, bind to all available IPs
ListenIP=$(ifconfig | grep "inet addr" | head -n 1| awk '{print $2}' | cut -d ':' -f 2)

# Number of pre-forked instances of zabbix_agentd.
# Default value is 5
StartAgents=5

# How often refresh list of active checks. 120 seconds by default.
RefreshActiveChecks=120

# Disable active checks. The agent will work in passive mode listening server.
# ServerActive=zabbix.beeonline.pro,zabbix.vpc.beeonline.pro

# Enable remote commands for ZABBIX agent. By default remote commands disabled.
EnableRemoteCommands=1

# Specifies debug level
# 0 - debug is not created
# 1 - critical information
# 2 - error information
# 3 - warnings
# 4 - information (default)
# 5 - for debugging (produces lots of information)
DebugLevel=4

# Name of log file.
# If not set, syslog will be used
LogFile=/var/log/zabbix/zabbix_agentd.log

# Maximum size of log file in MB. Set to 0 to disable automatic log rotation.
LogFileSize=5

# Name of PID file
PidFile=/var/run/zabbix/zabbix_agentd.pid

# Spend no more than Timeout seconds on processing
# Must be between 1 and 30
Timeout=10

# switch on additional configs and user parametrs
Include=/etc/zabbix/zabbix_agentd.d/*.conf

# enale secure connection with server
TLSConnect=psk
TLSAccept=psk
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
TLSPSKIdentity=$TLSPSK_ID
EOF
operation_result $? "Creating new config"

## Add additional monitoring configs

apt-get install -y sysstat &>> "$LOG_FILE"
operation_result $? "Installing sysstat package"

## config for 'disk stat performance'
mkdir -p /etc/zabbix/zabbix_agentd.d/

wget -q https://raw.githubusercontent.com/grundic/zabbix-disk-performance/master/userparameter_diskstats.conf \
  -O /etc/zabbix/zabbix_agentd.d/userparameter_diskstats.conf
operation_result $? "Download zabbix config for disk stat"

wget -q https://raw.githubusercontent.com/grundic/zabbix-disk-performance/master/lld-disks.py \
  -O /usr/local/bin/lld-disks.py
operation_result $? "Download script for disk stat"

chmod +x /usr/local/bin/lld-disks.py && ln -s /usr/bin/python3 /usr/bin/python
operation_result $? "Configuring script for disk stat"

## config for 'apt updates'
cat << 'EOF' > /etc/zabbix/zabbix_agentd.d/userparameter_apt.conf
UserParameter=apt.upgradable, apt update &>/dev/null && apt list --upgradable 2>/dev/null | wc -l
UserParameter=apt.security, apt update &>/dev/null && apt list --upgradable 2>/dev/null | grep -i security | wc -l
EOF
operation_result $? "Creating config for apt monitoring"

## config for mysql
cat << 'EOF' > /etc/zabbix/zabbix_agentd.d/userparameter_mysql.conf
#########################################################
### Set of parameters for monitoring MySQL server (v3.23.42 and later)
### Change -u and add -p if required
UserParameter=mysql.ping[*],mysqladmin -u$1 -p$2  ping 2>/dev/null |grep alive|wc -l
UserParameter=mysql.uptime[*],mysqladmin -u$1 -p$2 status 2>/dev/null |cut -f2 -d":"|cut -f2 -d" "
UserParameter=mysql.threads[*],mysqladmin -u$1 -p$2 status 2>/dev/null |cut -f3 -d":"|cut -f2 -d" "
UserParameter=mysql.questions[*],mysqladmin -u$1 -p$2 status 2>/dev/null |cut -f4 -d":"|cut -f2 -d" "
UserParameter=mysql.slowqueries[*],mysqladmin -u$1 -p$2 status 2>/dev/null |cut -f5 -d":"|cut -f2 -d" "
UserParameter=mysql.qps[*],mysqladmin -u$1 -p$2 status 2>/dev/null |cut -f9 -d":"|cut -f2 -d" "
UserParameter=mysql.version,mysql -V

UserParameter=mysql.status[*],echo "show global status where Variable_name='$1';" | mysql -N -u$2 -p$3 2>/dev/null | awk '{print $$2}'

# Flexible parameter to determine database or table size. On the frontend side, use keys like mysql.size[zabbix,history,data].
# Key syntax is mysql.size[<database>,<table>,<type>].
# Database may be a database name or "all". Default is "all".
# Table may be a table name or "all". Default is "all".
# Type may be "data", "index", "free" or "both". Both is a sum of data and index. Default is "both".
# Database is mandatory if a table is specified. Type may be specified always.
# Returns value in bytes.
# 'sum' on data_length or index_length alone needed when we are getting this information for whole database instead of a single table

UserParameter=mysql.size[*],bash -c 'echo "select sum($(case "$3" in both|"") echo "data_length+index_length";; data|index) echo "$3_length";; free) echo "data_free";; esac)) from information_schema.tables$([[ "$1" = "all" || ! "$1" ]] || echo " where table_schema=\"$1\"")$([[ "$2" = "all" || ! "$2" ]] || echo "and table_name=\"$2\"");" | mysql -N -u$4 -p$5' 2>/dev/nul
EOF
operation_result $? "Creating config for mysql monitoring"

## config for 'Veeam backup' status
cat << 'EOF' > /etc/zabbix/zabbix_agentd.d/userparameter_veeam_backup.conf
UserParameter=veeam_backup_status,veeamconfig session list | awk '{print $4}'| tail -n 2 | head -n 1
EOF
operation_result $? "Creating config for veeam backup monitoring"

# create firewall rule
apt-get install -y iptables-persistent &>> "$LOG_FILE"
operation_result $? "Installing iptables-persistent package"

IPTB_BIN=$(which iptables) &>> "$LOG_FILE"
"$IPTB_BIN" -I INPUT --protocol tcp --source "$ZABBIX_SERVER_ADDR" --dport 10050 --jump ACCEPT &>> "$LOG_FILE" \
  && netfilter-persistent save  &>> "$LOG_FILE"
operation_result $? "Configuring firewall"


## start zabbix agent works
usermod -a -G systemd-journal zabbix &>> "$LOG_FILE" \
  && service zabbix-agent start &>> "$LOG_FILE" \
  && update-rc.d zabbix-agent enable &>> "$LOG_FILE"

operation_result $? "Staring zabbix-agent"


printf "########################################## \n"
printf "Zabbix agent installed.\n"
printf "Zabbix agent has status: %s \n" "$(service zabbix-agent status | grep Active | awk '{print $3}')"
printf "########################################## \n"

printf "Configuration data:\n"
printf "Hostname: "
hostname

printf "IP: "
ifconfig | grep "inet addr" | head -n 1| awk '{print $2}' | cut -d ':' -f 2

printf "PSK ID: "
echo "$TLSPSK_ID"

printf "PSK Key: "
cat /etc/zabbix/zabbix_agentd.psk

printf "########################################## \n"
printf "Copy and use this data to configure host monitoring on Zabbix server\n"

exit 0
