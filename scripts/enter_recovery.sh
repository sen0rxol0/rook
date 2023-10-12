#!/usr/bin/env bash
idevicepair pair
idevicediagnostics -u $(ideviceinfo -k UniqueDeviceID) restart
ideviceinfo
