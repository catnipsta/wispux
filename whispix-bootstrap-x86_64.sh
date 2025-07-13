#!/bin/bash

set -e

cigs=(
acl
attr
autoconf
automake
audit
bash
bc
binutils
bison
brotli
bzip2
check
coreutils
curl
dejagnu
diffutils
dosfstools
e2fsprogs
expat
expect
elfutils
file
findutils
flex
gawk
gc
gcc
gcc-libs
gdbm
gettext
git
glibc
gperf
gmp
gnupg
gnutls
grep
groff
guile
gzip
iana-etc
icu
inetutils
intltool
iputils
iproute2
jansson
kbd
keyutils
kmod
krb5
less
libcap
libcap-ng
libbpf
libffi
libelf
libidn2
libisl
libp11-kit
libpipeline
libpsl
libmnl
libmpc
libnghttp2
libnghttp3
libnsl
libseccomp
libssh2
libtool
libxcrypt
libtasn1
libtirpc
libgpg-error
libgcrypt
libksba
libxml2
libunistring
leancrypto
lz4
m4
make
man-db
man-pages
meson
mpfr
mpc
ncurses
nettle
ninja
openssl
p11-kit
pam
pambase
patch
pcre2
perl
perl-xml-parser
pkgconf
popt
psmisc
python
python-flit-core
python-jinja
python-markupsafe
python-setuptools
python-wheel
readline
rsync
sed
shadow
tar
tcl
texinfo
unzip
util-linux
util-linux-libs
vi
wget
xxhash
xz
zip
zlib
zlib-ng
zstd
)

if [[ "$EUID" -ne 0 ]]; then
	echo "Whispix bootstrap script must be run as root."
	echo
	exit 1
