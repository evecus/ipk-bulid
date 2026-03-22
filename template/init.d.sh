#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
STOP=10

start_service() {
    config_load "__SERVICE__"
    local enabled
    config_get_bool enabled config enabled 0
    [ "$enabled" = "0" ] && return 1

    __EXEC_PRE__

    procd_open_instance "__SERVICE__"
    __START_CMD__
    __WORKING_DIR__
    __ENVIRONMENT__
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    __EXEC_POST__
}

service_triggers() {
    procd_add_reload_trigger "__SERVICE__"
}
