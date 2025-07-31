#!/bin/bash

set -e

if [[ "$EUID" -ne 0 ]]; then
	echo "Whispix bootstrap script must be run as root."
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
bzip2
xz
lz4
zstd
file
readline
m4
bc
flex
tcl
expect
dejagnu
pkgconf
binutils
gmp
mpfr
libmpc
attr
acl
libcap
libxcrypt
shadow
gcc
ncurses
sed
psmisc
gettext
bison
grep
bash
libtool
gdbm
gperf
expat
inetutils
less
perl
perl-xml-sax-expat
intltool
autoconf
automake
openssl
elfutils
libffi
python
python-flit-core
python-wheel
python-setuptools
ninja
meson
kmod
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
man-db
procps-ng
util-linux
e2fsprogs
wget
git
)

set +h
umask 022
cd $1
export DRAG_ROOT=$(pwd)
mkdir -p $DRAG_ROOT/root/.cache/drag
mkdir -p ~/.cache
ln -sf $DRAG_ROOT/root/.cache/drag ~/.cache
mkdir -p $DRAG_ROOT/root/.cache/whispix-bootstrap
mkdir -p ~/.cache
ln -sf $DRAG_ROOT/root/.cache/whispix-bootstrap ~/.cache
export PATH=$DRAG_ROOT/tools/bin:$PATH
export TGT=$(uname -m)-whispix-linux-gnu
export LC_ALL=POSIX
export CONFIG_SITE=$DRAG_ROOT/usr/share/config.site
unset CFLAGS CXXFLAGS
ashtray=~/.cache/drag/ashtray
if [ -f ~/.cache/whispix-bootstrap/krnlver ]; then
	KRNLVER=$(cat ~/.cache/whispix-bootstrap/krnlver)
	GLIBCVER=$(cat ~/.cache/whispix-bootstrap/glibcver)
	GCCVER=$(cat ~/.cache/whispix-bootstrap/gccver)
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
	mount -R /sys $DRAG_ROOT/sys
	mount --make-rslave $DRAG_ROOT/sys
	fi
	if ! mountpoint -q $DRAG_ROOT/dev; then
	mount -R /dev $DRAG_ROOT/dev
	mount --make-rslave $DRAG_ROOT/dev
	fi
	if ! mountpoint -q $DRAG_ROOT/run; then
	mount -B /run $DRAG_ROOT/run
	mount --make-slave $DRAG_ROOT/run
	fi
}

if [ ! -f ~/.cache/whispix-bootstrap/1 ]; then
echo
echo "STAGE 1 - Setup"
echo

chown root:root $DRAG_ROOT
chmod 755 $DRAG_ROOT
cd $DRAG_ROOT

mkdir -pv ./{etc,var,boot,home,mnt,opt,dev,proc,sys,run/lock,root,tmp} \
	./usr/{bin,include,lib/locale,local/{bin,include,lib,lib64,sbin,share,src},sbin,src} \
	./usr/local/share/{doc,info,locale,misc,terminfo,zoneinfo,man/man{1..8}} \
	./usr/lib/firmware ./var/{cache,lib,log,opt,spool,mail,tmp}
ln -sfv usr/bin bin
ln -sfv usr/lib lib
ln -sfv lib usr/lib64
ln -sfv usr/lib lib64
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

	echo "Pinching passwd"
	cat > $DRAG_ROOT/etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
uuidd:x:80:80:uuid daemon user:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
	echo "Pinching group"
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
	echo "Pinching profile"
	cat > $DRAG_ROOT/etc/profile << "EOF"
# /etc/profile

umask 022

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export ashtray=~/.cache/drag/ashtray

EOF
echo "export MAKEFLAGS='"$MAKEFLAGS"'" >> $DRAG_ROOT/etc/profile
	cat >> $DRAG_ROOT/etc/profile << "EOF"

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
swapon -a

. /etc/locale.conf

export LANG LC_ALL LC_COLLATE
hostname "$(cat /etc/hostname)"

#Setup udev
#udevd --daemon
#udevadm trigger
#udevadm settle

#Setup ethernet
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
	echo "Pinching drag"
	cd
	
	echo "Branding Whispix"
	cat > $DRAG_ROOT/etc/os-release << "EOF"
NAME="Whispix Linux"
PRETTY_NAME="Whispix Linux"
ID="whispix"
EOF

touch ~/.cache/whispix-bootstrap/1
fi
if [ ! -f ~/.cache/whispix-bootstrap/2 ]; then
echo
echo "STAGE 2 - Download the Linux kernel, Glibc, and GCC"
echo

