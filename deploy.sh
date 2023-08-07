#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_func"
source "$(dirname "$0")/ft-util/ft_util_inc_var"

app_name="futur-tech-zabbix-virtualmin"
required_pkg_arr=("at" "jq")

bin_dir="/usr/local/bin/${app_name}"
src_dir="/usr/local/src/${app_name}"
sudoers_etc="/etc/sudoers.d/${app_name}"

# Checking which Zabbix Agent is detected and adjust include directory
$(which zabbix_agent2 >/dev/null) && ZBX_CONF_AGENT_D="/etc/zabbix/zabbix_agent2.d"
$(which zabbix_agentd >/dev/null) && ZBX_CONF_AGENT_D="/etc/zabbix/zabbix_agentd.conf.d"
if [ ! -d "${ZBX_CONF_AGENT_D}" ]; then
  $S_LOG -s crit -d $S_NAME "${ZBX_CONF_AGENT_D} Zabbix Include directory not found"
  exit 10
fi

$S_LOG -d $S_NAME "Start $S_DIR_NAME/$S_NAME $*"

echo "
  INSTALL NEEDED PACKAGES & FILES
------------------------------------------"

$S_DIR_PATH/ft-util/ft_util_pkg -u -i ${required_pkg_arr[@]} || exit 1

if [ ! -d "${bin_dir}" ]; then
  run_cmd_log mkdir "${bin_dir}"
fi

$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/bin/" "${bin_dir}"
$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.zabbix/${app_name}.conf" "${ZBX_CONF_AGENT_D}/${app_name}.conf"

echo "
  SETUP VIRTUALMIN
------------------------------------------"

# Define the path to the Let's Encrypt SSL certificate
letsencrypt="/etc/ssl/pfsense-acme/letsencrypt.all.pem"

if [ -e "$letsencrypt" ]; then
  run_cmd_log webmin set-config --option keyfile --value /etc/ssl/pfsense-acme/letsencrypt.all.pem
  run_cmd_log webmin set-config --option certfile
fi

echo "
  SETUP SUDOERS FILE
------------------------------------------"

$S_LOG -d $S_NAME -d "$sudoers_etc" "==============================="

echo "Defaults:zabbix !requiretty" | sudo EDITOR='tee' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${src_dir}/deploy-update.sh" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${bin_dir}/bkp-discovery.sh" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${bin_dir}/bkp-last.sh *" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${bin_dir}/domain-discovery.sh" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${bin_dir}/domain-check.sh *" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null
echo "zabbix ALL=(ALL) NOPASSWD:${bin_dir}/domain-info.sh *" | sudo EDITOR='tee -a' visudo --file=$sudoers_etc &>/dev/null

cat $sudoers_etc | $S_LOG -d "$S_NAME" -d "$sudoers_etc" -i

$S_LOG -d $S_NAME -d "$sudoers_etc" "==============================="

echo "
  RESTART ZABBIX LATER
------------------------------------------"

echo "systemctl restart zabbix-agent*" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
$S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"

$S_LOG -d "$S_NAME" "End $S_NAME"

exit
