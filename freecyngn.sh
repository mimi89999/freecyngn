#!/sbin/sh

export BASE_DIR=/system/freecyngn
export TMP_DIR=/tmp/freecyngn
LOGFILE=$BASE_DIR/log

echo -n '' > $LOGFILE
chmod 644 $LOGFILE

export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin:/sbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib:/lib:/sbin
export ANDROID_BOOTLOGO=1
export ANDROID_ROOT=/system
export ANDROID_ASSETS=/system/app
export ANDROID_DATA=/data
export ANDROID_STORAGE=/storage
export ASEC_MOUNTPOINT=/mnt/asec
export LOOP_MOUNTPOINT=/mnt/obb
export BOOTCLASSPATH=/system/framework/core.jar:/system/framework/conscrypt.jar:/system/framework/okhttp.jar:/system/framework/core-junit.jar:/system/framework/bouncycastle.jar:/system/framework/ext.jar:/system/framework/framework.jar:/system/framework/framework2.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/mms-common.jar:/system/framework/android.policy.jar:/system/framework/services.jar:/system/framework/apache-xml.jar:/system/framework/webviewchromium.jar

if ! [ -f $BASE_DIR/busybox ] || ! [ -f $BASE_DIR/noAnalytics-dvk.jar ] || ! [ -f $BASE_DIR/baksmali-dvk.jar ] || ! [ -f $BASE_DIR/smali-dvk.jar ]
then
	echo "!!! Patch framework incomplete, can't continue!" >> $LOGFILE
	exit
fi

export SETTINGS_APP=/system/app/Settings.apk

if ! [ -f $SETTINGS_APP ]
then
	export SETTINGS_APP=/system/priv-app/Settings.apk
fi

if ! [ -f $SETTINGS_APP ]
then
	echo '!!! Did not find Settings.apk on /system, is any ROM installed?' >> $LOGFILE
	exit
fi

echo '--- Creating directory structure...' >> $LOGFILE
rm -rf $TMP_DIR/Settings $TMP_DIR/noAnalytics 2>&1 >> $LOGFILE

# ensure dalvik-cache exists
mkdir -p /cache/dalvik-cache /data/dalvik-cache 2>&1 >> $LOGFILE

mkdir -p $TMP_DIR/Settings/smali 2>&1 >> $LOGFILE
mkdir -p $TMP_DIR/noAnalytics/smali/com/google/analytics/tracking/android 2>&1 >> $LOGFILE

echo '--- Extracting classes.dex from noAnalytics...' >> $LOGFILE
$BASE_DIR/busybox unzip $BASE_DIR/noAnalytics-dvk.jar classes.dex -d $TMP_DIR/noAnalytics 2>&1 >> $LOGFILE
echo '--- Extracting classes.dex from Settings...' >> $LOGFILE
$BASE_DIR/busybox unzip $SETTINGS_APP classes.dex -d $TMP_DIR/Settings 2>&1 >> $LOGFILE || $BASE_DIR/busybox unzip $SETTINGS_APP classes.dex -d $TMP_DIR/Settings 2>&1 >> $LOGFILE

echo '--- Disassemble classes.dex from Settings...' >> $LOGFILE
dalvikvm -cp $BASE_DIR/baksmali-dvk.jar org.jf.baksmali.main -o $TMP_DIR/Settings/smali $TMP_DIR/Settings/classes.dex 2>&1 >> $LOGFILE
echo '--- Disassemble classes.dex from noAnalytics...' >> $LOGFILE
dalvikvm -cp $BASE_DIR/baksmali-dvk.jar org.jf.baksmali.main -o $TMP_DIR/noAnalytics/smali $TMP_DIR/noAnalytics/classes.dex 2>&1 >> $LOGFILE

echo '--- Remove old Google Analytics...' >> $LOGFILE
rm -rf $TMP_DIR/Settings/smali/com/google/analytics $TMP_DIR/Settings/smali/com/google/android/gms 2>&1 >> $LOGFILE

echo '--- Insert noAnalytics...' >> $LOGFILE
cp -r $TMP_DIR/noAnalytics/smali $TMP_DIR/Settings 2>&1 >> $LOGFILE

echo '--- Reassembling classes.dex...' >> $LOGFILE
rm $TMP_DIR/Settings/classes.dex 2>&1 >> $LOGFILE
dalvikvm -Xmx256m -cp $BASE_DIR/smali-dvk.jar org.jf.smali.main  -o $TMP_DIR/Settings/classes.dex $TMP_DIR/Settings/smali 2>&1 >> $LOGFILE

echo '--- Adding new classes.dex to Settings.apk...' >> $LOGFILE
cd $TMP_DIR/Settings
echo classes.dex | $BASE_DIR/zip -0 -@ $SETTINGS_APP 2>&1 >> $LOGFILE

echo '--- Cleaning up apps...' >> $LOGFILE
rm -f /system/*app/CMAccount.apk /system/*app/CMS.apk /system/*app/LockClock.apk  2>&1 >> $LOGFILE
rm -f /system/*app/Voice+.apk /system/*app/VoiceDialer.apk /system/*app/VoicePlus.apk  2>&1 >> $LOGFILE
rm -f /system/*app/WhisperPush.apk 2>&1 >> $LOGFILE


echo '--- Installing self-reflasher...' >> $LOGFILE
cp $BASE_DIR/20-freecyngn.sh /system/addon.d/20-freecyngn.sh 2>&1 >> $LOGFILE
chmod 755 /system/addon.d/20-freecyngn.sh 2>&1 >> $LOGFILE

echo >> $LOGFILE
echo '--- done' >> $LOGFILE

echo 'Have fun!'
