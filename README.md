# Zabbix agent install scripts

This scripts created for zabbix agent installation automation. Created for Zabbix 3.4.

List of scripts: \
├── _temp_zagent_install-centos.sh \
├── _temp_zagent_install_debian.sh \
└── zagent_install_ubuntu16.sh \

Scripts which names starting with "temp" aren't ready yet.

## Ubuntu16

zagent_install_ubuntu16.sh - created for ubuntu 16.04 server and tested with it.

### How to use it

Please run it: ```bash *scriptname* zabbix_server-address (fqdn or ip)```

Example:

```
vagrant@ubuntu-1:/vagrant$ sudo -s
root@ubuntu-1:/vagrant# bash zagent_install_ubuntu16.sh zabbix.mynet.local
Zabbix agent will be configured working with [zabbix.mynet.local] zabbix server

Starting...
 * [Zabbix agent installation] - Done!
 * [Generating crypto keys] - Done!
 * [Creating new config] - Done!
 * [Installing sysstat package] - Done!
 * [Download zabbix config for disk stat] - Done!
 * [Download script for disk stat] - Done!
 * [Configuring script for disk stat] - Done!
 * [Creating config for apt monitoring] - Done!
 * [Creating config for mysql monitoring] - Done!
 * [Creating config for veeam backup monitoring] - Done!
 * [Staring zabbix-agent] - Done!
########################################## 
Zabbix agent installed.
Zabbix agent has status: (running) 
########################################## 
Configuration data:
Hostname: ubuntu-1
IP: 10.0.2.15
PSK ID: fc423bd826
PSK Key: 50d602f9a1c38077164cc72235349d39fd44ebde8dd90d138389a6794dcf729d
########################################## 
Copy and use this data to configure host monitoring on Zabbix server
root@ubuntu-1:/vagrant# 

```