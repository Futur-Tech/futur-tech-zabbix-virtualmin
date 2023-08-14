#!/usr/bin/env bash

source "$(dirname "$0")/ft-util/ft_util_inc_func"
source "$(dirname "$0")/ft-util/ft_util_inc_var"
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
enforce_security exec "$bin_dir"

echo "
  SETUP VIRTUALMIN
------------------------------------------"

# Run webmin command
function run_webmin_cmd_log() {
  $@ 2>&1 | $S_LOG -s debug -d "$S_NAME|[${*}]" -i
  local exit_code=${PIPESTATUS[0]}
  if [ $exit_code -eq 0 ] || [ $exit_code -eq 1 ]; then
    # Exit Codes:
    # 0 on successfully replacing a config variable
    # 1 on successfully adding a new config variable (the specified option did
    # not already exist in the file, and was added)
    # >1 on error

    $S_LOG -d "$S_NAME" "[${*}] successful"
  else
    $S_LOG -s crit -d "$S_NAME" "[${*}] failed with EXIT_CODE=${exit_code}"
    exit $exit_code
  fi
}

# Use pfSense ACME generated certificate (or self signed if not deployed yet)
letsencrypt="/etc/ssl/pfsense-acme/letsencrypt.all.pem"

if [ -e "$letsencrypt" ]; then
  run_webmin_cmd_log webmin set-config --option keyfile --value /etc/ssl/pfsense-acme/letsencrypt.all.pem
  run_webmin_cmd_log webmin set-config --option certfile --value \"\"
fi

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
