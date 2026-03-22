#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
STOP=10

CONF="{{SERVICE_NAME}}"
PROG="{{BINARY}}"

{{ENV_VARS_HANDLER}}start_service() {
    config_load "$CONF"

    local enabled
    config_get_bool enabled main enabled 0
    [ "$enabled" = "0" ] && return 0

    [ ! -x "$PROG" ] && logger -t {{SERVICE_NAME}} "binary not found: $PROG" && return 1

{{CONFIG_GETS}}
    procd_open_instance
    procd_set_param command "$PROG"{{START_ARGS_PROCD}}
{{WORK_DIR_PROCD}}{{ENV_VARS_PROCD}}    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    return 0
}

service_triggers() {
    procd_add_reload_trigger "$CONF"
}
