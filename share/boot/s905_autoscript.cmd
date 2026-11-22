echo "ArmbianDesk: probing USB / SD / eMMC for mainline chainload or kernel"
if fatload usb 0:1 0x01000000 u-boot.ext; then
    echo "ArmbianDesk: starting u-boot.ext from usb 0:1"
    go 0x01000000
fi
if fatload mmc 0:1 0x01000000 u-boot.ext; then
    echo "ArmbianDesk: starting u-boot.ext from mmc 0:1"
    go 0x01000000
fi
