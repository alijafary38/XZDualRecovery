#!/sbin/busybox sh
set +x
_PATH="$PATH"

# Constants
LOGDIR="XZDualRecovery"
PREPLOG="/tmp/boot.log"
XZDRLOG="XZDualRecovery.log"
BUSYBOX="/sbin/busybox"

DRLOG="$PREPLOG"

# Function definitions
# They rely on the busybox setup being complete, do not try to use them before it did.
ECHOL(){
  _TIME=`${BUSYBOX} date +"%H:%M:%S"`
  ${BUSYBOX} echo "${_TIME} >> $*" >> ${DRLOG}
  return 0
}

EXECL(){
  _TIME=`${BUSYBOX} date +"%H:%M:%S"`
  ${BUSYBOX} echo "${_TIME} >> $*" >> ${DRLOG}
  $* >> ${DRLOG} 2>> ${DRLOG}
  _RET=$?
  ${BUSYBOX} echo "${_TIME} >> RET=${_RET}" >> ${DRLOG}
  return ${_RET}
}
BBXECL(){
  _TIME=`${BUSYBOX} date +"%H:%M:%S"`
  ${BUSYBOX} echo "${_TIME} >> $*" >> ${DRLOG}
  ${BUSYBOX} $* >> ${DRLOG} 2>> ${DRLOG}
  _RET=$?
  ${BUSYBOX} echo "${_TIME} >> RET=${_RET}" >> ${DRLOG}
  return ${_RET}
}

MOUNTSDCARD(){
        case $* in
                06|6|0B|b|0C|c|0E|e) BBXECL mount -t vfat /dev/block/mmcblk1p1 /storage/sdcard1; return $?;;
                07|7) BBXECL insmod /system/lib/modules/nls_utf8.ko;
                      BBXECL insmod /system/lib/modules/texfat.ko;
                      BBXECL mount -t texfat /dev/block/mmcblk1p1 /storage/sdcard1;
                      return $?;;
                83) PTYPE=$(${BUSYBOX} blkid /dev/block/mmcblk1p1 | ${BUSYBOX} awk -F' ' '{ print $NF }' | ${BUSYBOX} awk -F'[\"=]' '{ print $3 }');
                    BBXECL mount -t $PTYPE /dev/block/mmcblk1p1 /storage/sdcard1;
                    return $?;;
                 *) return 1;;
        esac
        ECHOL "### MOUNTSDCARD did not run with a parameter!";
        return 1
}

# Set the led on at a specified color, or off.
# Syntax: SETLED on R G B
SETLED() {
        if [ "$1" = "on" ]; then
                ECHOL "Turn on LED R: $2 G: $3 B: $4"
                echo "$2" > ${BOOTREC_LED_RED}
                echo "$3" > ${BOOTREC_LED_GREEN}
                echo "$4" > ${BOOTREC_LED_BLUE}
        else
                ECHOL "Turn off LED"
                echo "0" > ${BOOTREC_LED_RED}
                echo "0" > ${BOOTREC_LED_GREEN}
                echo "0" > ${BOOTREC_LED_BLUE}
        fi
}

