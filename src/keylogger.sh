#!/sbin/busybox sh
#
# Dual Recovery for Z
#
# Author:
#   [NUT]
# Thanks go to DooMLoRD for the keycodes and a working example!
#
###########################################################################

set +x
_PATH="$PATH"
export PATH=/system/xbin

# Defining constants, from commandline
DRPATH="$1"
LOGFILE="$2"
LOG="${DRPATH}/${LOGFILE}"

# Kickstarting log
DATETIME=`date +"%d-%m-%Y %H:%M:%S"`
echo "START Dual Recovery at ${DATETIME}: STAGE 2." > ${LOG}

# Z setup
#BOOTREC_CACHE_NODE="/dev/block/mmcblk0p25 b 179 25"
#BOOTREC_CACHE="/dev/block/mmcblk0p25"
BOOTREC_EXTERNAL_SDCARD_NODE="/dev/block/mmcblk1p1 b 179 32"
BOOTREC_EXTERNAL_SDCARD="/dev/block/mmcblk1p1"
BOOTREC_LED_RED="/sys/class/leds/$(busybox ls -1 /sys/class/leds|busybox grep red)/brightness"
BOOTREC_LED_GREEN="/sys/class/leds/$(busybox ls -1 /sys/class/leds|busybox grep green)/brightness"
BOOTREC_LED_BLUE="/sys/class/leds/$(busybox ls -1 /sys/class/leds|busybox grep blue)/brightness"

# Defining functions
ECHOL(){
  _TIME=`date +"%H:%M:%S"`
  echo "${_TIME}: $*" >> ${LOG}
  return 0
}
EXECL(){
  _TIME=`date +"%H:%M:%S"`
  echo "${_TIME}: $*" >> ${LOG}
  $* 2>&1 >> ${LOG}
  _RET=$?
  echo "${_TIME}: RET=${_RET}" >> ${LOG}
  return ${_RET}
}

mount -o remount,rw rootfs /
echo 0 > /sys/kernel/security/sony_ric/enable

ECHOL "DR Keycheck..."

# Vibrate to alert user to make a choice
ECHOL "Trigger vibrator"
echo 300 > /sys/class/timed_output/vibrator/enable

# Turn on green LED as a visual cue
ECHOL "Turn on white led"
echo 255 > ${BOOTREC_LED_RED}
echo 255 > ${BOOTREC_LED_GREEN}
echo 255 > ${BOOTREC_LED_BLUE}

SKIP=0
INPUTID=0

for INPUT in `find /dev/input/event* | sort -k1.17n`; do

	if [ $INPUTID -lt $SKIP ]; then
                INPUTID=`expr $INPUTID + 1`
                continue
        fi

	ECHOL "Listening on $INPUT"

	cat $INPUT > /dev/keycheck$INPUTID &

	INPUTID=`expr $INPUTID + 1`

done

echo 300 > /sys/class/timed_output/vibrator/enable

EXECL sleep 3

INPUTID=0

for INPUT in `find /dev/input/event* | sort -k1.17n`; do

	if [ $INPUTID -lt $SKIP ]; then
		INPUTID=`expr $INPUTID + 1`
		continue
	fi

	hexdump < /dev/keycheck$INPUTID > /dev/keycheckout$INPUTID

	VOLKEYCHECK=`cat /dev/keycheckout$INPUTID`

	ECHOL "Recorded UP $INPUT: $VOLKEYCHECK"

	INPUTID=`expr $INPUTID + 1`

done

EXECL rm -f /dev/keycheckout*

echo 300 > /sys/class/timed_output/vibrator/enable

EXECL sleep 3

INPUTID=0

for INPUT in `find /dev/input/event* | sort -k1.17n`; do

	if [ $INPUTID -lt $SKIP ]; then
		INPUTID=`expr $INPUTID + 1`
		continue
	fi

	hexdump < /dev/keycheck$INPUTID > /dev/keycheckout$INPUTID

	VOLKEYCHECK=`cat /dev/keycheckout$INPUTID`

	ECHOL "Recorded DOWN $INPUT: $VOLKEYCHECK"

	INPUTID=`expr $INPUTID + 1`

done

EXECL rm -f /dev/keycheckout*

echo 300 > /sys/class/timed_output/vibrator/enable

EXECL sleep 3

INPUTID=0

for INPUT in `find /dev/input/event* | sort -k1.17n`; do

	if [ $INPUTID -lt $SKIP ]; then
		INPUTID=`expr $INPUTID + 1`
		continue
	fi

	hexdump < /dev/keycheck$INPUTID > /dev/keycheckout$INPUTID

	VOLKEYCHECK=`cat /dev/keycheckout$INPUTID`

	ECHOL "Recorded POWER $INPUT: $VOLKEYCHECK"

	INPUTID=`expr $INPUTID + 1`

done

EXECL rm -f /dev/keycheckout*

echo 300 > /sys/class/timed_output/vibrator/enable

EXECL sleep 3

INPUTID=0

for INPUT in `find /dev/input/event* | sort -k1.17n`; do

	if [ $INPUTID -lt $SKIP ]; then
		INPUTID=`expr $INPUTID + 1`
		continue
	fi

	hexdump < /dev/keycheck$INPUTID > /dev/keycheckout$INPUTID

	VOLKEYCHECK=`cat /dev/keycheckout$INPUTID`

	ECHOL "Recorded CAMERA $INPUT: $VOLKEYCHECK"

	INPUTID=`expr $INPUTID + 1`

done

EXECL killall cat

EXECL rm -f /dev/keycheck*

# Turn on green LED as a visual cue
ECHOL "Turn led green..."
echo 0 > ${BOOTREC_LED_RED}
echo 255 > ${BOOTREC_LED_GREEN}
echo 0 > ${BOOTREC_LED_BLUE}

sleep 2

# Turn off LED
ECHOL "Turning off led..."
echo 0 > ${BOOTREC_LED_RED}
echo 0 > ${BOOTREC_LED_GREEN}
echo 0 > ${BOOTREC_LED_BLUE}

ECHOL "Remount / ro..."
mount -o remount,ro rootfs /

ECHOL "Return to normal boot mode..."

# Ending log
DATETIME=`busybox date +"%d-%m-%Y %H:%M:%S"`
echo "STOP Dual Recovery at ${DATETIME}: STAGE 2." >> ${LOG}

# Unmount SDCard1
umount -l /storage/sdcard1

# Return path variable to default
export PATH="${_PATH}"

# Continue booting
exec /system/bin/chargemon.stock