rm -rf $DRAG_ROOT/usr/src/linux* $ashtray/glibc $ashtray/gcc

read -p "What Linux kernel version do you wish to use? (eg. 6.12.40) " KRNLVER
read -p "Glibc version? (eg. 2.41) " GLIBCVER
read -p "GCC version?   (eg. 14.2.0) " GCCVER

wget --spider https://ftp.gnu.org/gnu/glibc/glibc-$GLIBCVER.tar.xz
wget --spider https://ftp.gnu.org/gnu/gcc/gcc-$GCCVER/gcc-$GCCVER.tar.xz

cd $DRAG_ROOT/usr/src
wget https://cdn.kernel.org/pub/linux/kernel/v${KRNLVER:0:1}.x/linux-$KRNLVER.tar.xz
tar xJf linux-$KRNLVER.tar.xz
rm linux-$KRNLVER.tar.xz

echo $KRNLVER  > ~/.cache/whispix-bootstrap/krnlver
echo $GLIBCVER > ~/.cache/whispix-bootstrap/glibcver
echo $GCCVER   > ~/.cache/whispix-bootstrap/gccver

touch ~/.cache/whispix-bootstrap/2
fi
if [ ! -f ~/.cache/whispix-bootstrap/3 ]; then
echo
echo "STAGE 3 - Download PKGBUILDs"
echo

rm /usr/bin/snoop
touch /usr/bin/snoop
chmod +x /usr/bin/snoop
stash ${cigs[@]}
cp $DRAG_ROOT/usr/bin/snoop /usr/bin/snoop

cat > ~/.cache/drag/stash/glibc/PKGBUILD << EOF
pkgname=glibc
pkgver=$GLIBCVER

EOF
cat >> ~/.cache/drag/stash/glibc/PKGBUILD << "EOF"
source=("https://ftp.gnu.org/gnu/glibc/glibc-$pkgver.tar.xz")

build() {
cd glibc-$pkgver

rm -rf build
mkdir -p build
cd build

echo "rootsbindir=/usr/sbin" > configparms

../configure --prefix=/usr \
	--disable-werror \
	--enable-kernel=5.4 \
	--enable-stack-protector=strong \
	--disable-nscd
make
}

package() {
cd glibc-$pkgver

make DESTDIR=$pkgdir install

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

rm -rf build
mkdir -p build
cd build

./configure --prefix=/usr \
	LD=ld \
	--enable-languages=c,c++ \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-host-pie \
	--disable-multilib \
	--disable-bootstrap \
	--disable-fixincludes \
	--with-system-zlib
make
}

package() {
cd gcc-$pkgver

make DESTDIR=$pkgdir install
}
EOF

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

touch ~/.cache/whispix-bootstrap/3
fi
if [ ! -f ~/.cache/whispix-bootstrap/4 ]; then
echo
echo "STAGE 4 - Download source"
echo

cigars=(
coreutils
diffutils
file
findutils
grep
gzip
patch
xz
zlib
flex
pkgconf
attr
acl
psmisc
libtool
expat
inetutils
automake
groff
shadow
gdbm
check
wget
)

