#!/usr/bin/env bash
# Somehow device has to be spammed !
# spamming `ideviceinfo` makes the restart process
# with device connected it will enter recovery mode
# device does not enter recovery mode with `ideviceenterrecovery`
idevicepair pair
idevicediagnostics -u $(ideviceinfo -k UniqueDeviceID) restart
ideviceinfo
