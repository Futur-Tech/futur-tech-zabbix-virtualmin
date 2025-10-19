#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_func"
source "$(dirname "$0")/ft-util/ft_util_inc_var"
source "$(dirname "$0")/ft-util/ft_util_sudoersd"
source "$(dirname "$0")/ft-util/ft_util_usrmgmt"

app_name="futur-tech-zabbix-virtualmin"
required_pkg_arr=("at" "jq")

bin_dir="/usr/local/bin/${app_name}"
src_dir="/usr/local/src/${app_name}"

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

mkdir_if_missing "${bin_dir}"
$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/bin/" "${bin_dir}"
$S_DIR/ft-util/ft_util_file-deploy "$S_DIR/etc.zabbix/${app_name}.conf" "${ZBX_CONF_AGENT_D}/${app_name}.conf"
enforce_security exec "$bin_dir" zabbix

echo "
  SETUP SUDOERS FILE
------------------------------------------"

bak_if_exist "/etc/sudoers.d/${app_name}"
sudoersd_reset_file $app_name zabbix
sudoersd_addto_file $app_name zabbix "${src_dir}/deploy-update.sh"
sudoersd_addto_file $app_name zabbix "${bin_dir}/bkp-discovery.sh"
sudoersd_addto_file $app_name zabbix "${bin_dir}/bkp-last.sh *"
sudoersd_addto_file $app_name zabbix "${bin_dir}/domain-discovery.sh"
sudoersd_addto_file $app_name zabbix "${bin_dir}/domain-check.sh *"
sudoersd_addto_file $app_name zabbix "${bin_dir}/domain-info.sh *"
show_bak_diff_rm "/etc/sudoers.d/${app_name}"

echo "
  RESTART ZABBIX LATER
------------------------------------------"

echo "systemctl restart zabbix-agent*" | at now + 1 min &>/dev/null ## restart zabbix agent with a delay
$S_LOG -s $? -d "$S_NAME" "Scheduling Zabbix Agent Restart"

$S_LOG -d "$S_NAME" "End $S_NAME"

exit