# Find the gpio-keys node, to listen on the right input event
gpioKeysSearch() {
        ECHOL "Trying to find the gpio-keys event node."
        for INPUTUEVENT in `find /sys/devices \( -path "*gpio*" -path "*keys*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(grep "DEVNAME=" ${INPUTUEVENT} | sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        ECHOL "Found and will be using /dev/${INPUTDEV}!"
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
}

# Find the power key node, to listen on the right input event
pwrkeySearch() {
        ECHOL "Trying to find the power key event node."
        # pm8xxx (xperia Z and similar)
        for INPUTUEVENT in `find /sys/devices \( -path "*pm8xxx*" -path "*pwrkey*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(grep "DEVNAME=" ${INPUTUEVENT} | sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        ECHOL "Found and will be monitoring /dev/${INPUTDEV}!"
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
        # qpnp_pon (xperia Z1 and similar)
        for INPUTUEVENT in `find $(find /sys/devices/ -name "name" -exec grep -l "qpnp_pon" {} \; | awk -F '/' 'sub(FS $NF,x)') \( -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

                INPUTDEV=$(grep "DEVNAME=" ${INPUTUEVENT} | sed 's/DEVNAME=//')

                if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
                        ECHOL "Found and will be monitoring /dev/${INPUTDEV}!"
                        echo "/dev/${INPUTDEV}"
                        return 0
                fi

        done
}

DRGETPROP() {

        # If it's empty, see if what was requested was a XZDR.prop value!
        VAR="$*"
        PROP=$(${BUSYBOX} grep "$*" ${DRPATH}/XZDR.prop | ${BUSYBOX} awk -F'=' '{ print $NF }')

	if [ "$PROP" = "" ]; then

		# If it still is empty, try to get it from the build.prop
		PROP=$(${BUSYBOX} grep "$VAR" /system/build.prop | ${BUSYBOX} awk -F'=' '{ print $NF }')

	fi

        if [ "$VAR" != "" -a "$PROP" != "" ]; then
                echo $PROP
        else
                echo "null"
        fi

}

DRSETPROP() {

        # We want to set this only if the XZDR.prop file exists...
        if [ ! -f "${DRPATH}/XZDR.prop" ]; then
                return 0
        fi

        PROP=$(DRGETPROP $1)

        if [ "$PROP" != "null" ]; then
                sed -i 's|'$1'=[^ ]*|'$1'='$2'|' ${DRPATH}/XZDR.prop
        else
                echo "$1=$2" >> ${DRPATH}/XZDR.prop
        fi
        return 0

}

# Kickstart the log
${BUSYBOX} date > ${DRLOG}
BBXECL chmod 666 ${DRLOG}

# The start of all we need to do.

ECHOL "DEBUGINFO=Current mounted filesystems:"
BBXECL mount

EXECL cd /
BBXECL blockdev --setrw $(${BUSYBOX} find /dev/block/platform/msm_sdcc.1/by-name/ -iname "system")
if [ "$(${BUSYBOX} mount | ${BUSYBOX} grep system | ${BUSYBOX} wc -l)" = "0" ]; then
	systemmounted="false"
	BBXECL mount -w $(${BUSYBOX} find /dev/block/platform/msm_sdcc.1/by-name/ -iname "system") /system
else
	systemmounted="true"
	BBXECL mount -o remount,rw /system
fi

# create directories and setup the temporary bin path
if [ ! -d "/cache" ]; then
	BBXECL mkdir /cache
	BBXECL chmod 777 /cache
fi
if [ ! -d "/storage/sdcard1" ]; then
	BBXECL mkdir /storage
	BBXECL mkdir /storage/sdcard1
	BBXECL chmod 775 /storage/sdcard1
fi

BBXECL mkdir /drbin
BBXECL chmod 777 /drbin
BBXECL mount -t tmpfs tmpfs /drbin

checkbyeselinux() {

	echo $(${BUSYBOX} lsmod | ${BUSYBOX} grep byeselinux | ${BUSYBOX} awk '{print $1}' | ${BUSYBOX} wc -l)

}

# Part of byeselinux, requisit for Lollipop based firmwares, this should run only once each time system is wiped or reinstalled.
# The test before it is to determine if demolishing SELinux is required to get XZDR to work. If not, the module is of no use to us and will be skipped.
ANDROIDVER=`${BUSYBOX} echo "$(DRGETPROP ro.build.version.release) 5.0.0" | ${BUSYBOX} awk '{if ($2 != "" && $1 >= $2) print "lollipop"; else print "other"}'`
VERREL=$(DRGETPROP ro.build.version.release)
ECHOL "FW DETECTED: $VERREL, $ANDROIDVER"
if [ "$ANDROIDVER" = "lollipop" ]; then

	BBXECL mount -w $(${BUSYBOX} find /dev/block/platform/msm_sdcc.1/by-name/ -iname "userdata") /data

	if [ ! -e "/data/local/byeselinux.ko" -o ! -e "/system/lib/modules/byeselinux.ko" ]; then

		ECHOL "Byeselinux missing on one or more storage locations, repatching and installing now."

		# This should run only once each time system is wiped or reinstalled.
		BBXECL cp /sbin/byeselinux.ko /drbin/byeselinux.ko

		for module in /system/lib/modules/*.ko; do
			EXECL /sbin/modulecrcpatch $module /drbin/byeselinux.ko
		done

		BBXECL insmod /drbin/byeselinux.ko

		if [ "$(checkbyeselinux)" = "1" ]; then

			# making sure system is mounted writable
			BBXECL mount -o remount,rw /system

			if [ ! -e "/system/lib/modules/byeselinux.ko" ]; then

				BBXECL cp /drbin/byeselinux.ko /system/lib/modules/byeselinux.ko
				BBXECL chmod 644 /system/lib/modules/byeselinux.ko

			fi

			if [ ! -e "/data/local/byeselinux.ko" ]; then

				BBXECL cp /drbin/byeselinux.ko /data/local/byeselinux.ko
				BBXECL chmod 644 /data/local/byeselinux.ko

			fi

		fi

	fi

	if [ "$(checkbyeselinux)" = "0" ]; then

		oldmodule="false"

		if [ -e "/system/lib/modules/byeselinux.ko" ]; then
			oldmodule="/system/lib/modules/byeselinux.ko"
		fi

		if [ -e "/data/local/byeselinux.ko" ]; then
			oldmodule="/data/local/byeselinux.ko"
		fi

		if [ "$oldmodule" != "false" ]; then

			BBXECL insmod $oldmodule

		fi

	fi

	BBXECL umount /data

fi

# Attempting to mount the external sdcard.
BOOT=`${BUSYBOX} fdisk -l /dev/block/mmcblk1 | ${BUSYBOX} grep "/dev/block/mmcblk1p1" | ${BUSYBOX} awk '{print $2}'`
if [ "${BOOT}" = "*" ]; then
	FSTYPE=`${BUSYBOX} fdisk -l /dev/block/mmcblk1 | ${BUSYBOX} grep "/dev/block/mmcblk1p1" | ${BUSYBOX} awk '{print $6}'`
	TXTFSTYPE=`${BUSYBOX} fdisk -l /dev/block/mmcblk1 | ${BUSYBOX} grep "/dev/block/mmcblk1p1" | ${BUSYBOX} awk '{for(i=7;i<=NF;++i) printf("%s ", $i)}'`
	ECHOL "### SDCard1 FS found: ${TXTFSTYPE} with code '${FSTYPE}', bootflag was set."
else
	FSTYPE=`${BUSYBOX} fdisk -l /dev/block/mmcblk1 | ${BUSYBOX} grep "/dev/block/mmcblk1p1" | ${BUSYBOX} awk '{print $5}'`
	TXTFSTYPE=`${BUSYBOX} fdisk -l /dev/block/mmcblk1 | ${BUSYBOX} grep "/dev/block/mmcblk1p1" | ${BUSYBOX} awk '{for(i=6;i<=NF;++i) printf("%s ", $i)}'`
	ECHOL "### SDCard1 FS found: ${TXTFSTYPE} with code '${FSTYPE}'."
fi

if [ "$(${BUSYBOX} mount | ${BUSYBOX} grep 'sdcard1' | ${BUSYBOX} wc -l)" = "0" ]; then

	MOUNTSDCARD ${FSTYPE}
	if [ "$?" -eq "0" ]; then

		ECHOL "### Mounted SDCard1!"

		DRPATH="/storage/sdcard1/${LOGDIR}"

	else

		ECHOL "### Not mounting SDCard1, using /cache instead!"

		# Mount cache, it is the XZDR fallback
		if [ "$(${BUSYBOX} mount | ${BUSYBOX} grep 'cache' | ${BUSYBOX} wc -l)" = "0" ]; then
			BBXECL mount /cache
		fi

		DRPATH="/cache/${LOGDIR}"

	fi

	if [ ! -d "${DRPATH}" ]; then
		ECHOL "${DRPATH} directory does not exist, creating it now."
		BBXECL mkdir ${DRPATH}
	fi

fi

# Here we setup a binaries folder, to make the rest of the script readable and easy to use. It will allow us to slim it down too.
ECHOL "Creating symlinks in /drbin to all functions of busybox."
# Create a symlink for each of the supported commands
for sym in `${BUSYBOX} --list`; do
#	${BUSYBOX} echo "Linking ${BUSYBOX} to /drbin/$sym" >> ${DRLOG}
	${BUSYBOX} ln -s ${BUSYBOX} /drbin/$sym
done

export PATH="/drbin"

# drbin is now the only path, with all the busybox functions linked, it's safe to use normal commands from here on.
# Using ECHOL from here on adds all the lines to the XZDR log file.
# Using EXECL from here on will echo the command and it's result in to the logfile.
# Not all commands will allow this to be used, so sometimes you will have to do without.

# Rotate and merge logs
ECHOL "Logfile rotation..."
if [ -f "${DRPATH}/${XZDRLOG}" ]; then
	EXECL mv ${DRPATH}/${XZDRLOG} ${DRPATH}/${XZDRLOG}.old
fi
EXECL touch ${DRPATH}/${XZDRLOG}
EXECL chmod 660 ${DRPATH}/${XZDRLOG}
cat ${DRLOG} > ${DRPATH}/${XZDRLOG}
rm ${DRLOG}
DRLOG="${DRPATH}/${XZDRLOG}"

if [ ! -d "/system/etc/init.d" ]; then
        TECHOL "No init.d directory found, creating it now!"
        TECHOL "To enable init.d support, set dr.enable.initd to true in XZDR.prop!"
        mkdir /system/etc/init.d
fi

# Initial setup of the XZDR.prop file, only once or whenever the file was removed
if [ ! -f "${DRPATH}/XZDR.prop" ]; then
        ECHOL "Creating XZDR.prop file."
        touch ${DRPATH}/XZDR.prop
        ECHOL "dr.recovery.boot will be set to TWRP (default)"
        DRSETPROP dr.recovery.boot twrp
        ECHOL "dr.initd.active will be set to false (default)"
        DRSETPROP dr.initd.active false
        DRSETPROP dr.keep.byeselinux false
fi

# Initial button setup for existing XZDR.prop files which do not have the input nodes defined.
if [ "$(DRGETPROP dr.pwrkey.node)" = "" -o "$(DRGETPROP dr.pwrkey.node)" = "null" ]; then
        DRSETPROP dr.pwrkey.node $(pwrkeySearch)
fi
if [ "$(DRGETPROP dr.gpiokeys.node)" = "" -o "$(DRGETPROP dr.gpiokeys.node)" = "null" ]; then
        DRSETPROP dr.gpiokeys.node $(gpioKeysSearch)
fi

KEEPBYESELINUX=$(DRGETPROP dr.keep.byeselinux)

# Base setup, find the right led nodes.
BOOTREC_LED_RED="/sys/class/leds/$(ls -1 /sys/class/leds|grep red)/brightness"
BOOTREC_LED_GREEN="/sys/class/leds/$(ls -1 /sys/class/leds|grep green)/brightness"
BOOTREC_LED_BLUE="/sys/class/leds/$(ls -1 /sys/class/leds|grep blue)/brightness"
EVENTNODE=$(DRGETPROP dr.gpiokeys.node)
RECOVERYBOOT="false"
KEYCHECK="false"

if [ "$(grep 'warmboot=0x77665502' /proc/cmdline | wc -l)" = "1" ]; then

        ECHOL "Reboot 'recovery' trigger found."
        RECOVERYBOOT="true"

elif [ -f "/cache/recovery/boot" -o -f "${DRPATH}/boot" ]; then

        ECHOL "Recovery 'boot file' trigger found."
        RECOVERYBOOT="true"

        if [ -f "/cache/recovery/boot" ]; then
                EXECL rm -f /cache/recovery/boot
        fi

        if [ -f "${DRPATH}/boot" ]; then
                EXECL rm -f ${DRPATH}/boot
        fi

else

        ECHOL "DR Keycheck..."
        cat ${EVENTNODE} > /dev/keycheck &

        # Vibrate to alert user to make a choice
        ECHOL "Trigger vibrator"
        echo 150 > /sys/class/timed_output/vibrator/enable
        usleep 300000
        echo 150 > /sys/class/timed_output/vibrator/enable

        # Turn on green LED as a visual cue
        SETLED on 0 255 0

        EXECL sleep 3

        hexdump < /dev/keycheck > /dev/keycheckout

        VOLUKEYCHECK=`cat /dev/keycheckout | grep '0001 0073' | wc -l`
        VOLDKEYCHECK=`cat /dev/keycheckout | grep '0001 0072' | wc -l`

        if [ "$VOLUKEYCHECK" != "0" -a "$VOLDKEYCHECK" = "0" ]; then
                ECHOL "Recorded VOL-UP on ${EVENTNODE}!"
                KEYCHECK="UP"
        elif [ "$VOLDKEYCHECK" != "0" -a "$VOLUKEYCHECK" = "0" ]; then
                ECHOL "Recorded VOL-DOWN on ${EVENTNODE}!"
                KEYCHECK="DOWN"
        elif [ "$VOLUKEYCHECK" != "0" -a "$VOLDKEYCHECK" != "0" ]; then
                ECHOL "Recorded BOTH VOL-UP & VOL-DOWN on ${EVENTNODE}! Making the choice to go to the UP target..."
                KEYCHECK="UP"
        fi

        EXECL killall cat

        EXECL rm -f /dev/keycheck
        EXECL rm -f /dev/keycheckout

        if [ "$KEYCHECK" != "false" ]; then

                ECHOL "Recovery 'volume button' trigger found."
                RECOVERYBOOT="true"

        fi

fi

if [ "$RECOVERYBOOT" = "true" ]; then

        # Recovery boot mode notification
        SETLED on 255 0 255

        cd /

        # reboot recovery trigger or boot file found, no keys pressed: read what recovery to use
        if [ "$KEYCHECK" = "false" ]; then
                RECLOAD="$(DRGETPROP dr.recovery.boot)"
                if [ "$RECLOAD" = "cwm" ]; then
			RECLOAD="philz"
		fi
                RECLOG="Booting to ${RECLOAD}..."
        fi

        # Prepare PhilZ recovery - by button press
        if [ "$KEYCHECK" = "UP" ]; then
                RECLOAD="philz"
                RECLOG="Booting recovery by keypress, booting to PhilZ Touch..."
        fi

        # Prepare TWRP recovery - by button press
        if [ "$KEYCHECK" = "DOWN" ]; then
                RECLOAD="twrp"
                RECLOG="Booting recovery by keypress, booting to TWRP..."
        fi

	if [ "$KEYCHECK" != "false" ]; then
		DRSETPROP dr.recovery.boot $RECLOAD
	fi
	RAMDISK="/sbin/recovery.$RECLOAD.cpio"
	PACKED="false"

	if [ ! -f "$RAMDISK" ]; then
		ECHOL "CPIO Archive not found, accepting it probably is an lzma version!"
		EXECL lzma -d /sbin/recovery.${RECLOAD}.cpio.lzma
	fi

	EXECL mkdir /recovery
	EXECL cd /recovery

	# Unmount all active filesystems
	EXECL umount -l /system
        EXECL umount -l /dev/cpuctl
        EXECL umount -l /dev/pts
        EXECL umount -l /mnt/asec
        EXECL umount -l /mnt/obb
        EXECL umount -l /mnt/qcks
        EXECL umount -l /mnt/idd        # Appslog
        EXECL umount -l /data/idd       # Appslog
        EXECL umount -l /data           # Userdata
        EXECL umount -l /lta-label      # LTALabel

	# Unpack the ramdisk image
	cpio -i -u < $RAMDISK

	SETLED off

	# Executing INIT.
	ECHOL "Executing recovery init, have fun!"

	# Here the log dies.
	${BUSYBOX} umount -l /cache
	${BUSYBOX} umount -l /storage/sdcard1
	${BUSYBOX} umount -l /drbin
	${BUSYBOX} rm -fr /drbin
	${BUSYBOX} chroot /recovery /init

fi

# init.d support
if [ "$(DRGETPROP dr.initd.active)" = "true" ]; then

	ECHOL "Init.d folder found and execution is enabled!"
	ECHOL "It will run the following scripts:"
	BBXECL run-parts --test /system/etc/init.d
	ECHOL "Executing them in the background now."
	/sbin/busybox nohup /sbin/busybox run-parts /system/etc/init.d &

else

	ECHOL "Init.d execution is disabled."
	ECHOL "To enable it, set dr.initd.active to true in XZDR.prop!"

fi

ECHOL "DEBUGINFO=Current mounted filesystems:"
BBXECL mount

ECHOL "Unmounting log location and booting to Android."

${BUSYBOX} umount -l /storage/sdcard1
${BUSYBOX} umount -l /drbin
${BUSYBOX} rm -fr /drbin
export PATH="$_PATH"

if [ "$KEEPBYESELINUX" != "true" ]; then
	/system/bin/rmmod byeselinux
	if [ "$systemmounted" = "false" ]; then
		${BUSYBOX} umount /system
	fi
else
	if [ "$systemmounted" = "false" ]; then
		${BUSYBOX} umount /system
	fi
fi

exit 0
