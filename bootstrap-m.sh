#!/bin/bash

set -e

if [[ "$EUID" -ne 0 ]]; then
	echo "Wispux bootstrap script must be run as root."
	echo
	exit 1
elif [[ $# != 1 || ! -d "$1" ]]; then
	echo "Please pass 1 argument: your target mount directory"
	echo
	exit 1
fi

cigs=(
man-pages
iana-etc
glibc
zlib
lib32-zlib
bzip2
lib32-bzip2
xz
lib32-xz
lz4
lib32-lz4
zstd
lib32-zstd
file
readline
lib32-readline
m4
bc
flex
tcl
expect
dejagnu
pkgconf
binutils
gmp
lib32-gmp
mpfr
libmpc
libisl
attr
lib32-attr
acl
lib32-acl
libcap
lib32-libcap
libxcrypt
lib32-libxcrypt
shadow
gcc
ncurses
lib32-ncurses
sed
psmisc
gettext
bison
grep
bash
libtool
lib32-libltdl
gdbm
gperf
expat
lib32-expat
inetutils
less
perl
perl-xml-parser
intltool
autoconf
automake
openssl
lib32-openssl
elfutils
lib32-libelf
libffi
lib32-libffi
python
python-flit-core
python-wheel
python-setuptools
ninja
meson
kmod
lib32-kmod
coreutils
check
diffutils
gawk
findutils
groff
gzip
iproute2
kbd
libpipeline
make
patch
tar
texinfo
vi
python-markupsafe
python-jinja
eudev
man-db
procps-ng
util-linux
lib32-util-linux
e2fsprogs

libunistring
libidn2
libpsl
pcre2
lib32-pcre2
curl
git
)

set +h
umask 022
cd $1
export DRAG_ROOT=$(pwd)
mkdir -p $DRAG_ROOT/root/.cache/drag
mkdir -p ~/.cache
ln -sf $DRAG_ROOT/root/.cache/drag ~/.cache
mkdir -p $DRAG_ROOT/root/.cache/wispux-bootstrap
mkdir -p ~/.cache
ln -sf $DRAG_ROOT/root/.cache/wispux-bootstrap ~/.cache
export PATH=$DRAG_ROOT/tools/bin:$PATH
export TGT=x86_64-wispux-linux-gnu
export TGT32=i686-wispux-linux-gnu
export TGTX32=x86_64-wispux-linux-gnux32
export LC_ALL=POSIX
export CONFIG_SITE=$DRAG_ROOT/usr/share/config.site
unset CFLAGS CXXFLAGS
ashtray=~/.cache/drag/ashtray
if [ -f ~/.cache/wispux-bootstrap/krnlver ]; then
	KRNLVER=$(cat ~/.cache/wispux-bootstrap/krnlver)
	GLIBCVER=$(cat ~/.cache/wispux-bootstrap/glibcver)
	GCCVER=$(cat ~/.cache/wispux-bootstrap/gccver)
fi
if [[ ! -f $DRAG_ROOT/usr/bin/smoke || ! -f /usr/bin/smoke ]]; then
	rm -rf drag
	git clone https://github.com/catnipsta/drag
	chmod +x drag/scripts/*
	mkdir -p $DRAG_ROOT/usr/bin/
	cp drag/scripts/* $DRAG_ROOT/usr/bin/
	cp drag/scripts/* /usr/bin/
	rm -rf drag
fi

tmpfsmount() {
	if ! mountpoint -q $DRAG_ROOT/proc; then
	mount -t proc /proc $DRAG_ROOT/proc
	fi
	if ! mountpoint -q $DRAG_ROOT/sys; then
	mount --rbind /sys $DRAG_ROOT/sys
	mount --make-rslave $DRAG_ROOT/sys
	fi
	if ! mountpoint -q $DRAG_ROOT/dev; then
	mount --rbind /dev $DRAG_ROOT/dev
	mount --make-rslave $DRAG_ROOT/dev
	fi
	if ! mountpoint -q $DRAG_ROOT/run; then
	mount --bind /run $DRAG_ROOT/run
	mount --make-slave $DRAG_ROOT/run
	fi
}

if [ ! -f ~/.cache/wispux-bootstrap/1 ]; then
echo
echo "STAGE 1 - Setup"
echo

chown root:root $DRAG_ROOT
chmod 755 $DRAG_ROOT
cd $DRAG_ROOT

mkdir -pv ./{etc,var,boot,home,mnt,opt,dev,proc,sys,run/lock,root,tmp} \
	./usr/{bin,include,lib32,lib/locale,local/{bin,include,lib,sbin,share,src},sbin,src} \
	./usr/local/share/{doc,info,locale,misc,terminfo,zoneinfo,man/man{1..8}} \
	./usr/lib/firmware ./var/{cache,lib,log,opt,spool,mail,tmp}
ln -sfv usr/bin bin
ln -sfv usr/lib lib
ln -sfv lib usr/lib64
ln -sfv usr/lib lib64
ln -sfv usr/lib32 lib32
ln -sfv usr/sbin sbin
ln -sfv ../run var/run
ln -sfv ../run/lock var/lock
ln -sfv ../proc/self/mounts etc/mtab
chmod 1777 var/tmp
chmod 1777 var/mail
chmod 0750 root
chmod 1777 tmp
touch var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp var/log/lastlog
chmod -v 664  var/log/lastlog
chmod -v 600  var/log/btmp

	echo "Pinching /etc/passwd"
	cat > $DRAG_ROOT/etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
uuidd:x:80:80:uuid daemon user:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
	echo "Pinching /etc/group"
	cat > $DRAG_ROOT/etc/group << "EOF"
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
	echo "Pinching /etc/profile"
	cat > $DRAG_ROOT/etc/profile << "EOF"
umask 022

appendpath () {
    case ":$PATH:" in
        *:"$1":*)
            ;;
        *)
            PATH="${PATH:+$PATH:}$1"
    esac
}

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

export ashtray=~/.cache/drag/ashtray

EOF
echo "export MAKEFLAGS='"$MAKEFLAGS"'" >> $DRAG_ROOT/etc/profile
	cat >> $DRAG_ROOT/etc/profile << "EOF"
#export CFLAGS="-march=native -O2 -pipe"
#export CXXFLAGS="${CFLAGS}"

if [ -d /etc/profile.d/ ]; then
        for f in /etc/profile.d/*.sh; do
                [ -r "$f" ] && . "$f"
        done
fi
EOF
sed -i "s/'/\"/g" $DRAG_ROOT/etc/profile

	echo "Pinching /etc/resolv.conf"
	cp --dereference /etc/resolv.conf $DRAG_ROOT/etc/
	echo

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
mount -t tmpfs -o nosuid,nodev tmpfs /dev/shm
mount -t tmpfs -o nosuid,nodev tmpfs /run
chmod 0755 /run
mount -t tmpfs -o nosuid,nodev tmpfs /tmp
mount -a
swapon -a

. /etc/locale.conf
export LANG LC_ALL LC_COLLATE LC_CTYPE

hostname "$(cat /etc/hostname)"

#Setup udev
udevd --daemon
udevadm trigger
udevadm settle

# Module loading
#modprobe i915

# D-Bus
#mkdir -p /run/dbus
#chmod 755 /run/dbus
#export $(dbus-launch)
#dbus-daemon --system --nofork --nopidfile &

setsid agetty --noclear tty1 38400 linux &
setsid agetty tty2 38400 linux &
setsid agetty tty3 38400 linux &
setsid agetty tty4 38400 linux &

# Manual ethernet
#ip link set lo up
#ip link set eth0 up
#ip addr add XXX.XXX.XXX.XXX/XX dev eth0
#ip route add default via XXX.XXX.XXX.XXX

# wpa_supplicant
#wpa_supplicant -B -iwlan0 -c/etc/wpa_supplicant.conf

# dhcpcd
#dhcpcd -b

while true; do wait; done
EOF
	chmod +x $DRAG_ROOT/sbin/init
	echo "Pinching power utilities"
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
swapoff -a
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,ro /

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
swapoff -a
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,ro /

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
swapoff -a
umount $(awk '$2 != "/" && $2 != "/proc" && $2 != "/sys" && $2 != "/dev" && $2 != "/run" {print $2}' /proc/mounts | tac)
mount -o remount,ro /

echo "Halting..."
echo h > /proc/sysrq-trigger
EOF
	chmod +x $DRAG_ROOT/sbin/poweroff $DRAG_ROOT/sbin/reboot $DRAG_ROOT/sbin/halt
	cp $DRAG_ROOT/sbin/{poweroff,reboot,halt} $DRAG_ROOT/usr/bin

	echo "Pinching drag"
	cd
	
	echo "Branding Wispux"
	cat > $DRAG_ROOT/etc/os-release << "EOF"
NAME="Wispux Linux"
PRETTY_NAME="Wispux Linux"
ID="wispux"
EOF

touch ~/.cache/wispux-bootstrap/1
fi
if [ ! -f ~/.cache/wispux-bootstrap/2 ]; then
echo
echo "STAGE 2 - Download the Linux kernel, Glibc, and GCC"
echo

rm -rf $DRAG_ROOT/usr/src/linux* $ashtray/glibc $ashtray/gcc

curl -Lo ~/.cache/wispux-bootstrap/lfs.html https://linuxfromscratch.org/lfs/view/stable/chapter03/packages.html

#DGCCVER=$(grep ">GCC (" ~/.cache/wispux-bootstrap/lfs.html)
#DGCCVER=${DGCCVER##*\(}
#DGCCVER=${DGCCVER%%)*}
DGCCVER=14.2.0

#DGLIBCVER=$(grep ">Glibc (" ~/.cache/wispux-bootstrap/lfs.html)
#DGLIBCVER=${DGLIBCVER##*\(}
#DGLIBCVER=${DGLIBCVER%%)*}
DGLIBCVER=2.41

DKRNLVER=$(grep ">Linux (" ~/.cache/wispux-bootstrap/lfs.html)
DKRNLVER=${DKRNLVER##*\(}
DKRNLVER=${DKRNLVER%%)*}

rm ~/.cache/wispux-bootstrap/lfs.html

read -p "What Linux kernel version do you wish to use? (default: $DKRNLVER) " KRNLVER
read -p "Glibc version? (default: $DGLIBCVER) " GLIBCVER
read -p "GCC version?   (default: $DGCCVER) " GCCVER

[[ $KRNLVER == "" ]] && KRNLVER=$DKRNLVER
[[ $GLIBCVER == "" ]] && GLIBCVER=$DGLIBCVER
[[ $GCCVER == "" ]] && GCCVER=$DGCCVER

curl -If https://ftp.gnu.org/gnu/glibc/glibc-$GLIBCVER.tar.xz
curl -If https://ftp.gnu.org/gnu/gcc/gcc-$GCCVER/gcc-$GCCVER.tar.xz

cd $DRAG_ROOT/usr/src
curl -O https://cdn.kernel.org/pub/linux/kernel/v${KRNLVER:0:1}.x/linux-$KRNLVER.tar.xz
tar xJf linux-$KRNLVER.tar.xz

echo $KRNLVER  > ~/.cache/wispux-bootstrap/krnlver
echo $GLIBCVER > ~/.cache/wispux-bootstrap/glibcver
echo $GCCVER   > ~/.cache/wispux-bootstrap/gccver

touch ~/.cache/wispux-bootstrap/2
fi
if [ ! -f ~/.cache/wispux-bootstrap/3 ]; then
echo
echo "STAGE 3 - Download PKGBUILDs"
echo

for i in ${cigs[@]}; do
	[ $i != eudev ] && stash -ns $i
done


### PATCH PKGBUILDS TO CORRECT SOURCE, CONFIGURATION, BUILD, AND DISABLE CERTAIN COMMANDS WHICH WOULD COMPLICATE THE PROCESS ###

cat > ~/.cache/drag/stash/glibc/PKGBUILD << EOF
pkgname=glibc
pkgver=$GLIBCVER

EOF
cat >> ~/.cache/drag/stash/glibc/PKGBUILD << "EOF"
source=("https://ftp.gnu.org/gnu/glibc/glibc-$pkgver.tar.xz")

build() {
cd glibc-$pkgver

sed -e '/unistd.h/i #include <string.h>' \
    -e '/libc_rwlock_init/c\
  __libc_rwlock_define_initialized (, reset_lock);\
  memcpy (&lock, &reset_lock, sizeof (lock));' \
    -i stdlib/abort.c 

mkdir -p build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure --prefix=/usr \
	--disable-werror \
	--enable-kernel=5.4 \
	libc_cv_slibdir=/usr/lib \
	--enable-stack-protector=strong \
	--disable-nscd
make
make DESTDIR=$srcdir/64 install

rm -rf ./*
find .. -name "*.a" -delete

CC="gcc -m32" CXX="g++ -m32" \
../configure --prefix=/usr \
	--host=i686-pc-linux-gnu \
	--build=$(../scripts/config.guess) \
	--libdir=/usr/lib32 \
	--libexecdir=/usr/lib32 \
	--disable-werror \
	--disable-nscd \
	libc_cv_slibdir=/usr/lib32 \
	--enable-stack-protector=strong \
	--enable-kernel=5.4
make
make DESTDIR=$srcdir/32 install
}

package() {
mkdir -p $pkgdir/usr/lib32
cp -a $srcdir/64/* $pkgdir
cp -a $srcdir/32/usr/lib32/* $pkgdir/usr/lib32/
install -vm644 $srcdir/32/usr/include/gnu/{lib-names,stubs}-32.h $pkgdir/usr/include/gnu

sed '/RTLDLIST=/s@/usr@@g' -i $pkgdir/usr/bin/ldd
mkdir -p $pkgdir/etc
echo "passwd: files" >  $pkgdir/etc/nsswitch.conf
echo "group: files" >> $pkgdir/etc/nsswitch.conf
echo "shadow: files" >> $pkgdir/etc/nsswitch.conf
echo "hosts: files dns" >> $pkgdir/etc/nsswitch.conf
echo "networks: files" >> $pkgdir/etc/nsswitch.conf
echo "protocols: files" >> $pkgdir/etc/nsswitch.conf
echo "services: files" >> $pkgdir/etc/nsswitch.conf
echo "ethers: files" >> $pkgdir/etc/nsswitch.conf
echo "rpc: files" >> $pkgdir/etc/nsswitch.conf
echo "/usr/local/lib" > $pkgdir/etc/ld.so.conf
echo "/usr/lib32" >> $pkgdir/etc/ld.so.conf

localedef -i C -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8
echo "LANG=en_US.UTF-8" > /etc/locale.conf
}
EOF

cat > ~/.cache/drag/stash/gcc/PKGBUILD << EOF
pkgname=gcc
pkgver=$GCCVER

EOF
cat >> ~/.cache/drag/stash/gcc/PKGBUILD << "EOF"
source=("https://ftp.gnu.org/gnu/gcc/gcc-$pkgver/gcc-$pkgver.tar.xz")

build() {
cd gcc-$pkgver

sed -e '/m32=/s/m32=.*/m32=..\/lib32$(call if_multiarch,:i386-linux-gnu)/' -i gcc/config/i386/t-linux64

mkdir -p build
cd build

../configure --prefix=/usr \
	LD=ld \
	--enable-languages=c,c++ \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-host-pie \
	--enable-multilib \
	--with-multilib-list=m64,m32 \
	--disable-bootstrap \
	--disable-fixincludes \
	--with-system-zlib
make
}

package() {
cd gcc-$pkgver/build

make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/binutils/PKGBUILD
cat > ~/.cache/drag/stash/binutils/PKGBUILD << EOF
pkgname=binutils
pkgver=${pkgver%%+*}

EOF
)
cat >> ~/.cache/drag/stash/binutils/PKGBUILD << "EOF"
source=("https://sourceware.org/pub/binutils/releases/binutils-$pkgver.tar.xz")

build() {
cd binutils-$pkgver

mkdir -p build
cd build

../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --disable-gdb       \
             --disable-gdbserver \
             --enable-default-hash-style=gnu
make tooldir=/usr
}

package() {
cd binutils-$pkgver/build

make DESTDIR=$pkgdir tooldir=/usr install
}
EOF

mkdir -p ~/.cache/drag/stash/eudev
cat > ~/.cache/drag/stash/eudev/PKGBUILD << "EOF"
pkgname=eudev
pkgver=3.2.14
source=(https://github.com/eudev-project/eudev/releases/download/v$pkgver/eudev-$pkgver.tar.gz)

build() {
cd eudev-$pkgver

mkdir -p build
cd build 

../configure --prefix=/usr --sysconfdir=/etc --disable-static
make
make DESTDIR=$srcdir/64 install

rm -rf *
CC="gcc -m32 -march=i686" CXX="g++ -m32 -march=i686" PKG_CONFIG_PATH="/usr/lib32/pkgconfig" LANG=en_US.UTF-8 \
../configure --prefix=/usr --libdir=/usr/lib32 --sysconfdir=/etc --disable-static
make
make DESTDIR=$srcdir/32 install
}

package() {
cd eudev-$pkgver/build
cp -a $srcdir/64/* $pkgdir
mkdir -p $pkgdir/usr/lib32
cp -r $srcdir/32/usr/lib32/* $pkgdir/usr/lib32

mkdir -p $pkgdir/etc/udev/rules.d
echo 'KERNEL=="card*", SUBSYSTEM=="drm", GROUP="video", MODE="0660"' > $pkgdir/etc/udev/rules.d/99-dri.rules
echo 'KERNEL=="renderD*", SUBSYSTEM=="drm", GROUP="video", MODE="0660"' >> $pkgdir/etc/udev/rules.d/99-dri.rules
echo 'KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0660"' > $pkgdir/etc/udev/rules.d/99-input.rules
}
EOF

cat > ~/.cache/drag/stash/eudev/eudev.install << "EOF"
#!/bin/sh

post_install() {
udev-hwdb update
}
EOF

mkdir -p ~/.cache/drag/stash/linux-firmware
cat > ~/.cache/drag/stash/linux-firmware/PKGBUILD << EOF
pkgname=linux-firmware
pkgver=$(date +%Y%m%d)
EOF
cat >> ~/.cache/drag/stash/linux-firmware/PKGBUILD << "EOF"
source=(https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git)

package() {
mkdir -p $pkgdir/usr/lib/
mv linux-firmware $pkgdir/usr/lib/firmware
}
EOF

stash -ns grub
(source ~/.cache/drag/stash/grub/PKGBUILD
cat > ~/.cache/drag/stash/grub/PKGBUILD << EOF
pkgname=grub
pkgver=$_pkgver
EOF
)
cat >> ~/.cache/drag/stash/grub/PKGBUILD << "EOF"
source=(https://ftp.gnu.org/gnu/grub/grub-$pkgver.tar.xz)
prepare(){
cd grub-$pkgver
echo depends bli part_gpt > grub-core/extra_deps.lst
}
build(){
unset {C,CXX,LD}FLAGS
cd grub-$pkgver
[[ $(cat /sys/firmware/efi/fw_platform_size) == 64 ]] && fluff="--target=x86_64 --with-platform=efi"
./configure --prefix=/usr --sysconfdir=/etc --disable-efiemu --disable-werror $fluff
make
}
package() {
cd grub-$pkgver
make DESTDIR=$pkgdir install
}
EOF

sed -i 's/pkgver=.*/pkgver=8.6.16/' ~/.cache/drag/stash/tcl/PKGBUILD
sed -i 's/pkgname=.*/pkgname=libxcrypt/' ~/.cache/drag/stash/libxcrypt/PKGBUILD
sed -i 's/pkgname=.*/pkgname=lib32-libxcrypt/' ~/.cache/drag/stash/lib32-libxcrypt/PKGBUILD
sed -i '/--with-libpam/d; /--with-audit/d; /--enable-man/d' ~/.cache/drag/stash/shadow/PKGBUILD
sed -i '/case/,/esac/d' ~/.cache/drag/stash/openssl/PKGBUILD
sed -i '/local _platform/d' ~/.cache/drag/stash/openssl/PKGBUILD
sed -i 's/pkgbase/pkgname/' ~/.cache/drag/stash/openssl/PKGBUILD
sed -i '/if \[/,/fi/d' ~/.cache/drag/stash/openssl/PKGBUILD
sed -i '/shared/c\shared' ~/.cache/drag/stash/openssl/PKGBUILD
sed -i 's/.\/configure/FORCE_UNSAFE_CONFIGURE=1 .\/configure/' ~/.cache/drag/stash/coreutils/PKGBUILD
sed -i 's/.\/configure/FORCE_UNSAFE_CONFIGURE=1 .\/configure/' ~/.cache/drag/stash/tar/PKGBUILD
sed -i 's/.\/configure/.\/configure --disable-vlock/' ~/.cache/drag/stash/kbd/PKGBUILD
sed -i 's/make/CFLAGS=-Wno-error=implicit-function-declaration make/' ~/.cache/drag/stash/vi/PKGBUILD
sed -i '/git /d; /--with-systemd/d' ~/.cache/drag/stash/procps-ng/PKGBUILD
sed -i '/git /d; /jit/d' ~/.cache/drag/stash/pcre2/PKGBUILD
sed -i '/git /d; /jit/d' ~/.cache/drag/stash/lib32-pcre2/PKGBUILD
sed -i '/msg/d; /configure/s/$/ --host=i686-pc-linux-gnu/' ~/.cache/drag/stash/lib32-readline/PKGBUILD
sed -i 's/configure/configure --host=i686-pc-linux-gnu/' ~/.cache/drag/stash/lib32-gmp/PKGBUILD
sed -i '/PKG_CONFIG/d' ~/.cache/drag/stash/lib32-libelf/PKGBUILD
sed -i 's/.\/configure/FORCE_UNSAFE_CONFIGURE=1 .\/configure/' ~/.cache/drag/stash/coreutils/PKGBUILD
sed -i '/tracking/,/=libidn2/d' ~/.cache/drag/stash/libpsl/PKGBUILD
sed -i '/with-psl/c\ ' ~/.cache/drag/stash/libpsl/PKGBUILD
sed -i '/with-readline/c\ ' ~/.cache/drag/stash/bc/PKGBUILD 
sed -i '/prepare()/,/^}/d' ~/.cache/drag/stash/{expect,grep,libtool,lib32-libltdl,inetutils,coreutils,diffutils,findutils,gzip,patch,libpsl,file,readline,flex,gmp,mpfr,attr,acl,shadow,psmisc,groff}/PKGBUILD
sed -i '/check()/,/^}/d' ~/.cache/drag/stash/{tcl,bison,autoconf,automake,libffi,psmisc,libtool,coreutils,gawk,tar,texinfo,attr,acl,sed,gperf,make,lib32-{zlib,lz4}}/PKGBUILD

### CHECKSUMS NO LONGER VALID FOR THESE PACKAGES ###
sed -i '/b2sums=(.*)/d; /b2sums=(/,/)/d; /sha256sums=(.*)/d; /sha256sums=(/,/)/d; /sha512sums=(.*)/d; /sha512sums=(/,/)/d;' ~/.cache/drag/stash/{coreutils,diffutils,file,findutils,grep,gzip,patch,flex,pkgconf,attr,acl,psmisc,libtool,lib32-libltdl,inetutils,automake,groff,shadow,tcl,gmp,lib32-gmp,make}/PKGBUILD

sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/coreutils\/coreutils-$pkgver.tar.xz)/' ~/.cache/drag/stash/coreutils/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/diffutils\/diffutils-$pkgver.tar.xz)/' ~/.cache/drag/stash/diffutils/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/astron.com\/pub\/file\/file-$pkgver.tar.gz)/' ~/.cache/drag/stash/file/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/findutils\/findutils-$pkgver.tar.xz)/' ~/.cache/drag/stash/findutils/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/grep\/grep-$pkgver.tar.xz)/' ~/.cache/drag/stash/grep/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/gzip\/gzip-$pkgver.tar.xz)/' ~/.cache/drag/stash/gzip/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/patch\/patch-$pkgver.tar.xz)/' ~/.cache/drag/stash/patch/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/github.com\/westes\/flex\/releases\/download\/v$pkgver\/flex-$pkgver.tar.gz)/' ~/.cache/drag/stash/flex/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/distfiles.ariadne.space\/pkgconf\/pkgconf-$pkgver.tar.xz)/' ~/.cache/drag/stash/pkgconf/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/download.savannah.gnu.org\/releases\/attr\/attr-$pkgver.tar.gz)/' ~/.cache/drag/stash/attr/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/download.savannah.gnu.org\/releases\/acl\/acl-$pkgver.tar.xz)/' ~/.cache/drag/stash/acl/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/sourceforge.net\/projects\/psmisc\/files\/psmisc\/psmisc-$pkgver.tar.xz)/' ~/.cache/drag/stash/psmisc/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/libtool\/libtool-${pkgver%%+*}.tar.xz)/' ~/.cache/drag/stash/libtool/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/libtool\/libtool-${pkgver%%+*}.tar.xz)/' ~/.cache/drag/stash/lib32-libltdl/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/inetutils\/inetutils-$pkgver.tar.xz)/' ~/.cache/drag/stash/inetutils/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/automake\/automake-$pkgver.tar.xz)/' ~/.cache/drag/stash/automake/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/ftp.gnu.org\/gnu\/groff\/groff-$pkgver.tar.gz)/' ~/.cache/drag/stash/groff/PKGBUILD
sed -zi 's/source=(\([^)]*\))/source=(https:\/\/github.com\/shadow-maint\/shadow\/releases\/download\/$pkgver\/shadow-$pkgver.tar.xz)/' ~/.cache/drag/stash/shadow/PKGBUILD
for i in {coreutils,diffutils,findutils,grep,gzip,patch,flex,pkgconf,attr,acl,psmisc,libtool,lib32-libltdl,inetutils,automake,groff,shadow}; do
	sed -i 's/cd .*pkgname.*/cd $pkgname-$pkgver/' ~/.cache/drag/stash/$i/PKGBUILD
