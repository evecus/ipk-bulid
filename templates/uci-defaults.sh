#!/bin/sh
/etc/init.d/{{SERVICE_NAME}} enable
/etc/init.d/{{SERVICE_NAME}} start
sleep 1
/etc/init.d/rpcd reload
exit 0
