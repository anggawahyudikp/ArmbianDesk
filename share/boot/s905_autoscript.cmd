echo "ArmbianDesk: probing USB (ports 0-3) / SD for mainline chainload"
for usbdev in 0 1 2 3; do
    if fatload usb ${usbdev}:1 0x01000000 u-boot.ext; then
        echo "ArmbianDesk: starting u-boot.ext from usb ${usbdev}:1"
        go 0x01000000
    fi
done
if fatload mmc 0:1 0x01000000 u-boot.ext; then
    echo "ArmbianDesk: starting u-boot.ext from mmc 0:1"
    go 0x01000000
fi