elif [[ $# != 1 || ! -d "$1" ]]; then
	echo "Please pass 1 argument: your target mount directory"
	echo
	exit 1
fi
umask 022
chown root:root $1
chmod 755 $1
cd $1
if [ ! -d etc ]; then
	mkdir -pv ./{etc,var,boot,home,mnt,opt,dev,proc,sys,run/lock,root,tmp} \
		./usr/{bin,include,lib/locale,local/{bin,include,lib,lib64,sbin,share,src},sbin,src} \
		./usr/local/share/{doc,info,locale,misc,terminfo,zoneinfo,man/man{1..8}} \
		./usr/lib/firmware ./var/{cache,lib,log,opt,spool,mail,tmp}
	ln -sv usr/bin bin
	ln -sv usr/lib lib
	ln -sv lib usr/lib64
	ln -sv usr/lib lib64
	ln -sv usr/sbin sbin
	ln -sfv ../run var/run
	ln -sfv ../run/lock var/lock
	ln -sv ../proc/self/mounts etc/mtab
	chmod 1777 var/tmp
	chmod 1777 var/mail
	chmod 0750 root
	chmod 1777 tmp
	touch var/log/{btmp,lastlog,faillog,wtmp}
	chgrp -v utmp var/log/lastlog
	chmod -v 664  var/log/lastlog
	chmod -v 600  var/log/btmp
fi

export DRAG_ROOT=$(pwd)
mkdir -p $DRAG_ROOT/root/.cache/drag
mkdir -p ~/.cache
ln -sf $DRAG_ROOT/root/.cache/drag ~/.cache

mkdir -p ~/.cache/drag/stash/eudev
cat > ~/.cache/drag/stash/eudev/PKGBUILD << "EOF"
pkgname="eudev"
pkgver="9e7c4e7"
source=("git+https://github.com/eudev-project/eudev.git#commit=$pkgver")

build=(
cd eudev
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make)

package=(
make DESTDIR=$pkgdir install
)
EOF

	ashtray=~/.cache/drag/ashtray
	for cig in ${cigs[@]}; do
		if [ ! -d $DRAG_ROOT/var/lib/drag/smoked/$cig ]; then
		echo "Pinching $cig..."
		url=$(wget --max-redirect=1 -O /dev/null https://archlinux.org/packages/core/x86_64/$cig/download 2>&1 | grep Location | grep ://) || url=$(wget --max-redirect=1 -O /dev/null https://archlinux.org/packages/core/any/$cig/download 2>&1 | grep Location | grep ://) || url=$(wget --max-redirect=1 -O /dev/null https://archlinux.org/packages/extra/x86_64/$cig/download 2>&1 | grep Location | grep ://) || url=$(wget --max-redirect=1 -O /dev/null https://archlinux.org/packages/extra/any/$cig/download 2>&1 | grep Location | grep ://)
		url=${url#Location: }
		url=${url%" [following]"}
		mkdir -p $ashtray/$cig/pkg
		wget -q -O $ashtray/$cig/pkg/$cig.pkg.tar.zst $url
		wget -q -O $ashtray/$cig/pkg/$cig.pkg.tar.zst.sig $url.sig
		echo "Verifying $cig..."
		key="$(gpg --list-packets $ashtray/$cig/pkg/$cig.pkg.tar.zst.sig | grep keyid)"
		key=${key##*keyid }
		gpg --keyserver keyserver.ubuntu.com --recv-keys $key
		gpg --verify $ashtray/$cig/pkg/$cig.pkg.tar.zst.sig $ashtray/$cig/pkg/$cig.pkg.tar.zst
		echo "Arch Linux pre-built binary - unkown version" | tee $ashtray/$cig/ver
		cd $ashtray/$cig/pkg
		tar xf $cig.pkg.tar.zst
		rm $cig.pkg.tar.zst*
		smoke $cig
		fi
	done
	rm -rf .INSTALL .BUILDINFO .PKGINFO .MTREE

 echo "Pinching passwd"
        cat > etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
uuidd:x:80:80:uuid daemon user:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF                                                            
        echo "Pinching group"                                  
        cat > etc/group << "EOF"
root:x:0:                       
bin:x:1:                        
sys:x:2: 
kmem:x:3:
tape:x:4:
tty:x:5: 
daemon:x:6:
floppy:x:7:
disk:x:8:  
lp:x:9:    
dialout:x:10:
auto:x:11:   
video:x:12:  
utmp:x:13: 
cdrom:x:15:
adm:x:16:  
messagebus:x:18:
input:x:24:     
mail:x:34:      
kvm:x:61:  
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF             
        echo "Pinching profile"
        cat > etc/profile << "EOF"
# /etc/profile                    
                                  
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
                                                                        
umask 022                                                               
         
if [ -d /etc/profile.d/ ]; then
        for f in /etc/profile.d/*.sh; do
                [ -r "$f" ] && . "$f"   
        done                            
fi                                   
EOF

	echo "Pinching init"
	cat > $DRAG_ROOT/sbin/init << "EOF"
#!/bin/sh

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

mount -o remount,rw /
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs /dev/shm
mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs /run
mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs /tmp
mount -a

. /etc/locale.conf

export LANG LC_ALL LC_COLLATE
hostname "$(cat /etc/hostname)"

udevd --daemon
udevadm trigger
udevadm settle

#Ethernet setup
#ip link set lo up
#ip link set eth0 up
#ip addr add XXX.XXX.XXX.XXX/XX dev eth0
#ip route add default via XXX.XXX.XXX.XXX

setsid agetty --noclear tty1 38400 linux &
setsid agetty tty2 38400 linux &
setsid agetty tty3 38400 linux &
setsid agetty tty4 38400 linux &

while true; do wait; done
EOF
	chmod +x $DRAG_ROOT/sbin/init
	echo "Pinched init"
	echo
	
	echo "Pinching power commands..."
	cat > $DRAG_ROOT/sbin/poweroff << "EOF"
#!/bin/sh

if [ $EUID != 0 ]; then
	echo "Insufficient privileges."
	echo
	exit 1
elif [ $PPID != 1 ]; then
	nohup $0 >/dev/null 2>&1 &
	exit 0
fi

echo "Syncing filesystems..."
sync

echo "Killing processes..."
kill -TERM -1
sleep 1
kill -KILL -1

echo "Unmounting filesystems..."
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,rw /

echo "Powering off..."
echo o > /proc/sysrq-trigger
EOF
	cat > $DRAG_ROOT/sbin/reboot << "EOF"
#!/bin/sh

if [ $EUID != 0 ]; then
	echo "Insufficient privileges."
	echo
	exit 1
elif [ $PPID != 1 ]; then
	nohup $0 >/dev/null 2>&1 &
	exit 0
fi

echo "Syncing filesystems..."
sync

echo "Killing processes..."
kill -TERM -1
sleep 1
kill -KILL -1

echo "Unmounting filesystems..."
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,rw /

echo "Rebooting..."
echo b > /proc/sysrq-trigger
EOF
	cat > $DRAG_ROOT/sbin/halt << "EOF"
#!/bin/sh

if [ $EUID != 0 ]; then
	echo "Insufficient privileges."
	echo
	exit 1
elif [ $PPID != 1 ]; then
	nohup $0 >/dev/null 2>&1 &
	exit 0
fi

echo "Syncing filesystems..."
sync

echo "Killing processes..."
kill -TERM -1
sleep 1
kill -KILL -1

echo "Unmounting filesystems..."
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,rw /

echo "Halting..."
echo h > /proc/sysrq-trigger
EOF
	chmod +x $DRAG_ROOT/sbin/poweroff $DRAG_ROOT/sbin/reboot $DRAG_ROOT/sbin/halt
	echo "Pinched power commands"
	echo

	echo "Pinching drag"
	cd
	rm -rf drag
	git clone https://github.com/catnipsta/drag
	chmod +x drag/scripts/*
	mv drag/scripts/* $DRAG_ROOT/usr/bin/
	rm -rf drag
	echo "Pinched drag!"
	
	pinch ca-certificates

	echo "Branding Whispix"
	cat > $DRAG_ROOT/etc/os-release << "EOF"
NAME="Whispix"
ID="whispix"
EOF
	echo
	echo "Done!"