done
sed -i 's/cd file/cd $pkgname-$pkgver/' ~/.cache/drag/stash/file/PKGBUILD
sed -i 's/cd libtool/cd libtool-${pkgver%%+*}/' ~/.cache/drag/stash/{libtool,lib32-libltdl}/PKGBUILD
sed -i 's/lz/xz/' ~/.cache/drag/stash/{gmp,lib32-gmp}/PKGBUILD
sed -i 's/lz/gz/' ~/.cache/drag/stash/make/PKGBUILD

(source ~/.cache/drag/stash/xz/PKGBUILD
cat > ~/.cache/drag/stash/xz/PKGBUILD << EOF
pkgname=xz
pkgver=$pkgver
source=(https://github.com/tukaani-project/xz/releases/download/v$pkgver/xz-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/xz/PKGBUILD << "EOF"
build(){
cd $pkgname-$pkgver
./configure --prefix=/usr --disable-static
make
}
package(){
cd $pkgname-$pkgver
make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/lib32-xz/PKGBUILD
cat > ~/.cache/drag/stash/lib32-xz/PKGBUILD << EOF
pkgname=lib32-xz
pkgver=$pkgver
source=(https://github.com/tukaani-project/xz/releases/download/v$pkgver/xz-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/lib32-xz/PKGBUILD << "EOF"
build(){
cd xz-$pkgver
CC="gcc -m32" PKG_CONFIG_PATH="/usr/lib32/pkgconfig" ./configure --host=i686-pc-linux-gnu --prefix=/usr --libdir=/usr/lib32 --disable-static
make
}
package(){
cd xz-$pkgver
make DESTDIR=$pkgdir install
rm -rf "$pkgdir"/usr/{bin,include,share}
}
EOF

(source ~/.cache/drag/stash/lz4/PKGBUILD
cat > ~/.cache/drag/stash/lz4/PKGBUILD << EOF
pkgname=lz4
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/lz4/PKGBUILD << "EOF"
build(){
cd lz4
make BUILD_STATIC=no PREFIX=/usr
}
package(){
cd lz4
make DESTDIR=$pkgdir BUILD_STATIC=no PREFIX=/usr install
}
EOF

(source ~/.cache/drag/stash/zstd/PKGBUILD
cat > ~/.cache/drag/stash/zstd/PKGBUILD << EOF
pkgname=zstd
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/zstd/PKGBUILD << "EOF"
build(){
cd zstd-$pkgver
make prefix=/usr
}
package(){
cd zstd-$pkgver
make DESTDIR=$pkgdir prefix=/usr install
}
EOF

(source ~/.cache/drag/stash/lib32-zstd/PKGBUILD
cat > ~/.cache/drag/stash/lib32-zstd/PKGBUILD << EOF
pkgname=lib32-zstd
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/lib32-zstd/PKGBUILD << "EOF"
build(){
cd zstd-$pkgver
CC="gcc -m32" PKG_CONFIG_PATH="/usr/lib32/pkgconfig" make prefix=/usr
}
package(){
cd zstd-$pkgver
make prefix=/usr DESTDIR=$PWD/DESTDIR install
mkdir -p $pkgdir/usr/lib32
cp -Rv DESTDIR/usr/lib/* $pkgdir/usr/lib32/
sed -e "/^libdir/s/lib$/lib32/" -i $pkgdir/usr/lib32/pkgconfig/libzstd.pc
rm -rf DESTDIR
}
EOF

(source ~/.cache/drag/stash/pkgconf/PKGBUILD
cat > ~/.cache/drag/stash/pkgconf/PKGBUILD << EOF
pkgname=pkgconf
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/pkgconf/PKGBUILD << "EOF"
build(){
cd $pkgname-$pkgver
./configure --prefix=/usr --disable-static
make
}
package(){
cd $pkgname-$pkgver
make DESTDIR=$pkgdir install
ln -sv pkgconf $pkgdir/usr/bin/pkg-config
}
EOF

(source ~/.cache/drag/stash/elfutils/PKGBUILD
cat > ~/.cache/drag/stash/elfutils/PKGBUILD << EOF
pkgname=elfutils
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/elfutils/PKGBUILD << "EOF"
prepare(){
cd elfutils
autoreconf -fi
}
build(){
cd elfutils
./configure --prefix=/usr --enable-maintainer-mode
make
}
package(){
cd elfutils
make DESTDIR=$pkgdir install
install -vm644 config/libelf.pc $pkgdir/usr/lib/pkgconfig
}
EOF

(source ~/.cache/drag/stash/expat/PKGBUILD
cat > ~/.cache/drag/stash/expat/PKGBUILD << EOF
pkgname=expat
pkgver=$pkgver
source=(https://prdownloads.sourceforge.net/expat/expat-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/expat/PKGBUILD << "EOF"
build(){
cd expat-$pkgver
./configure --prefix=/usr --disable-static
make
}
package(){
cd expat-$pkgver
make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/lib32-expat/PKGBUILD
cat > ~/.cache/drag/stash/lib32-expat/PKGBUILD << EOF
pkgname=lib32-expat
pkgver=$pkgver
source=(https://prdownloads.sourceforge.net/expat/expat-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/lib32-expat/PKGBUILD << "EOF"
build(){
cd expat-$pkgver
CC="gcc -m32" CXX="g++ -m32" PKG_CONFIG_PATH="/usr/lib32/pkgconfig" ./configure --prefix=/usr --libdir=/usr/lib32 --host=i686-pc-linux-gnu --disable-static
make
}
package(){
cd expat-$pkgver
make DESTDIR=$PWD/DESTDIR install
mkdir -p $pkgdir/usr/lib32
cp -Rv DESTDIR/usr/lib32/* $pkgdir/usr/lib32
rm -rf DESTDIR
}
EOF

(source ~/.cache/drag/stash/python/PKGBUILD
cat > ~/.cache/drag/stash/python/PKGBUILD << EOF
pkgname=python
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/python/PKGBUILD << "EOF"
build(){
cd Python-$pkgver
./configure --prefix=/usr --enable-shared --with-system-expat --enable-optimizations
make
}
package(){
cd Python-$pkgver
make DESTDIR=$pkgdir install
ln -sf python3 $pkgdir/usr/bin/python
ln -sf pip3 $pkgdir/usr/bin/pip
ln -sf python3-config $pkgdir/usr/bin/python-config
ln -sf idle3 $pkgdir/usr/bin/idle
ln -sf pydoc3 $pkgdir/usr/bin/pydoc
}
EOF

(source ~/.cache/drag/stash/python-flit-core/PKGBUILD
cat > ~/.cache/drag/stash/python-flit-core/PKGBUILD << EOF
pkgname=python-flit-core
pkgver=$pkgver
source=(https://pypi.org/packages/source/f/flit-core/flit_core-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/python-flit-core/PKGBUILD << "EOF"
build(){
cd flit_core-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd flit_core-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist flit_core
}
EOF

(source ~/.cache/drag/stash/python-wheel/PKGBUILD
cat > ~/.cache/drag/stash/python-wheel/PKGBUILD << EOF
pkgname=python-wheel
pkgver=$pkgver
source=(https://pypi.org/packages/source/w/wheel/wheel-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/python-wheel/PKGBUILD << "EOF"
build(){
cd wheel-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd wheel-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist wheel
}
EOF

(source ~/.cache/drag/stash/python-setuptools/PKGBUILD
cat > ~/.cache/drag/stash/python-setuptools/PKGBUILD << EOF
pkgname=python-setuptools
pkgver=$pkgver
source=(https://pypi.org/packages/source/s/setuptools/setuptools-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/python-setuptools/PKGBUILD << "EOF"
build(){
cd setuptools-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd setuptools-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist setuptools
}
EOF

(source ~/.cache/drag/stash/python-markupsafe/PKGBUILD
cat > ~/.cache/drag/stash/python-markupsafe/PKGBUILD << EOF
pkgname=python-markupsafe
pkgver=$pkgver
source=(https://pypi.org/packages/source/M/MarkupSafe/markupsafe-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/python-markupsafe/PKGBUILD << "EOF"
build(){
cd markupsafe-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd markupsafe-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist MarkupSafe
}
EOF

(source ~/.cache/drag/stash/python-jinja/PKGBUILD
cat > ~/.cache/drag/stash/python-jinja/PKGBUILD << EOF
pkgname=python-jinja
pkgver=$pkgver
source=(https://pypi.org/packages/source/J/Jinja2/jinja2-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/python-jinja/PKGBUILD << "EOF"
build(){
cd jinja2-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd jinja2-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist Jinja2
}
EOF

(source ~/.cache/drag/stash/ninja/PKGBUILD
cat > ~/.cache/drag/stash/ninja/PKGBUILD << EOF
pkgname=ninja
pkgver=$pkgver
source=(https://github.com/ninja-build/ninja/archive/v$pkgver/ninja-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/ninja/PKGBUILD << "EOF"
build(){
cd ninja-$pkgver
python configure.py --bootstrap --verbose
}
package(){
cd ninja-$pkgver
mkdir -p $pkgdir/usr/bin $pkgdir/usr/share/{bash-completion/completions,zsh/site-functions}
install -vDm755 ninja $pkgdir/usr/bin/
install -vDm644 misc/bash-completion $pkgdir/usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion $pkgdir/usr/share/zsh/site-functions/_ninja
}
EOF

(source ~/.cache/drag/stash/meson/PKGBUILD
cat > ~/.cache/drag/stash/meson/PKGBUILD << EOF
pkgname=meson
pkgver=$pkgver
source=(https://github.com/mesonbuild/meson/releases/download/$pkgver/meson-$pkgver.tar.gz
arch-meson)
EOF
)
cat >> ~/.cache/drag/stash/meson/PKGBUILD << "EOF"
build(){
cd meson-$pkgver
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
}
package(){
cd meson-$pkgver
mkdir -p $pkgdir
pip3 install --root=$pkgdir --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson $pkgdir/usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson $pkgdir/usr/share/zsh/site-functions/_meson
install -D ../arch-meson -t "$pkgdir/usr/bin"
sed -i '/features/d' $pkgdir/usr/bin/arch-meson
}
EOF

(source ~/.cache/drag/stash/gdbm/PKGBUILD
cat > ~/.cache/drag/stash/gdbm/PKGBUILD << EOF
pkgname=gdbm
pkgver=$pkgver
source=(https://ftp.gnu.org/gnu/gdbm/gdbm-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/gdbm/PKGBUILD << "EOF"
build(){
cd gdbm-$pkgver
./configure --prefix=/usr \
	--disable-static \
	--enable-libgdbm-compat
make
}
package(){
cd gdbm-$pkgver
make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/check/PKGBUILD
cat > ~/.cache/drag/stash/check/PKGBUILD << EOF
pkgname=check
pkgver=$pkgver
source=(https://github.com/libcheck/check/releases/download/$pkgver/check-$pkgver.tar.gz)
EOF
)
cat >> ~/.cache/drag/stash/check/PKGBUILD << "EOF"
build(){
cd check-$pkgver
./configure --prefix=/usr --disable-static
make
}
package(){
cd check-$pkgver
make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/perl/PKGBUILD
cat > ~/.cache/drag/stash/perl/PKGBUILD << EOF
pkgname=perl
pkgver=$pkgver
source=(https://www.cpan.org/src/${pkgver%%.*}.0/perl-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/perl/PKGBUILD << "EOF"
export BUILD_ZLIB=False
export BUILD_BZIP2=0

build(){
cd perl-$pkgver

sh Configure -des \
	-Dprefix=/usr \
	-Dvendorprefix=/usr \
	-Dprivlib=/usr/lib/perl5/${pkgver%.*}/core_perl \
	-Darchlib=/usr/lib/perl5/${pkgver%.*}/core_perl \
	-Dsitelib=/usr/lib/perl5/${pkgver%.*}/site_perl \
	-Dsitearch=/usr/lib/perl5/${pkgver%.*}/site_perl \
	-Dvendorlib=/usr/lib/perl5/${pkgver%.*}/vendor_perl \
	-Dvendorarch=/usr/lib/perl5/${pkgver%.*}/vendor_perl \
	-Dman1dir=/usr/share/man/man1 \
	-Dman3dir=/usr/share/man/man3 \
	-Dpager="/usr/bin/less -isR" \
	-Duseshrplib \
	-Dusethreads
make
}
package(){
cd perl-$pkgver
make DESTDIR=$pkgdir install
unset BUILD_ZLIB BUILD_BZIP2
}
EOF

(source ~/.cache/drag/stash/kmod/PKGBUILD
cat > ~/.cache/drag/stash/kmod/PKGBUILD << EOF
pkgname=kmod
pkgver=$pkgver
source=(https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/kmod/PKGBUILD << "EOF"
build(){
cd kmod-$pkgver

mkdir -p build
cd build

meson setup --prefix=/usr .. \
	--sbindir=/usr/sbin \
	--buildtype=release \
	-Dmanpages=false
meson compile
}
package(){
cd kmod-$pkgver/build

meson install --destdir=$pkgdir
}
EOF

(source ~/.cache/drag/stash/util-linux/PKGBUILD
cat > ~/.cache/drag/stash/util-linux/PKGBUILD << EOF
pkgname=util-linux
pkgver=$pkgver
source=(https://kernel.org/pub/linux/utils/util-linux/v${pkgver%.*}/util-linux-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/util-linux/PKGBUILD << "EOF"
build(){
cd util-linux-$pkgver

./configure --bindir=/usr/bin \
	--libdir=/usr/lib \
	--runstatedir=/run \
	--disable-liblastlog2 \
        --disable-pylibmount \
        --without-python
make
}
package(){
cd util-linux-$pkgver

make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/lib32-util-linux/PKGBUILD
cat > ~/.cache/drag/stash/lib32-util-linux/PKGBUILD << EOF
pkgname=lib32-util-linux
pkgver=$pkgver
source=(https://kernel.org/pub/linux/utils/util-linux/v${pkgver%.*}/util-linux-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/lib32-util-linux/PKGBUILD << "EOF"
build(){
cd util-linux-$pkgver

CC="gcc -m32" PKG_CONFIG_PATH="/usr/lib32/pkgconfig" ./configure --bindir=/usr/bin \
	--host=i686-pc-linux-gnu \
	--libdir=/usr/lib32 \
	--runstatedir=/run \
	--disable-liblastlog2 \
        --disable-pylibmount \
        --without-python
make
}
package(){
cd util-linux-$pkgver

make DESTDIR=$PWD/DESTDIR install
mkdir -p $pkgdir/usr/lib32
cp -Rv DESTDIR/usr/lib32/* $pkgdir/usr/lib32
rm -rf DESTDIR
}
EOF

(source ~/.cache/drag/stash/curl/PKGBUILD
cat > ~/.cache/drag/stash/curl/PKGBUILD << EOF
pkgname=curl
pkgver=$pkgver
source=(https://curl.se/download/curl-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/curl/PKGBUILD << "EOF"
build(){
cd curl-$pkgver

./configure --prefix=/usr --with-openssl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt
make
}
package(){
cd curl-$pkgver

make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/zlib/PKGBUILD
cat > ~/.cache/drag/stash/zlib/PKGBUILD << EOF
pkgname=zlib
pkgver=$pkgver
source=(${source[@]})
EOF
)
cat >> ~/.cache/drag/stash/zlib/PKGBUILD << "EOF"
build(){
cd zlib-$pkgver

./configure --prefix=/usr 
make
}
package(){
cd zlib-$pkgver

make DESTDIR=$pkgdir install
}
EOF

(source ~/.cache/drag/stash/git/PKGBUILD
cat > ~/.cache/drag/stash/git/PKGBUILD << EOF
pkgname=git
pkgver=$pkgver
source=(https://www.kernel.org/pub/software/scm/git/git-$pkgver.tar.xz)
EOF
)
cat >> ~/.cache/drag/stash/git/PKGBUILD << "EOF"
build(){
cd git-$pkgver

./configure --prefix=/usr
make
}
package(){
cd git-$pkgver

make DESTDIR=$pkgdir install
}
EOF

sed -i 's/ftp.gnu.org\/pub/ftpmirror.gnu.org/' ~/.cache/drag/stash/*/PKGBUILD
sed -i 's/ftp.gnu.org/ftpmirror.gnu.org/' ~/.cache/drag/stash/*/PKGBUILD

touch ~/.cache/wispux-bootstrap/3
fi
if [ ! -f ~/.cache/wispux-bootstrap/4 ]; then
echo
echo "STAGE 4 - Download source"
echo

echo "Note:"
echo "If a download is consistently failing, you may need to edit the source variable in a PKGBUILD"
echo "To edit PKGBUILDs, use the snoop command."
echo

for i in ${cigs[@]}; do
	[[ $(cat ~/.cache/wispux-bootstrap/3) != *"--$i--"* ]] && pinch $i
	echo "--$i--" >> ~/.cache/wispux-bootstrap/3
done

mkdir -p $ashtray/ca-certificates/src $DRAG_ROOT/etc/ssl/certs
cd $ashtray/ca-certificates/src
curl -Lqo ca-certificates.crt https://curl.se/ca/cacert.pem
curl -Lqo certsha256sum       https://curl.se/ca/cacert.pem.sha256
actual=$(sha256sum ca-certificates.crt)
actual=${actual%%\ *}
if [[ "$(cat certsha256sum)" == *$actual* ]]; then
        echo "Verified ca-certificates"
        echo
        cp ca-certificates.crt $DRAG_ROOT/etc/ssl/certs/
        cp ca-certificates.crt $DRAG_ROOT/etc/ssl/cert.pem
else
	echo "CHECKSUM VALIDATION FAILED FOR ca-certificates!"
	echo
	exit 1
fi

touch ~/.cache/wispux-bootstrap/4
fi
if [ ! -f ~/.cache/wispux-bootstrap/5 ]; then
echo
echo "STAGE 5 - binutils pass 1"
echo

cd $ashtray/binutils/src/binutils*/

mkdir -p build
cd build

../configure --prefix=$DRAG_ROOT/tools \
	--with-sysroot=$DRAG_ROOT \
	--target=$TGT \
	--disable-nls \
	--enable-gprofng=no \
	--disable-werror \
	--enable-new-dtags \
	--enable-default-hash-style=gnu \
	--disable-gdb \
	--disable-gdbserver
make
make install

cd ..
rm -rf build

touch ~/.cache/wispux-bootstrap/5
fi
if [ ! -f ~/.cache/wispux-bootstrap/6 ]; then
echo
echo "STAGE 6 - GCC pass 1"
echo

cd $ashtray/gcc/src/gcc*/
tar xJf $ashtray/mpfr/src/mpfr*.tar.xz
tar xJf $ashtray/gmp/src/gmp*.tar.xz
tar xzf $ashtray/libmpc/src/mpc*.tar.gz
rm -rf mpfr
rm -rf gmp
rm -rf mpc
mv mpfr*/ mpfr
mv gmp*/ gmp
mv mpc*/ mpc

sed -e '/m32=/s/m32=.*/m32=..\/lib32$(call if_multiarch,:i386-linux-gnu)/' -i gcc/config/i386/t-linux64
sed '/STACK_REALIGN_DEFAULT/s/0/(!TARGET_64BIT \&\& TARGET_SSE)/' -i gcc/config/i386/i386.h

mkdir -p build
cd build

../configure --target=$TGT \
	--prefix=$DRAG_ROOT/tools \
	--with-glibc-version=$GLIBCVER \
	--with-sysroot=$DRAG_ROOT \
	--with-newlib \
	--without-headers \
	--enable-default-pie \
	--enable-default-ssp \
	--disable-nls \
	--disable-shared \
	--enable-multilib --with-multilib-list=m64,m32 \
	--disable-threads \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libquadmath \
	--disable-libssp \
	--disable-libvtv \
	--disable-libstdcxx \
	--enable-languages=c,c++
make
make install

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($TGT-gcc -print-libgcc-file-name)`/include/limits.h

rm -rf build

touch ~/.cache/wispux-bootstrap/6
fi
if [ ! -f ~/.cache/wispux-bootstrap/7 ]; then
echo
echo "STAGE 7 - Linux headers"
echo

cd $DRAG_ROOT/usr/src/linux-$KRNLVER
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -r usr/include $DRAG_ROOT/usr

cd $DRAG_ROOT/usr/src
rm -rf linux-$KRNLVER
tar xJf linux-$KRNLVER.tar.xz
rm linux-$KRNLVER.tar.xz

sed -i 's/EXTRAVERSION =/EXTRAVERSION = -wispux/' linux-$KRNLVER/Makefile

touch ~/.cache/wispux-bootstrap/7
fi
if [ ! -f ~/.cache/wispux-bootstrap/8 ]; then
echo
echo "STAGE 8 - Glibc"
echo

cd $ashtray/glibc/src/glibc*/

mkdir -p build
cd build

echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr \
	--host=$TGT \
	--build=$(../scripts/config.guess) \
	--enable-kernel=5.4 \
	--with-headers=$DRAG_ROOT/usr/include \
	--disable-nscd \
	libc_cv_slibdir=/usr/lib
make
make DESTDIR=$DRAG_ROOT install

sed '/RTLDLIST=/s@/usr@@g' -i $DRAG_ROOT/usr/bin/ldd

make clean
find .. -name "*.a" -delete
CC="$TGT-gcc -m32" CXX="$TGT-g++ -m32" \
../configure --prefix=/usr \
	--host=$TGT32 \
	--build=$(../scripts/config.guess) \
	--enable-kernel=5.4 \
	--with-headers=$DRAG_ROOT/usr/include \
	--disable-nscd \
	--libdir=/usr/lib32 \
	--libexecdir=/usr/lib32 \
	libc_cv_slibdir=/usr/lib32
make
make DESTDIR=$PWD/DESTDIR install
cp -a DESTDIR/usr/lib32 $DRAG_ROOT/usr/
install -vm644 DESTDIR/usr/include/gnu/{lib-names,stubs}-32.h $DRAG_ROOT/usr/include/gnu/
ln -svf ../lib32/ld-linux.so.2 $DRAG_ROOT/lib/ld-linux.so.2

cd ..
rm -rf build

touch ~/.cache/wispux-bootstrap/8
fi
if [ ! -f ~/.cache/wispux-bootstrap/9 ]; then
echo
echo "STAGE 9 - libstdc++"
echo

cd $ashtray/gcc/src/gcc*/

mkdir -p build
cd build

../libstdc++-v3/configure --host=$TGT \
	--build=$(../config.guess) \
	--prefix=/usr \
	--enable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=/tools/$TGT/include/c++/$GCCVER
make
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cd ..
rm -rf build

touch ~/.cache/wispux-bootstrap/9
fi
if [ ! -f ~/.cache/wispux-bootstrap/10 ]; then
echo
echo "STAGE 10 - m4"
echo

cd $ashtray/m4/src/m4*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

make distclean
#cd $ashtray
#pinch m4

touch ~/.cache/wispux-bootstrap/10
fi
if [ ! -f ~/.cache/wispux-bootstrap/11 ]; then
echo
echo "STAGE 11 - ncurses"
echo

cd $ashtray/ncurses/src/ncurses*/

mkdir -p build
cd build
../configure AWK=gawk
make -C include
make -C progs tic
cd $ashtray/ncurses/src/ncurses*/

./configure --prefix=/usr \
	--host=$TGT \
	--build=$(./config.guess) \
	--mandir=/usr/share/man \
	--with-manpage-format=normal \
	--with-shared \
	--without-normal \
	--with-cxx-shared \
	--without-debug \
	--without-ada \
	--disable-stripping \
	AWK=gawk
make
make DESTDIR=$DRAG_ROOT TIC_PATH=$(pwd)/build/progs/tic install
ln -sf libncursesw.so $DRAG_ROOT/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $DRAG_ROOT/usr/include/curses.h

make distclean
CC="$TGT-gcc -m32" CXX="TGT-g++ -m32" \
./configure --prefix=/usr \
	--host=$TGT32 \
	--build=$(./config.guess) \
	--libdir=/usr/lib32 \
	--mandir=/usr/share/man \
	--with-shared \
	--without-normal \
	--with-cxx-shared \
	--without-debug \
	--without-ada \
	--disable-stripping
make
make DESTDIR=$PWD/DESTDIR TIC_PATH=$(pwd)/build/progs/tic install
ln -sf libncursesw.so DESTDIR/usr/lib32/libncurses.so
cp -R DESTDIR/usr/lib32/* $DRAG_ROOT/usr/lib32
rm -rf DESTDIR

cd ..
rm -rf build

touch ~/.cache/wispux-bootstrap/11
fi
if [ ! -f ~/.cache/wispux-bootstrap/12 ]; then
echo
echo "STAGE 12 - bash"
echo

cd $ashtray/bash/src/bash*/

./configure --prefix=/usr --host=$TGT --build=$(sh support/config.guess) --without-bash-malloc
make
make DESTDIR=$DRAG_ROOT install
ln -sf bash $DRAG_ROOT/bin/sh

make distclean
#cd $ashtray
#pinch bash

touch ~/.cache/wispux-bootstrap/12
fi
if [ ! -f ~/.cache/wispux-bootstrap/13 ]; then
echo
echo "STAGE 13 - coreutils"
echo

cd $ashtray/coreutils/src/coreutils*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/13
fi
if [ ! -f ~/.cache/wispux-bootstrap/14 ]; then
echo
echo "STAGE 14 - diffutils"
echo

touch $DRAG_ROOT/usr/include/getopt-cdefs.h

cd $ashtray/diffutils/src/diffutils*/

export CFLAGS="-Wno-error"
./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess) gl_cv_func_strcasecmp_works=y
make
make DESTDIR=$DRAG_ROOT install
unset CFLAGS

touch ~/.cache/wispux-bootstrap/14
fi
if [ ! -f ~/.cache/wispux-bootstrap/15 ]; then
echo
echo "STAGE 15 - file"
echo

cd $ashtray/file/src/file*/

mkdir -p build
cd build
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make
cd $ashtray/file/src/file*/

./configure --prefix=/usr --host=$TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/libmagic.la

touch ~/.cache/wispux-bootstrap/15
fi
if [ ! -f ~/.cache/wispux-bootstrap/16 ]; then
echo
echo "STAGE 16 - findutils"
echo

cd $ashtray/findutils/src/findutils*/

./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

make distclean
#cd $ashtray
#pinch findutils

touch ~/.cache/wispux-bootstrap/16
fi
if [ ! -f ~/.cache/wispux-bootstrap/17 ]; then
echo
echo "STAGE 17 - gawk"
echo

cd $ashtray/gawk/src/gawk*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/17
fi
if [ ! -f ~/.cache/wispux-bootstrap/18 ]; then
echo
echo "STAGE 18 - grep"
echo

cd $ashtray/grep/src/grep*/

./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install
make distclean

touch ~/.cache/wispux-bootstrap/18
fi
if [ ! -f ~/.cache/wispux-bootstrap/19 ]; then
echo
echo "STAGE 19 - gzip"
echo

cd $ashtray/gzip/src/gzip*/

./configure --prefix=/usr --host=$TGT
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/19
fi
if [ ! -f ~/.cache/wispux-bootstrap/20 ]; then
echo
echo "STAGE 20 - make"
echo

cd $ashtray/make/src/make*/

./configure --prefix=/usr --host=$TGT --without-guile --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/20
fi
if [ ! -f ~/.cache/wispux-bootstrap/21 ]; then
echo
echo "STAGE 21 - patch"
echo

cd $ashtray/patch/src/patch*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/21
fi
if [ ! -f ~/.cache/wispux-bootstrap/22 ]; then
echo
echo "STAGE 22 - sed"
echo

cd $ashtray/sed/src/sed*/

./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/22
fi
if [ ! -f ~/.cache/wispux-bootstrap/23 ]; then
echo
echo "STAGE 23 - tar"
echo

cd $ashtray/tar/src/tar*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/wispux-bootstrap/23
fi
if [ ! -f ~/.cache/wispux-bootstrap/24 ]; then
echo
echo "STAGE 24 - xz"
echo

cd $ashtray/xz/src/xz*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess) --disable-static
make
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/liblzma.la

touch ~/.cache/wispux-bootstrap/24
fi
if [ ! -f ~/.cache/wispux-bootstrap/25 ]; then
echo
echo "STAGE 25 - binutils pass 2"
echo

cd $ashtray/binutils/src/binutils*/
sed '6031s/$add_dir//' -i ltmain.sh

mkdir -p build
cd build

../configure --prefix=/usr \
	--build=$(../config.guess) \
	--host=$TGT \
	--disable-nls \
	--enable-shared \
	--enable-gprofng=no \
	--disable-werror \
	--enable-64-bit-bfd \
	--enable-new-dtags \
	--enable-default-hash-style=gnu \
	--without-zstd \
	--disable-gdb \
	--disable-gdbserver
make
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

cd ..
rm -rf build

#cd $ashtray
#pinch binutils

touch ~/.cache/wispux-bootstrap/25
fi
if [ ! -f ~/.cache/wispux-bootstrap/26 ]; then
echo
echo "STAGE 26 - GCC pass 2"
echo

cd $ashtray/gcc/src/gcc*/
tar xJf $ashtray/mpfr/src/mpfr*.tar.xz
tar xJf $ashtray/gmp/src/gmp*.tar.xz
tar xzf $ashtray/libmpc/src/mpc*.tar.gz
rm -rf mpfr
rm -rf gmp
rm -rf mpc
mv mpfr*/ mpfr
mv gmp*/ gmp
mv mpc*/ mpc

sed -e '/m32=/s/m32=.*/m32=..\/lib32$(call if_multiarch,:i386-linux-gnu)/' -i gcc/config/i386/t-linux64
sed '/STACK_REALIGN_DEFAULT/s/0/(!TARGET_64BIT \&\& TARGET_SSE)/' -i gcc/config/i386/i386.h
sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -p build
cd build

../configure --build=$(../config.guess) \
	--host=$TGT \
	--target=$TGT \
	LDFLAGS_FOR_TARGET=-L$PWD/$TGT/libgcc \
	--prefix=/usr \
	--with-build-sysroot=$DRAG_ROOT \
	--enable-default-pie \
	--enable-default-ssp \
	--disable-nls \
	--enable-multilib --with-multilib-list=m64,m32 \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libquadmath \
	--disable-libsanitizer \
	--disable-libssp \
	--disable-libvtv \
	--enable-languages=c,c++
make
make DESTDIR=$DRAG_ROOT install
ln -sf gcc $DRAG_ROOT/usr/bin/cc
ln -sf cc $DRAG_ROOT/usr/bin/c99

cd ..
rm -rf build mpfr gmp mpc

#cd $ashtray
#pinch gcc

touch ~/.cache/wispux-bootstrap/26
fi
if [ ! -f ~/.cache/wispux-bootstrap/27 ]; then
echo
echo "STAGE 27 - gettext"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/gettext/src/gettext*/
./configure --disable-shared
make
cp gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
"

touch ~/.cache/wispux-bootstrap/27
fi
if [ ! -f ~/.cache/wispux-bootstrap/28 ]; then
echo
echo "STAGE 28 - bison"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/bison/src/bison*/
./configure --prefix=/usr
make
make install
"

touch ~/.cache/wispux-bootstrap/28
fi
if [ ! -f ~/.cache/wispux-bootstrap/29 ]; then
echo
echo "STAGE 29 - perl"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/perl/src/perl*/
sh Configure -des \
	-D prefix=/usr \
	-D vendorprefix=/usr \
	-D useshrplib
make
make install
"
cd $ashtray/perl/src
rm -rf perl*/
tar xJf perl*.tar.xz

touch ~/.cache/wispux-bootstrap/29
fi
if [ ! -f ~/.cache/wispux-bootstrap/30 ]; then
echo
echo "STAGE 30 - python"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/python/src/Python*/
./configure --prefix=/usr --enable-shared --without-ensurepip
make
make install
"

touch ~/.cache/wispux-bootstrap/30
fi
if [ ! -f ~/.cache/wispux-bootstrap/31 ]; then
echo
echo "STAGE 31 - texinfo"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/texinfo/src/texinfo*/
./configure --prefix=/usr
make
make install
"

touch ~/.cache/wispux-bootstrap/31
fi
if [ ! -f ~/.cache/wispux-bootstrap/32 ]; then
echo
echo "STAGE 32 util-linux"
echo

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/util-linux/src/util-linux*/
./configure --libdir=/usr/lib \
	--runstatedir=/run \
	--disable-chfn-chsh \
	--disable-login \
	--disable-nologin \
	--disable-su \
	--disable-setpriv \
	--disable-runuser \
	--disable-pylibmount \
	--disable-static \
	--disable-liblastlog2 \
	--without-python
make
make install
make distclean
CC='gcc -m32' \
./configure --host=i686-pc-linux-gnu \
	--libdir=/usr/lib32 \
	--runstatedir=/run \
	--disable-chfn-chsh \
	--disable-login \
	--disable-nologin \
	--disable-su \
	--disable-setpriv \
	--disable-runuser \
	--disable-pylibmount \
	--disable-static \
	--disable-liblastlog2 \
	--without-python
make
make DESTDIR=\$PWD/DESTDIR install
cp -R DESTDIR/usr/lib32/* /usr/lib32
rm -rf DESTDIR
make distclean
"

touch ~/.cache/wispux-bootstrap/32
fi
if [ ! -f ~/.cache/wispux-bootstrap/33 ]; then
echo
echo "STAGE 33 - Hotbox"
echo

echo "Note:"
echo "You may find yourself needing to edit and correct some of the PKGBUILD instructions on this stage."
echo "To edit PKGBUILDs, use the snoop command."
echo

rm -rf $DRAG_ROOT/tools

if (( ${GCCVER%%.*} >= 14 )) && [ ! -f $ashtray/expect/src/patched ]; then
	cd $ashtray/expect/src
	[ ! -f expect-5.45.4-gcc15-1.patch ] && curl -LO https://www.linuxfromscratch.org/patches/downloads/expect/expect-5.45.4-gcc15-1.patch
	cd expect*/
	patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
	touch $ashtray/expect/src/patched
	cd
fi

echo "smoke ${cigs[@]}" > $DRAG_ROOT/root/.cache/hotbox
chmod +x $DRAG_ROOT/root/.cache/hotbox

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "set -e
source /etc/profile
~/.cache/hotbox
"

find $DRAG_ROOT/usr -depth -name x86_64-wispux-linux-gnu\* | xargs rm -rf
sed -i 's/#//' $DRAG_ROOT/etc/profile

touch ~/.cache/wispux-bootstrap/33
fi

echo
echo "Done!"
