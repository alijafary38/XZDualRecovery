#!/sbin/busybox sh

# Backup original LD_LIBRARY_PATH value to restore it later.
_LDLIBPATH="$LD_LIBRARY_PATH"
# Backup original PATH value to restore later
_PATH="$PATH"

export LD_LIBRARY_PATH=".:/sbin:/system/vendor/lib:/system/lib"
export PATH="/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin"

#https://github.com/android/platform_system_core/commit/e18c0d508a6d8b4376c6f0b8c22600e5aca37f69
#The busybox in all of the recoveries has not yet been patched to take this in account.
/sbin/busybox blockdev --setrw $(/sbin/find /dev/block/platform/msm_sdcc.1/by-num/ -iname "p12")

# Making darn sure sysfs has been mounted, otherwise the LED control will fail.
if [ "$(/sbin/busybox cat /proc/mounts | /sbin/busybox grep 'sysfs' | /sbin/busybox grep '/sys' | /sbin/busybox wc -l)" = "0" ]; then
	/sbin/busybox mount -t sysfs sysfs /sys
fi

SETLED() {
        BRIGHTNESS_LED_RED="/sys/class/leds/red/brightness"
        CURRENT_LED_RED="/sys/class/leds/red/led_current"
        BRIGHTNESS_LED_GREEN="/sys/class/leds/green/brightness"
        CURRENT_LED_GREEN="/sys/class/leds/green/led_current"
        BRIGHTNESS_LED_BLUE="/sys/class/leds/blue/brightness"
        CURRENT_LED_BLUE="/sys/class/leds/blue/led_current"

        if [ "$1" = "on" ]; then

                echo "$2" > ${BRIGHTNESS_LED_RED}
                echo "$3" > ${BRIGHTNESS_LED_GREEN}
                echo "$4" > ${BRIGHTNESS_LED_BLUE}

                if [ -f "$CURRENT_LED_RED" -a -f "$CURRENT_LED_GREEN" -a -f "$CURRENT_LED_BLUE" ]; then

                        echo "$2" > ${CURRENT_LED_RED}
                        echo "$3" > ${CURRENT_LED_GREEN}
                        echo "$4" > ${CURRENT_LED_BLUE}
                fi

        else

                echo "0" > ${BRIGHTNESS_LED_RED}
                echo "0" > ${BRIGHTNESS_LED_GREEN}
                echo "0" > ${BRIGHTNESS_LED_BLUE}

                if [ -f "$CURRENT_LED_RED" -a -f "$CURRENT_LED_GREEN" -a -f "$CURRENT_LED_BLUE" ]; then

                        echo "0" > ${CURRENT_LED_RED}
                        echo "0" > ${CURRENT_LED_GREEN}
                        echo "0" > ${CURRENT_LED_BLUE}
                fi

        fi
}

FLASHLED() {
	SETLED on 255 0 0
	sleep 1
	SETLED off
	sleep 1
	FLASHLED
}

echo "Correcting system time: $(/sbin/busybox date)" >> /tmp/xzdr.log

if [ "$(/sbin/busybox cat /proc/mounts | /sbin/busybox grep '/system' | /sbin/busybox wc -l)" = "0" ]; then
	SYSTEM=$(/sbin/busybox find /dev/block/platform/msm_sdcc.1/by-num/ -iname "p12")
	/sbin/busybox mount -t ext4 -o rw,barrier=1,discard $SYSTEM /system 2>&1 >> /tmp/xzdr.log
fi

if [ "$(/sbin/busybox cat /proc/mounts | /sbin/busybox grep '/data' | /sbin/busybox wc -l)" = "0" ]; then
	USERDATA=$(/sbin/busybox find /dev/block/platform/msm_sdcc.1/by-num/ -iname "p14")
	/sbin/busybox mount -t ext4 -o rw,barrier=1,discard $USERDATA /data 2>&1 >> /tmp/xzdr.log
fi

# Initialize system clock.
if [ "$(getprop persist.sys.timezone)" != "" ]; then

	export TZ=$(getprop persist.sys.timezone)
	echo "Set $(getprop persist.sys.timezone) timezone..." >> /tmp/xzdr.log

else

	export TZ="GMT"
	echo "Set GMT timezone..." >> /tmp/xzdr.log

fi

#if [ "$1" = "time" ]; then

	/sbin/busybox cp /system/bin/time_daemon /sbin/
#	/system/bin/time_daemon &
	/sbin/time_daemon &

#	/sbin/busybox sleep 2

#fi

echo "Corrected system time: $(/sbin/busybox date)" >> /tmp/xzdr.log

echo "Anti-Filesystem-Lock starting." >> /tmp/xzdr.log

for LOCKINGPID in `/sbin/busybox lsof | /sbin/busybox awk '{print $1" "$2}' | /sbin/busybox grep "/bin\|/system\|/data\|/cache" | /sbin/busybox awk '{print $1}'`; do
	BINARY=$(/sbin/busybox cat /proc/${LOCKINGPID}/status | /sbin/busybox grep -i "name" | /sbin/busybox awk -F':\t' '{print $2}')
	if [ "$BINARY" != "" ]; then
		echo "File ${BINARY} is locking a critical partition running as PID ${LOCKINGPID}, killing it now!" >> /tmp/xzdr.log
		/sbin/busybox killall ${BINARY}
	fi
done

/sbin/busybox sleep 2

REMAINING=$(/sbin/busybox lsof | /sbin/busybox awk '{print $1" "$2}' | /sbin/busybox grep "/bin\|/system\|/data\|/cache" | wc -l)
if [ $REMAINING -gt 0 ]; then
	FLASHLED
fi

/sbin/busybox umount /system 2>&1 >> /tmp/xzdr.log
/sbin/busybox umount /data 2>&1 >> /tmp/xzdr.log

echo "Anti-Filesystem-Lock completed." >> /tmp/xzdr.log

# Returning values to their original settings
export LD_LIBRARY_PATH="$_LDLIBPATH"
export PATH="$_PATH"

exit 0
