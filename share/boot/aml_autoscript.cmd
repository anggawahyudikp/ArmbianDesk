echo "ArmbianDesk: starting USB / SD autoscript chain"
setenv boot_start "booti"
if test "X${devtype}" = "X"; then setenv devtype "usb"; fi
if fatload usb 0:1 0x01020000 s905_autoscript; then autoscr 0x01020000; fi
if fatload mmc 0:1 0x01020000 s905_autoscript; then autoscr 0x01020000; fi