(cigars2=()
source ~/.cache/drag/stash/coreutils/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/coreutils/coreutils-$pkgver.tar.xz)
source ~/.cache/drag/stash/diffutils/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/diffutils/diffutils-$pkgver.tar.xz)
source ~/.cache/drag/stash/file/PKGBUILD
cigars2+=(https://astron.com/pub/file/file-$pkgver.tar.gz)
source ~/.cache/drag/stash/findutils/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/findutils/findutils-$pkgver.tar.xz)
source ~/.cache/drag/stash/grep/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/grep/grep-$pkgver.tar.xz)
source ~/.cache/drag/stash/gzip/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/gzip/gzip-$pkgver.tar.xz)
source ~/.cache/drag/stash/patch/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/patch/patch-$pkgver.tar.xz)
source ~/.cache/drag/stash/xz/PKGBUILD
cigars2+=(https://github.com//tukaani-project/xz/releases/download/v$pkgver/xz-$pkgver.tar.xz)
source ~/.cache/drag/stash/zlib/PKGBUILD
cigars2+=(https://zlib.net/fossils/zlib-$pkgver.tar.gz)
source ~/.cache/drag/stash/flex/PKGBUILD
cigars2+=(https://github.com/westes/flex/releases/download/v$pkgver/flex-$pkgver.tar.gz)
source ~/.cache/drag/stash/pkgconf/PKGBUILD
cigars2+=(https://distfiles.ariadne.space/pkgconf/pkgconf-$pkgver.tar.xz)
source ~/.cache/drag/stash/attr/PKGBUILD
cigars2+=(https://download.savannah.gnu.org/releases/attr/attr-$pkgver.tar.gz)
source ~/.cache/drag/stash/acl/PKGBUILD
cigars2+=(https://download.savannah.gnu.org/releases/acl/acl-$pkgver.tar.xz)
source ~/.cache/drag/stash/psmisc/PKGBUILD
cigars2+=(https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-$pkgver.tar.xz)
source ~/.cache/drag/stash/libtool/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/libtool/libtool-${pkgver%%+*}.tar.xz)
source ~/.cache/drag/stash/expat/PKGBUILD
cigars2+=(https://prdownloads.sourceforge.net/expat/expat-$pkgver.tar.xz)
source ~/.cache/drag/stash/inetutils/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/inetutils/inetutils-$pkgver.tar.xz)
source ~/.cache/drag/stash/automake/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/automake/automake-$pkgver.tar.xz)
source ~/.cache/drag/stash/groff/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/groff/groff-$pkgver.tar.gz)
source ~/.cache/drag/stash/shadow/PKGBUILD
cigars2+=(https://github.com/shadow-maint/shadow/releases/download/$pkgver/shadow-$pkgver.tar.xz)
source ~/.cache/drag/stash/gdbm/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/gdbm/gdbm-$pkgver.tar.gz)
source ~/.cache/drag/stash/check/PKGBUILD
cigars2+=(https://github.com/libcheck/check/releases/download/$pkgver/check-$pkgver.tar.gz)
source ~/.cache/drag/stash/wget/PKGBUILD
cigars2+=(https://ftp.gnu.org/gnu/wget/wget-$pkgver.tar.gz)

for ((i=0; i<${#cigars[@]}; i++)); do
	mkdir -p $ashtray/${cigars[$i]}/src
	cd $ashtray/${cigars[$i]}/src
	wget -nc ${cigars2[$i]}
	for file in *; do
		if [ $file == *.tar.xz ]; then
			tar xJf $file || (rm $file && echo "Please re-run the script.")
		elif [ $file == *.tar.gz ]; then
			tar xzf $file || (rm $file && echo "Please re-run the script.")
		fi
	done
done)

for i in ${cigs[@]}; do
        if ! printf "%s\n" "${cigars[@]}" | grep -wq "$i"; then
		pinch $i
        fi
done

touch ~/.cache/whispix-bootstrap/4
fi
if [ ! -f ~/.cache/whispix-bootstrap/5 ]; then
echo
echo "STAGE 5 - binutils pass 1"
echo

cd $ashtray/binutils/src/binutils*/

rm -rf build
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

touch ~/.cache/whispix-bootstrap/5
fi
if [ ! -f ~/.cache/whispix-bootstrap/6 ]; then
echo
echo "STAGE 6 - GCC pass 1"
echo

cd $ashtray/gcc/src/gcc*/
tar xJf $ashtray/mpfr/src/mpfr*.tar.xz
lzip -cd $ashtray/gmp/src/gmp*.tar.lz | tar xf -
tar xzf $ashtray/libmpc/src/mpc*.tar.gz
rm -rf mpfr
rm -rf gmp
rm -rf mpc
mv mpfr*/ mpfr
mv gmp*/ gmp
mv mpc*/ mpc

rm -rf build
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
	--disable-multilib \
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

touch ~/.cache/whispix-bootstrap/6
fi
if [ ! -f ~/.cache/whispix-bootstrap/7 ]; then
echo
echo "STAGE 7 - Linux headers"
echo

cd $DRAG_ROOT/usr/src/linux-$KRNLVER
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -r usr/include $DRAG_ROOT/usr

touch ~/.cache/whispix-bootstrap/7
fi
if [ ! -f ~/.cache/whispix-bootstrap/8 ]; then
echo
echo "STAGE 8 - Glibc"
echo

cd $ashtray/glibc/src/glibc*/

rm -rf build
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

touch ~/.cache/whispix-bootstrap/8
fi
if [ ! -f ~/.cache/whispix-bootstrap/9 ]; then
echo
echo "STAGE 9 - libstdc++"
echo

cd $ashtray/gcc/src/gcc*/

rm -rf build
mkdir -p build
cd build

../libstdc++-v3/configure --host=$TGT \
	--build=$(../config.guess) \
	--prefix=/usr \
	--disable-multilib \
	--disable-nls \
	--disable-libstdcxx-pch \
	--with-gxx-include-dir=/tools/$TGT/include/c++/$GCCVER
make
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/lib{stdc++{,exp,fs},supc++}.la

touch ~/.cache/whispix-bootstrap/9
fi
if [ ! -f ~/.cache/whispix-bootstrap/10 ]; then
echo
echo "STAGE 10 - m4"
echo

cd $ashtray/m4/src/m4*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

pinch m4

touch ~/.cache/whispix-bootstrap/10
fi
if [ ! -f ~/.cache/whispix-bootstrap/11 ]; then
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
ln -s libncursesw.so $DRAG_ROOT/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $DRAG_ROOT/usr/include/curses.h

touch ~/.cache/whispix-bootstrap/11
fi
if [ ! -f ~/.cache/whispix-bootstrap/12 ]; then
echo
echo "STAGE 12 - bash"
echo

cd $ashtray/bash/src/bash*/

./configure --prefix=/usr --host=$TGT --build=$(sh support/config.guess) --without-bash-malloc
make
make DESTDIR=$DRAG_ROOT install
ln -s bash $DRAG_ROOT/bin/sh

touch ~/.cache/whispix-bootstrap/12
fi
if [ ! -f ~/.cache/whispix-bootstrap/13 ]; then
echo
echo "STAGE 13 - coreutils"
echo

cd $ashtray/coreutils/src/coreutils/

[ -d $ashtray/pkgconf/src/pkgconf ] || pinch pkgconf
cp $ashtray/pkgconf/src/pkgconf*/pkg.m4 /usr/share/aclocal/pkg.m4

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess) --enable-install-program=hostname --enable-no-install-program=kill,uptime
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/13
fi
if [ ! -f ~/.cache/whispix-bootstrap/14 ]; then
echo
echo "STAGE 14 - diffutils"
echo

cd $ashtray/diffutils/src/diffutils/

export CFLAGS="-Wno-error"
./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess) gl_cv_func_strcasecmp_works=y
make
make DESTDIR=$DRAG_ROOT install
unset CFLAGS

touch ~/.cache/whispix-bootstrap/14
fi
if [ ! -f ~/.cache/whispix-bootstrap/15 ]; then
echo
echo "STAGE 15 - file"
echo

cd $ashtray/file/src/file/

mkdir -p build
cd build
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make
cd $ashtray/file/src/file/

./configure --prefix=/usr --host=$TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/libmagic.la

touch ~/.cache/whispix-bootstrap/15
fi
if [ ! -f ~/.cache/whispix-bootstrap/16 ]; then
echo
echo "STAGE 16 - findutils"
echo

cd $ashtray/findutils/src/findutils/

./configure --prefix=/usr --localstatedir=/var/lib/locate --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/16
fi
if [ ! -f ~/.cache/whispix-bootstrap/17 ]; then
echo
echo "STAGE 17 - gawk"
echo

cd $ashtray/gawk/src/gawk*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/17
fi
if [ ! -f ~/.cache/whispix-bootstrap/18 ]; then
echo
echo "STAGE 18 - grep"
echo

cd $ashtray/grep/src/grep/

./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/18
fi
if [ ! -f ~/.cache/whispix-bootstrap/19 ]; then
echo
echo "STAGE 19 - gzip"
echo

cd $ashtray/gzip/src/gzip/

./configure --prefix=/usr --host=$TGT
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/19
fi
if [ ! -f ~/.cache/whispix-bootstrap/20 ]; then
echo
echo "STAGE 20 - make"
echo

cd $ashtray/make/src/make*/

./configure --prefix=/usr --host=$TGT --without-guile --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/20
fi
if [ ! -f ~/.cache/whispix-bootstrap/21 ]; then
echo
echo "STAGE 21 - patch"
echo

cd $ashtray/patch/src/patch/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/21
fi
if [ ! -f ~/.cache/whispix-bootstrap/22 ]; then
echo
echo "STAGE 22 - sed"
echo

cd $ashtray/sed/src/sed*/

./configure --prefix=/usr --host=$TGT --build=$(./build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/22
fi
if [ ! -f ~/.cache/whispix-bootstrap/23 ]; then
echo
echo "STAGE 23 - tar"
echo

cd $ashtray/tar/src/tar*/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess)
make
make DESTDIR=$DRAG_ROOT install

touch ~/.cache/whispix-bootstrap/23
fi
if [ ! -f ~/.cache/whispix-bootstrap/24 ]; then
echo
echo "STAGE 24 - xz"
echo

cd $ashtray/xz/src/xz/

./configure --prefix=/usr --host=$TGT --build=$(build-aux/config.guess) --disable-static
make
make DESTDIR=$DRAG_ROOT install
rm -f $DRAG_ROOT/usr/lib/liblzma.la

touch ~/.cache/whispix-bootstrap/24
fi
if [ ! -f ~/.cache/whispix-bootstrap/25 ]; then
echo
echo "STAGE 25 - binutils pass 2"
echo

cd $ashtray/binutils/src/binutils*/
sed '6031s/$add_dir//' -i ltmain.sh

rm -rf build
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

cd $ashtray
pinch binutils

touch ~/.cache/whispix-bootstrap/25
fi
if [ ! -f ~/.cache/whispix-bootstrap/26 ]; then
echo
echo "STAGE 26 - GCC pass 2"
echo

cd $ashtray/gcc/src/gcc*/
tar xJf $ashtray/mpfr/src/mpfr*.tar.xz
lzip -cd $ashtray/gmp/src/gmp*.tar.lz | tar xf -
tar xzf $ashtray/libmpc/src/mpc*.tar.gz
rm -rf mpfr
rm -rf gmp
rm -rf mpc
mv mpfr*/ mpfr
mv gmp*/ gmp
mv mpc*/ mpc
sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

rm -rf build
mkdir -p build
cd build

../configure --build=$(../config.guess) \
	--host=$TGT \
	--target=$TGT \
	LDFLAGS_FOR_TARGET=-L$PWD/$TGT/libgcc \
	--prefix=/usr \
	CC_FOR_TARGET=$TGT-gcc \
	--with-build-sysroot=$DRAG_ROOT \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-initfini-array \
	--disable-nls \
	--disable-multilib \
	--disable-libatomic \
	--disable-libgomp \
	--disable-libquadmath \
	--disable-libsanitizer \
	--disable-libssp \
	--disable-libvtv \
	--enable-languages=c,c++
make
make DESTDIR=$DRAG_ROOT install
ln -s gcc $DRAG_ROOT/usr/bin/cc

cd $ashtray
pinch gcc

touch ~/.cache/whispix-bootstrap/26
fi
if [ ! -f ~/.cache/whispix-bootstrap/27 ]; then
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

touch ~/.cache/whispix-bootstrap/27
fi
if [ ! -f ~/.cache/whispix-bootstrap/28 ]; then
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

touch ~/.cache/whispix-bootstrap/28
fi
if [ ! -f ~/.cache/whispix-bootstrap/29 ]; then
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

touch ~/.cache/whispix-bootstrap/29
fi
if [ ! -f ~/.cache/whispix-bootstrap/30 ]; then
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

touch ~/.cache/whispix-bootstrap/30
fi
if [ ! -f ~/.cache/whispix-bootstrap/31 ]; then
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

touch ~/.cache/whispix-bootstrap/31
fi
if [ ! -f ~/.cache/whispix-bootstrap/32 ]; then
echo
echo "STAGE 32 util-linux"
echo

(source ~/.cache/drag/stash/util-linux/PKGBUILD
cd $ashtray/util-linux/src
wget -nc https://kernel.org/pub/linux/utils/util-linux/v${pkgver%.*}/util-linux-$pkgver.tar.xz
tar xJf util-linux-$pkgver.tar.xz)

tmpfsmount
chroot $DRAG_ROOT /bin/bash -c "
source /etc/profile
cd $ashtray/util-linux/src/util-linux-*/
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
"

rm -rf $ashtray/util-linux/src/util-linux-*/

touch ~/.cache/whispix-bootstrap/32
fi
if [ ! -f ~/.cache/whispix-bootstrap/33 ]; then
echo
echo "STAGE 33 - Hotbox"
echo

echo "Note:"
echo "You may find yourself needing to edit and correct some of the PKGBUILD instructions on this stage."
echo "To edit PKGBUILDs, use the snoop command."
echo

rm -rf /mnt/whispix/tools

echo "smoke ${cigs[@]}" > /mnt/whispix/root/.cache/hotbox
chmod +x /mnt/whispix/root/.cache/hotbox

tmpfsmount
chroot $DRAG_ROOT /bin/env -i cigs=$cigs /bin/bash -c "
source /etc/profile
~/.cache/hotbox
"

touch ~/.cache/whispix-bootstrap/33
fi

echo
echo "Done!"
