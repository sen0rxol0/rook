#!/usr/bin/env bash
sleep 2
irecovery -c "setenv auto-boot true"
irecovery -c "saveenv"
irecovery -c "reboot"
exit
