#!/bin/bash

# preparaion
# copy 2017-03-02-raspbian-jessie-lite.img to sd card
# set interfaces for eth0
# touch /boot/ssh
# -> boot pi
# raspi-config -> hostname tx-pi, enable ssh, expand filesystem

# TODO
# - fix store
# - add screen calibration tool
# - adjust timezone
# much much more ...

# to be run on plain jessie-lite
echo "Setting up TX-PI on jessie lite ..."

GITBASE="https://raw.githubusercontent.com/ftCommunity/ftcommunity-TXT/master/"
GITROOT=$GITBASE"board/fischertechnik/TXT/rootfs"
SVNBASE="https://github.com/ftCommunity/ftcommunity-TXT.git/trunk/"
SVNROOT=$SVNBASE"board/fischertechnik/TXT/rootfs"
TSVNBASE="https://github.com/harbaum/TouchUI.git/trunk/"

# Things you may do:
# set a root password
# enable root ssh login
# apt-get install emacs-nox

if [ "$HOSTNAME" != tx-pi ]; then
    echo "Make sure your R-Pi has been setup completely and is named tx-pi"
    exit -1
fi

# ----------------------- package installation ---------------------

apt-get update

# X11
apt-get -y install --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev xserver-xorg-legacy
# python and pyqt
apt-get -y install --no-install-recommends python3-pyqt4 python3 python3-pip python3-numpy python3-dev cmake
# misc tools
apt-get -y install i2c-tools lighttpd git subversion ntpdate

# ---------------------- display setup ----------------------
# check if waveshare driver is installed
if [ ! -f /boot/overlays/waveshare32b-overlay.dtb ]; then
    echo "============================================================"
    echo "============== SCREEN DRIVER INSTALLATION =================="
    echo "============================================================"
    echo "= YOU NEED TO RESTART THIS SCRIPT ONCE THE PI HAS REBOOTED ="
    echo "============================================================"
    cd
    wget -N http://www.waveshare.com/w/upload/7/74/LCD-show-170309.tar.gz
    tar xvfz LCD-show-170309.tar.gz
    cd LCD-show
    ./LCD32-show
    # the pi will reboot
fi

# some additionl python stuff
pip3 install semantic_version

# opencv is not directly available so we need to build it
# TODO: build debian packages!
cd /root
git clone https://github.com/Itseez/opencv.git
git clone https://github.com/Itseez/opencv_contrib.git
cd opencv
mkdir build
cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D INSTALL_C_EXAMPLES=OFF \
      -D INSTALL_PYTHON_EXAMPLES=OFF \
      -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
      -D BUILD_EXAMPLES=OFF ..
make -j4
make install
ldconfig

# ----------------------- user setup ---------------------
# create ftc user
groupadd ftc
useradd -g ftc -m ftc
usermod -a -G video ftc
usermod -a -G tty ftc

echo "ftc:ftc" | chpasswd

# special ftc permissions
cd /etc/sudoers.d
wget -N $GITROOT/etc/sudoers.d/shutdown
chmod 0440 shutdown

# ----------------------- display setup ---------------------

# disable fbturbo/enable ordinary fbdev
rm -f /usr/share/X11/xorg.conf.d/99-fbturbo.conf
cat <<EOF > /usr/share/X11/xorg.conf.d/99-fbdev.conf
Section "Device"
        Identifier      "FBDEV"
        Driver          "fbdev"
        Option          "fbdev" "/dev/fb1"

        Option          "SwapbuffersWait" "true"
EndSection
EOF

# X server/launcher start
cat <<EOF > /etc/systemd/system/launcher.service
[Unit]
Description=Start Launcher

[Service]
ExecStart=/bin/su ftc -c "PYTHONPATH=/opt/ftc startx /opt/ftc/launcher.py"
ExecStop=/usr/bin/killall xinit

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable launcher

# allow any user to start xs
sed -i 's,^\(allowed_users=\).*,\1'\anybody',' /etc/X11/Xwrapper.config

# rotate display
sed -i 's,^\(dtoverlay=waveshare32b.rotate=\).*,\1'\0',' /boot/config.txt

# rotate touchscreen 
cat <<EOF > /usr/share/X11/xorg.conf.d/99-calibration.conf
Section "InputClass"
Identifier "calibration"
MatchProduct "ADS7846 Touchscreen"
Option "Calibration" "200 3900 200 3900"
Option "SwapAxes" "0"
EndSection
EOF

# hide cursor and disable screensaver
cat <<EOF > /etc/X11/xinit/xserverrc
#!/bin/sh
exec /usr/bin/X -s 0 dpms -nocursor -nolisten tcp "\$@"
EOF

# allow user to modify locale
touch /etc/locale
chmod og+rw /etc/locale

# set timezone to germany
echo "Europe/Berlin" > /etc/timezone

# set firmware version
cd /etc
wget -N $GITROOT/etc/fw-ver.txt

# set various udev rules to give ftc user access to
# hardware
cd /etc/udev/rules.d
wget -N $GITROOT/etc/udev/rules.d/40-btsmart.rules
wget -N $GITROOT/etc/udev/rules.d/40-robolt.rules
wget -N $GITROOT/etc/udev/rules.d/40-wedo.rules
wget -N $GITROOT/etc/udev/rules.d/60-i2c-tools.rules

# get /opt/ftc
echo "Populating /opt/ftc ..."
cd /opt
rm -rf ftc
svn export $SVNROOT"/opt/ftc"
cd /opt/ftc
# just fetch a copy of ftrobopy to make some programs happy
wget -N https://raw.githubusercontent.com/ftrobopy/ftrobopy/master/ftrobopy.py

# remove usedless ftgui
rm -rf /opt/ftc/apps/system/ftgui

# add power tool from touchui
cd /opt/ftc/apps/system
svn export $TSVNBASE"/touchui/apps/system/power"

# adjust lighttpd config
sed -i 's,^\(server.document-root *=\).*,\1'\ \"/var/www\"',' /etc/lighttpd/lighttpd.conf
sed -i 's,^\(server.username *=\).*,\1'\ \"ftc\"',' /etc/lighttpd/lighttpd.conf
sed -i 's,^\(server.groupname *=\).*,\1'\ \"ftc\"',' /etc/lighttpd/lighttpd.conf

# enable ssi
if ! grep -q mod_ssi /etc/lighttpd/lighttpd.conf; then
cat <<EOF >> /etc/lighttpd/lighttpd.conf

server.modules += ( "mod_ssi" )
ssi.extension = ( ".html" )
EOF
fi

# enable cgi
if ! grep -q mod_cgi /etc/lighttpd/lighttpd.conf; then
cat <<EOF >> /etc/lighttpd/lighttpd.conf
server.modules += ( "mod_cgi" )

\$HTTP["url"] =~ "^/cgi-bin/" {
       cgi.assign = ( "" => "" )
}

cgi.assign      = (
       ".py"  => "/usr/bin/python3"
)
EOF
fi
    
# fetch www pages
echo "Populating /var/www ..."
cd /var
rm -rf www
svn export $SVNROOT"/var/www"

# adjust file ownership for changed www user name
chown -R ftc:ftc /var/www/*
chown -R ftc:ftc /var/log/lighttpd
chown -R ftc:ftc /var/run/lighttpd

#mkdir /opt/ftc/apps/user
#chown -R ftc:ftc /opt/ftc/apps/user

mkdir /home/ftc/apps
chown -R ftc:ftc /home/ftc/apps

/etc/init.d/lighttpd restart

echo "rebooting ..."

sync
reboot
