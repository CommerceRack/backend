
##
## 201407 BUILD process
##
# using a standard centos box
##

yum -y install yum-plugin-fastestmirror
yum install -y git

useradd -u 1000 commercerack



## similiar to tinydns, etc. we use a root level directory to minimize stat calls to the root fs
## /backend is the path for the main server.
mkdir -p /backend
cd /
git clone https://github.com/commercerack/backend.git
cd /backend/
git clone https://github.com/commercerack/backend-static.git
ln -s backend-static static


## set MOTD
rm /etc/motd
ln -s /backend/platform/etc-motd /etc/motd

echo "/usr/local/lib" > /etc/ld.so.conf.d/usr-local-lib.conf
ldconfig

ln -sf /usr/share/zoneinfo/US/Pacific-New /etc/localtime


##
## RPM forge
##
rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
yum -y install htop

##
## ELRepo
##
#rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
### CENTOS 6:
#rpm -Uvh http://www.elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm
### CENTOS 7:
#rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm (external link)

## Fedora Extras (centos 6)
yum -y install http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
## https://dl.fedoraproject.org/pub/epel/beta/7/x86_64/epel-release-7-0.2.noarch.rpm

## we don't need ip forwarding anymore
#modify /etc/rc.d/rc.local set 
#	echo 1 > /proc/sys/net/ipv4/ip_forward


#===========================================
## INSTALL ZFS
#===========================================
yum -y install rpm-build kernel-devel zlib-devel libuuid-devel libblkid-devel libselinux-devel  e2fsprogs-devel parted lsscsi
yum -y localinstall --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release-1-3.el6.noarch.rpm
yum -y localinstall --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release$(rpm -E %dist).noarch.rpm


## instructions for ZFS on Linux are here: http://zfsonlinux.org/epel.html
# yum localinstall --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release-1-3.el6.noarch.rpm
#sudo yum -y localinstall --nogpgcheck http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
#sudo yum -y localinstall --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release$(rpm -E %dist).noarch.rpm

yum -y install wget zlib-devel e2fsprogs-devel libuuid-devel libblkid-devel bc lsscsi mdadm parted mailx
yum -y groupinstall "Development Tools"
yum -y update
yum -y install zfs
reboot



## for iostat
yum -y install systat
yum -y install help2man texinfo libtool asciidoc

#===========================================
##  
#===========================================
yum -y install cronie ftp postfix openssh openssl openssh-clients rdist ntpdate gcc make postfix mailx telnet openssh man wget
yum -y install libtool-ltdl-devel glibc-devel apr-devel apr-util-devel aspell-devel binutils-devel bison-devel boost-devel boost-mpich2-devel boost-openmpi-devel 
yum -y install inotify-tools incrond vixie-cron
yum -y update


## 
cat >> /etc/crontab 
# run-parts 
01 * * * * root run-parts /etc/cron.hourly 
02 4 * * * root run-parts /etc/cron.daily 
22 4 * * 0 root run-parts /etc/cron.weekly 
42 4 1 * * root run-parts /etc/cron.monthly
^D

ln -s /backend/platform/cron/weekly /etc/cron.weekly/commercerack.weekly
ln -s /backend/platform/cron/monthly /etc/cron.monthly/commercerack.monthly

yum -y install bzip2-devel expat-devel expect-devel freetype-devel gd-devel gdbm-devel

yum -y install glibc-devel.i686 gmp-devel gnutls-devel gpm-devel gsm-devel iso-codes-devel.noarch libIDL-devel libc-client-devel \
	libcurl-devel libdaemon-devel libdbi-devel libdc1394-devel libdhash-devel libdiscid-devel libdmx-devel libdrm-devel \
	libdv-devel libdvdread-devel libedit-devel libesmtp-devel libevent-devel libexif-devel libffi-devel libfontenc-devel libicu-devel libidn-devel \
   libjpeg-devel libksba-devel libldb-devel libmemcached-devel libmng-devel libmpcdec-devel libnl-devel libpng-devel libstdc++-devel.i686 libstdc++-devel \
   libtalloc-devel.i686 libtalloc-devel libtar-devel libtasn1-devel libtdb-devel libtevent-devel libtidy-devel libtiff-devel libuuid-devel libvorbis-devel 

yum -y install \
 libxml2-devel libxslt-devel libzip-devel log4cpp-devel lua-devel lzo-devel memcached-devel mpfr-devel ncurses-devel \
 openjpeg-devel openmpi-devel openssl-devel pcre-devel perl-devel uuid-devel zlib-devel git rsync jwhois \
 tcpdump iotop bind-utils asciidoc libatomic libatomic_ops-devel openssl-devel perl perl-ExtUtils-MakeMaker perl-ExtUtils-ParseXS perl-Module-Pluggable \
 perl-Pod-Escapes perl-Pod-Simple perl-Test-Harness perl-devel perl-libs perl-version openssl-perl perl-Algorithm-Diff.noarch perl-AppConfig.noarch perl-Archive-Extract 

yum -y install \
 perl-Archive-Tar perl-Archive-Zip.noarch perl-Authen-SASL.noarch perl-B-Keywords.noarch perl-BSD-Resource perl-Bit-Vector perl-CGI perl-CPAN perl-CPANPLUS \
 perl-CSS-Tiny.noarch perl-Cache-Memcached.noarch perl-Carp-Clan.noarch perl-Class-Accessor.noarch perl-Class-Data-Inheritable.noarch perl-Class-Inspector.noarch \
 perl-Class-MethodMaker perl-Class-Singleton.noarch perl-Class-Trigger.noarch perl-Clone perl-Compress-Raw-Bzip2 \
 perl-Compress-Raw-Zlib perl-Compress-Zlib perl-Config-General.noarch perl-Config-Simple.noarch perl-Config-Tiny.noarch \
 perl-Convert-ASN1.noarch perl-Convert-BinHex.noarch perl-Crypt-OpenSSL-Bignum perl-Crypt-OpenSSL-RSA perl-Crypt-OpenSSL-Random \
 perl-Crypt-PasswdMD5.noarch perl-Crypt-SSLeay perl-DBD-MySQL perl-DBI perl-DBIx-Simple.noarch \
 perl-Data-OptList.noarch perl-Date-Calc.noarch perl-Date-Manip.noarch perl-DateTime perl-DateTime-Format-DateParse.noarch \
 perl-DateTime-Format-Mail.noarch perl-DateTime-Format-W3CDTF.noarch perl-Devel-Cover perl-Devel-Cycle.noarch perl-Devel-Leak \
 perl-Devel-StackTrace.noarch perl-Devel-Symdump.noarch perl-Digest-BubbleBabble.noarch perl-Digest-HMAC.noarch perl-Digest-SHA \
 perl-Digest-SHA1 perl-Email-Date-Format.noarch perl-Encode-Detect perl-Error.noarch perl-Exception-Class.noarch \
 perl-ExtUtils-CBuilder perl-ExtUtils-Embed perl-ExtUtils-MakeMaker-Coverage.noarch perl-File-Copy-Recursive.noarch perl-File-Fetch \
 perl-File-Find-Rule.noarch perl-File-Find-Rule-Perl.noarch perl-File-HomeDir.noarch perl-File-Remove.noarch perl-File-Slurp.noarch \
 perl-File-Which.noarch perl-File-pushd.noarch perl-Font-AFM.noarch perl-Font-TTF.noarch perl-FreezeThaw.noarch \
 perl-GD perl-GD-Barcode.noarch perl-GDGraph.noarch perl-GDGraph3d.noarch perl-GDTextUtil.noarch \
 perl-GSSAPI perl-Git.noarch perl-HTML-Format.noarch perl-HTML-Parser perl-HTML-Tagset.noarch \
 perl-HTML-Tree.noarch perl-IO-Compress-Base perl-IO-Compress-Bzip2 perl-IO-Compress-Zlib perl-IO-Socket-INET6.noarch \
 perl-IO-Socket-SSL.noarch perl-IO-String.noarch perl-IO-Tty perl-IO-Zlib perl-IO-stringy.noarch \
 perl-IPC-Cmd perl-IPC-Run.noarch perl-IPC-Run3.noarch perl-JSON.noarch perl-LDAP.noarch \
 perl-List-MoreUtils perl-Locale-Maketext-Gettext.noarch perl-Locale-Maketext-Simple perl-Locale-PO.noarch perl-Log-Message \
 perl-Log-Message-Simple perl-MIME-Lite.noarch perl-MIME-Types.noarch perl-MIME-tools.noarch perl-Mail-DKIM.noarch \
 perl-MailTools.noarch perl-Makefile-DOM.noarch perl-Makefile-Parser.noarch perl-Module-Build perl-Module-CoreList \
 perl-Module-Find.noarch perl-Module-Info.noarch perl-Module-Install.noarch perl-Module-Load perl-Module-Load-Conditional \
 perl-Module-Loaded perl-Module-ScanDeps.noarch perl-Mozilla-LDAP perl-Net-DNS perl-Net-DNS-Nameserver \
 perl-Net-IP.noarch perl-Net-LibIDN perl-Net-SMTP-SSL.noarch perl-Net-SSLeay perl-Net-Telnet.noarch \
 perl-Net-XMPP.noarch perl-NetAddr-IP perl-Number-Compare.noarch perl-Object-Accessor perl-Object-Deadly.noarch \
 perl-PAR-Dist.noarch perl-Package-Constants perl-Package-Generator.noarch perl-Params-Check perl-Params-Util \
 perl-Params-Validate perl-Parse-CPAN-Meta perl-Parse-RecDescent.noarch perl-Parse-Yapp.noarch perl-Perl-Critic.noarch \
 perl-Perl-MinimumVersion.noarch perl-Perlilog.noarch perl-Pod-Coverage.noarch perl-Pod-POM.noarch perl-Pod-Spell.noarch \
 perl-Probe-Perl.noarch perl-Readonly.noarch perl-Readonly-XS perl-SNMP_Session.noarch perl-SOAP-Lite.noarch \
 perl-Socket6 perl-Spiffy.noarch perl-String-CRC32 perl-String-Format.noarch perl-Sub-Exporter.noarch \
 perl-Sub-Install.noarch perl-Sub-Uplevel.noarch perl-Syntax-Highlight-Engine-Kate.noarc perl-Sys-Guestfs perl-Sys-Virt \
 perl-Taint-Runtime perl-Task-Weaken.noarch perl-TeX-Hyphen.noarch perl-Template-Toolkit perl-Term-ProgressBar.noarch \
 perl-Term-UI perl-TermReadKey perl-Test-Base.noarch perl-Test-CPAN-Meta.noarch perl-Test-ClassAPI.noarch \
 perl-Test-Deep.noarch perl-Test-Differences.noarch perl-Test-Exception.noarch perl-Test-Inter.noarch perl-Test-Manifest.noarch \
 perl-Test-Memory-Cycle.noarch perl-Test-MinimumVersion.noarch perl-Test-MockObject.noarch perl-Test-NoWarnings.noarch perl-Test-Object.noarch \
 perl-Test-Output.noarch perl-Test-Perl-Critic.noarch perl-Test-Pod.noarch perl-Test-Pod-Coverage.noarch perl-Test-Prereq.noarch \
 perl-Test-Script.noarch perl-Test-Simple perl-Test-Spelling.noarch perl-Test-SubCalls.noarch perl-Test-Taint \
 perl-Test-Tester.noarch perl-Test-Warn.noarch perl-Text-Autoformat.noarch perl-Text-Diff.noarch perl-Text-Glob.noarch \
 perl-Text-Iconv perl-Text-PDF.noarch perl-Text-Reform.noarch perl-Text-Unidecode.noarch perl-Tie-IxHash.noarch \
 perl-Time-HiRes perl-Time-Piece perl-Time-modules.noarch perl-TimeDate.noarch perl-Tree-DAG_Node.noarch \
 perl-UNIVERSAL-can.noarch perl-UNIVERSAL-isa.noarch perl-URI.noarch perl-Unicode-Map8 perl-Unicode-String \
 perl-WWW-Curl perl-XML-DOM.noarch perl-XML-DOM-XPath.noarch perl-XML-Dumper.noarch perl-XML-Filter-BufferText.noarch \
 perl-XML-Grove.noarch perl-XML-LibXML perl-XML-LibXSLT perl-XML-NamespaceSupport.noarch perl-XML-Parser \
 perl-XML-RSS.noarch perl-XML-RegExp.noarch perl-XML-SAX.noarch perl-XML-SAX-Writer.noarch perl-XML-Simple.noarch \
 perl-XML-Stream.noarch perl-XML-TokeParser.noarch perl-XML-TreeBuilder.noarch perl-XML-Twig.noarch perl-XML-Writer.noarch \
 perl-XML-XPath.noarch perl-XML-XPathEngine.noarch perl-YAML.noarch perl-YAML-Syck perl-YAML-Tiny.noarch

yum -y install perl-core perl-devel perl-hivex perl-libintl perl-libs
yum -y install perl-libwww-perl.noarch perl-libxml-perl.noarch
yum -y install postfix-perl-scripts

yum -y install git-svn.noarch					## svn compatibility required for v8 javascript engine
yum -y install gcc-c++ gcc-objc++	 ## required for v8
yum -y install autoconf autoconf213.noarch		## for spidermonkey (and possibly others)
yum -y install zip								## for spidermonkey
yum -y install pciutils							## for hp monitoring
yum -y install unzip
yum -y install patch
yum -y install lua lua-devel lua-static lua-wsapi lua-sql-mysql readline-devel
yum -y install yum-plugin-fastestmirror

##
## JOE
##
yum -y install wget
cd /usr/local/src
wget 'http://downloads.sourceforge.net/project/joe-editor/JOE%20sources/joe-3.7/joe-3.7.tar.gz'
tar -xzvf joe-3.7.tar.gz
cd joe-3.7
./configure
make install
##scp 192.168.2.141:/usr/local/etc/joe/* /usr/local/etc/joe/

##
## we use openresty to get a lot of modules for nginx, but we don't install them all. (NOT ANYMORE)
##
##cd /usr/local/src;
##wget http://openresty.org/download/ngx_openresty-1.5.8.1.tar.gz;
##tar -xzvf ngx_openresty-1.5.8.1.tar.gz; cd ngx_openresty-1.5.8.1;
##./configure;

cd /usr/local/src/
wget http://nginx.org/download/nginx-1.6.0.tar.gz; tar -xzvf nginx-1.6.0.tar.gz; cd nginx-1.6.0;
## wget http://nginx.org/download/nginx-1.5.13.tar.gz; tar -xzvf nginx-1.5.13.tar.gz; cd nginx-1.5.13;
## wget http://nginx.org/download/nginx-1.5.9.tar.gz; tar -xzvf nginx-1.5.9.tar.gz; cd nginx-1.5.9
## cd /usr/local/src/nginx-1.5.9
## wget http://nginx.org/patches/patch.spdy-v31.txt
## patch -p1 < patch.spdy-v31.txt
## THIS PATCH NO LONGER WORKS:
## patch -p1 < ../nginx_upstream_check_module/check_1.2.6+.patch


## note: removed --without-http-cache --with-proxy
## 	--with-http_ssl_module \		## not needed
cd /usr/local/src/nginx-1.6.0
./configure --with-http_ssl_module --with-http_gunzip_module --with-http_gzip_static_module --without-http_ssi_module   \
	--without-http_userid_module --without-http_access_module --without-http_auth_basic_module \ 
	--without-http_autoindex_module --without-http_geo_module \
	--without-http_map_module --with-http_perl_module --with-perl=/usr/bin/perl \
	--with-pcre --with-pcre-jit --with-libatomic  \
 	--with-http_spdy_module \
	--with-pcre-jit 
#	--add-module=../ngx_openresty-1.5.8.1/bundle/auth-request-nginx-module-0.2 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/echo-nginx-module-0.51 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/headers-more-nginx-module-0.25 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/ngx_coolkit-0.2rc1 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/ngx_devel_kit-0.2.19 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/redis-nginx-module-0.3.7 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/redis2-nginx-module-0.10 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/set-misc-nginx-module-0.24 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/srcache-nginx-module-0.25 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/memc-nginx-module-0.14 
#	--with-openssl=../openssl-1.0.1e \
#	--add-module=../nginx_upstream_check_module  \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/ngx_lua-0.9.2 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/LuaJIT-2.0.2 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-lock-0.01 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-memcached-0.12 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-5.1.5 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-cjson-1.0.3 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-redis-parser-0.10 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-redis-0.17 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-string-0.08 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-upload-0.09 \
#	--add-module=../ngx_openresty-1.5.8.1/bundle/lua-resty-websocket-0.02 

make -j2
make install


## raise the number of file descriptors
cat >> /etc/security/limits.conf
nginx       soft    nofile   10000
nginx       hard    nofile  30000
^D

ln -s /backend/platform/etc-init.d-nginx /etc/init.d/nginx
cd /usr/local/nginx/conf
rm nginx.conf
ln -s /backend/platform/nginx/certs/ /usr/local/nginx
ln -s /backend/platform/nginx/conf/nginx.conf .
ln -s /backend/platform/nginx/conf/commercerack-locations.conf .
mkdir vhosts




yum install memcached
/sbin/chkconfig --add memcached
service memcached start


## we don't use this anymore.
## yum -y install gitolite gitolite3

##
## 
## SOLARIS REQUIRES libpng
#cd /usr/local/src
## wget http://downloads.sourceforge.net/project/libpng/libpng16/1.6.1/libpng-1.6.1.tar.gz
## wget http://sourceforge.net/projects/libpng/files/libpng16/1.6.2/libpng-1.6.2.tar.gz
#wget http://sourceforge.net/projects/libpng/files/libpng16/1.6.6/libpng-1.6.6.tar.gz
#tar -xzvf libpng-1.6.6.tar.gz
#cd libpng-1.6.6
#./configure --with-gnu-ld --enable-shared
#make install
#cd /usr/local/lib/
### BUG FIXED IN 1.6
##ln -s libpng15.so.15. libpng15.so.15



##
## IMAGEMAGICK
##
yum -y install ImageMagick ImageMagick-perl
## wget http://www.imagemagick.org/download/ImageMagick-6.8.3-1.tar.gz
## wget http://www.imagemagick.org/download/ImageMagick-6.8.4-10.tar.gz
#cd /usr/local/src
#wget http://www.imagemagick.org/download/ImageMagick.tar.gz
#tar -xzvf ImageMagick.tar.gz
#cd ImageMagick-6.8.*
#./configure --enable-shared=yes  --with-gnu-ld=yes  --with-quantum-depth=16  --with-bzlib=yes  \
#	--with-fontconfig=yes --with-freetype=yes --with-jpeg=yes \
#	--with-perl=yes --with-tiff=no  --with-x=no  --with-windows-font-dir=/httpd/fonts --with-png=yes \
#	--with-lzma=yes --with-zlib=yes
#make install
yum install -y ImageMagick ImageMagick-devel


##
## ELASTICSEARCH 
##
yum -y install java-1.7.0-openjdk java-1.7.0-openjdk-devel  java-1.7.0-openjdk-javadoc java-1.7.0-openjdk-src
yum -y install https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.2.1.noarch.rpm


# wget http://search.cpan.org/CPAN/authors/id/M/MI/MIYAGAWA/PSGI-1.102.tar.gz
# http://lists.unbit.it/pipermail/uwsgi/2013-November/006649.html
#cpanm install PSGI

##
## CPAN Minus is amazing, and a great way to install perl stuff
##
yum install -y perl-devel perl-CPAN
curl -L http://cpanmin.us | perl - --sudo App::cpanminus


##
## uWSGi is our application signaling layer.
##
cpanm Coro
yum -y python-devel
cd /usr/local/src
wget http://projects.unbit.it/downloads/uwsgi-latest.tar.gz
tar -xvzf uwsgi-latest.tar.gz
cd uwsgi-2.0.*
python uwsgiconfig.py --build psgi --build coroae
## --build v8 ??
## mv uwsgi /httpd/bin/uwsgi.`arch`
cp uwsgi /usr/local/bin/uwsgi
ln -s /backend/platform/etc-init.d-uwsgi /etc/init.d/uwsgi



#there's some gotchas  on solaris:
## * 1. need to pull latest from github
## * 2. need to edit build.ini, comment out a ton of stuff (check hoth)
#-----

yum -y install dpkg
## if the command above doesn't work -- try this:
## THANKS TO: http://charlesleaver.com/2012/04/start-stop-daemon-on-centosrhel/
#cd /usr/local/src
#wget http://ftp.de.debian.org/debian/pool/main/d/dpkg/dpkg_1.16.10.tar.xz
#xz -d dpkg_1.16.10.tar.xz
#tar -xvf dpkg_1.16.10.tar
#cd dpkg-1.16.10/
#./configure --disable-install-info --disable-update-alternatives --disable-dselect
#make && make install



##
## CDB
##
## a few random files are still stored/compiled into .cdb format
##
cd /usr/local/src
wget http://cr.yp.to/cdb/cdb-0.75.tar.gz
tar -xzvf cdb-0.75.tar.gz
cd cdb-0.75
if [ `/bin/uname -m` == 'x86_64' ] ; then
	echo "gcc -O3 -m64 -include /usr/include/errno.h" > conf-cc
else 
	echo "gcc -O3 -m32 -include /usr/include/errno.h" > conf-cc
fi
make setup check
## NOTE: to fix a bad build use rm -Rf *.o
## make setup check
./install		## does this even do anythign?


##
## Redis
##
yum -y install redis
cd /usr/local/src/
wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar -xzvf redis-2.6.16.tar.gz
cd redis-2.6.16
make install

rm /usr/sbin/redis-server
ln -s /usr/local/bin/redis-server /usr/sbin/redis-server
#yum -y install hiredis hiredis-devel
/sbin/chkconfig --add redis
service redis start
ln -s /backend/platform/redis/redis.conf /etc/redis.conf
rm -Rf /var/lib/redis/dump.rdb
mkdir -p /local/redis
ln -s /var/lib/redis /local/redis
ln -s /var/lib/redis/redis.sock /var/run/redis.sock

## LIBREDIS
## 
## a developer interface to redis.
##
cd /usr/local/src
git clone git://github.com/toymachine/libredis.git
cd libredis
make
./use_release.sh	## this will throw an error 
/bin/cp lib/libredis.so /usr/local/lib
ldconfig


## GET NFS WORKING:
##
## you only need NFS if you're planning to have multiple instances servicing a single with non-distributed files.
##	(in other words- you probably don't need this)
##
#yum -y install nfs-utils keyutils nfs-utils-lib rpc-bind libgssglue libtirpc
#service rpcbind start


# to simplify the perl modules - just run:
/backend/platform/perl-setup.sh 


#rm /usr/local/lib/libpari*
#cd /usr/local/src
#wget http://search.cpan.org/CPAN/authors/id/I/IL/ILYAZ/modules/Math-Pari-2.01080605.tar.gz
#tar -xzvf Math-Pari-2.01080605.tar.gz
#cd Math-Pari*
#perl Makefile.PL force_download
#make install




#   CLUSTER=`/root/configs/platform.pl show=cluster`
#   ## verify mount points 
#   if [[ ! -z "$CLUSTER" ]] ; then
#	/httpd/bin/apachectl stop
#	killall -9 httpd
#	sleep 1
#	umount /remote/$CLUSTER/users
#      #/bin/mount -t nfs $CLUSTER:/data/users-$CLUSTER /remote/$CLUSTER/users \
#      #  -O defaults,hard,udp,rsize=8192,wsize=8192,nfsvers=3,intr,noatime
#      /bin/mount -t nfs $CLUSTER:/data/users-$CLUSTER /remote/$CLUSTER/users -O "defaults,hard,udp,rsize=8192,wsize=8192,nfsvers=3,intr,noatime"
#   fi

##
## if you plan to use buy.com make sure you open a support ticket letting us know your public ip address.
## buy.com requires an active ftp connection which is very difficult to do out of AWS since it requires opening
## of many ports, and it's very insecure. we have an active/passive gateway.
##
cat >> /etc/hosts
184.72.58.88   trade.marketplace.buy.com
^D


--------------------------------

##
## ZERO MQ
##
cd /usr/local/src
wget http://download.zeromq.org/zeromq-3.2.2.tar.gz
tar -xzvf zeromq-3.2.2.tar.gz
cd zeromq-3.2.2
./configure
make
make install
ldconfig

yum -y install yum;

##
## NAGIOS
##
#cd /usr/local/src
#wget http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.16.tar.gz
#tar -xzvf nagios-plugins-1.4.16.tar.gz
#cd nagios-plugins-1.4.16
#./configure --enable-perl-modules --with-openssl=/usr/include/openssl
#make
#make install
## yum -y install nagios-plugins nagios-plugins-disk nagios-plugins-mysql nagios-plugins-load nagios-plugins-tcp nagios-plugins-icmp nagios-plugins-http
yum -y nagios-plugins
yum -y install sysstat



# cd /usr/local
# rm -Rf elasticsearch*
# rm -f /etc/init.d/elasticsearch
 
# ## wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.0.1.noarch.rpm
# ## rpm --install elasticsearch-1.0.1.noarch.rpm
#cd /root
#wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.1.noarch.rpm
#rpm --install elasticsearch-1.3.1.noarch.rpm
 
## you might need to change the values below to something sane:
rm -f /etc/elasticsearch.yml
echo "node.max_local.storage_nodes: 1" >> /etc/elasticsearch/elasticsearch.yml
echo "index.number_of_replicas: 0" >> /etc/elasticsearch/elasticsearch.yml
echo "path.data: /local/elastic" >> /etc/elasticsearch/elasticsearch.yml

/sbin/chkconfig --add elasticsearch
service elasticsearch start



## MYSQL
yum -y remove mysql-libs mysql mysql-server mysql-devel mysql-shared mysql-server
cd /usr/local/
wget http://dev.mysql.com/get/Downloads/MySQL-5.6/MySQL-5.6.20-1.el6.x86_64.rpm-bundle.tar
tar -xvf *.tar
rm MySQL-5.6.20-1.el6.x86_64.rpm-bundle.tar
rpm --install MySQL-client-5.6.20-1.el6.x86_64.rpm MySQL-devel-5.6.20-1.el6.x86_64.rpm \
	MySQL-server-5.6.20-1.el6.x86_64.rpm MySQL-shared-5.6.20-1.el6.x86_64.rpm \
	MySQL-shared-compat-5.6.20-1.el6.x86_64.rpm

service mysql start


## s3fs
yum remove -y fuse fuse-devel libguestfs perl-Sys-Guestfs
##here are the instructions:
## S3 FUSE FILESYSTEM ##
## yum -y install ftp://rpmfind.net/linux/sourceforge/a/an/anthonos/mirror/os2-repo/os3-packages/stage-6-packages/fuse-2.9.3-2.x86_64.rpm

##http://sourceforge.net/projects/httpfs/files/latest/download?source=files

## s3fs requires a higher version of fuse than comes with centos
## yum remove -y fuse fuse-devel libguestfs perl-Sys-Guestfs
#browse to : http://sourceforge.net/projects/fuse/files/fuse-2.X/
#download 2.9.6 then uncompress in /usr/local/src

cd /usr/local/src
wget 'http://downloads.sourceforge.net/project/fuse/fuse-2.X/2.9.3/fuse-2.9.3.tar.gz'
tar -xzvf fuse-2.9.3.tar.gz
cd fuse-2.9.3
./configure
make install


cd /usr/local/src;
wget http://s3fs.googlecode.com/files/s3fs-1.74.tar.gz;
tar -xzvf  s3fs-1.74.tar.gz;
cd s3fs-1.74;
./configure;
make -j2;
make install;

mkdir /mnt/configs
# public:
/usr/local/bin/s3fs commercerack-configs /mnt/configs -odefault_acl=public-read -opublic_bucket=1 -ouse_cache=/tmp
# private (rw)
#/usr/local/bin/s3fs commercerack-configs /mnt/configs -odefault_acl=public-read -ouse_cache=/tmp


## 
## xerces and xalan are needed for ebay xslt conversion, also for some types of EDI
## on i686
## NEVER USE CENTOS BINARIES: -- THESE VERSIONS DONT WORK (IT WILL SCREW OVER XALAN)
##	yum install xerces-c xerces-c-devel xerces-c-doc
## 
cd /usr/local/src/
wget http://apache.cs.utah.edu/xerces/c/3/sources/xerces-c-3.1.1.tar.gz
tar -xzvf xerces-c-3.1.1.tar.gz
cd xerces-c-3.1.1
./configure
make install
ldconfig

cd /usr/local/src
wget http://apache.cs.utah.edu/xalan/xalan-c/sources/xalan_c-1.11-src.tar.gz
tar -xzvf xalan_c-1.11-src.tar.gz
cd xalan-c-1.11/c
 export XERCESCROOT="/usr/local/include/xercesc"
 export XALANCROOT=`pwd`
./runConfigure -p linux
make clean

## DO NOT RUN CONFIGURE -- YOU WILL SPEND HOURS FIGURING OUT WTF.
## ./configure
make
make install



## OKAY NOW WE'RE ALL SET WITH INSTALLATION(S) -- let's provision filesystems
zpool create tank /dev/xvdf 
zfs create tank/users
mkdir -p /users


cat /etc/commercerack.ini
[zid]
insecure: 1

!users: /users/*/platform.yaml
^D




## now we can provision a new account


##########################################################
## line of deprecation
##


## elastic search really wants a swapfile.
#mkdir -p /var/swap
## create a 1gb swap file
#dd if=/dev/zero of=/var/swap/swap1 count=1024 bs=1024000
#mkswap /var/swap/swap1
#swapon /var/swap/swap1
#echo "/var/swap/swap1 swap    swap    defaults         0 0" >> /etc/fstab




## NetSRS -- DomainRegistration
## pre-req for opensrs
#cd /usr/local/src
#echo | cpanm Test::Carp;
#echo | cpanm Locales::DB;
#echo | cpanm Locales;
#echo | cpanm DBM::Deep;
#echo | cpanm Number::Phone;
#cd /usr/local/src;
#git clone https://github.com/brianhorakh/perl-cpan--Net-OpenSRS
#cd perl-cpan--Net-OpenSRS
#perl Makefile.PL
#make install


##
## opensrs we must download the dev release
## http://search.cpan.org/CPAN/authors/id/I/IV/IVAN/Net-OpenSRS-0.07_01.tar.gz
#cd /usr/local/src
#wget http://search.cpan.org/CPAN/authors/id/I/IV/IVAN/Net-OpenSRS-0.07_01.tar.gz
#tar -xzvf Net-OpenSRS-0.07_01.tar.gz
#cd Net-OpenSRS-0.07_01/
#perl Makefile.PL
#make




## JFTP GATEWAY (for buy.com proxy)
## 
cd /usr/local/src
wget http://www.mcknight.de/jftpgw/jftpgw-0.13.5.tar.gz
tar -xzvf jftpgw-0.13.5.tar.gz
cd jftpgw-0.13.5
./configure --enable-libwrap
make install
cp /httpd/platform/role/gw/jftpgw.conf /usr/local/etc/jftpgw.conf
ln -s /etc/jftpgw.conf /usr/local/etc/jftpgw.conf




## HMM maybe:
#cd /usr/local/src
#wget http://redis.googlecode.com/files/redis-2.6.10.tar.gz
#tar xzf redis-2.6.10.tar.gz
#cd redis-2.6.10
#make 
#make install



##
## git clone git://banu.com/tinyproxy.git
#cd /usr/local/src
#wget --no-check-certificate https://banu.com/pub/tinyproxy/1.8/tinyproxy-1.8.3.tar.bz2
#tar -xjvf tinyproxy-1.8.3.tar.bz2
#cd tinyproxy-1.8.3
#./configure
#make install
##
##



## ZERO MQ

## latest autoconf needed for libmaxmind/geoip
cd /usr/local/src;
wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz;
cd autoconf-2.69;
./configure;
make install;


## download maxmind c library? (is this even needed)
#cd /usr/local/src
#git clone https://github.com/maxmind/libmaxminddb.git
#cd libmaxminddb
#./bootstrap
#./configure
#make install


cd /usr/local/src
# wget http://www.maxmind.com/app/c
/bin/rm -f GeoIP-latest.tar.gz;
wget http://www.maxmind.com/download/geoip/api/c/GeoIP-latest.tar.gz
tar -xzvf GeoIP-latest.tar.gz
cd GeoIP-1.5.1
./configure --enable-shared
make
make install

## grab the latest database
wget -N http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
## wget http://dev.maxmind.com/geoip/downloadable

## grab the perl library
## DO NOT USE: cpanm Geo::IP
wget http://search.cpan.org/CPAN/authors/id/B/BO/BORISZ/Geo-IP-1.42.tar.gz
tar -xzvf Geo-IP-1.42.tar.gz
cd Geo-IP-1.42
perl Makefile.PL LIBS="-L/usr/local/lib"



cd /usr/local/src
wget -N http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
gzip -d GeoIP.dat.gz
mv GeoIP.dat /httpd/static



## 201402

ln -s /httpd /backend

cd /
ln -s /backend /httpd
rm -Rf /backend/lib
ln -s /backend/lib /backend/modules
 
## 201403




/root/configs/ntp-time/ntp.sh

sysctl -w net.core.somaxconn=1024









######################################################### END OF FILE ######################################################


## STUFF I DID NOT INSTALL:
#rrd
#mysql client
#wget http://www.cpan.org/src/5.0/perl-5.16.2.tar.gz


#http://dev.mysql.com/get/Downloads/MySQL-Proxy/mysql-proxy-0.8.3-linux-rhel5-x86-32bit.tar.gz/from/http://cdn.mysql.com/
#http://dev.mysql.com/get/Downloads/MySQL-Proxy/mysql-proxy-0.8.3-linux-rhel5-x86-64bit.tar.gz/from/http://cdn.mysql.com/
#tar -xzvf
#mv /usr/local
#ln -s mysql-proxy-0.8.3-linux-rhel5-x86-64bit mysql-proxy


### STEPS TO FIX THE CLONE ISSUE:
#steps to fix the clone issue:
#1. joe /etc/udev/rules.d/70-persistent-net.rules
#2. udev adds new nics when the new boots 
#Change those from eth2, eth3 to eth0, eth1
#delete the old eth0,1 lines
#3. copy the new mac addresses
#4. put them in /etc/sysconfig/network-scripts/ifcfgl-eth0 ,1
#5. start_udev
#6. reboot


## 
## CERTIFICATES!
## if we were going to create new certificates we would:
#cd /usr/local/ssl/misc/
#   a) ./CA.sh -newca
#         # Follow instructions, create PEM passphrase, but create a blank pass for the Challenge pass phrase
#   b) Next, create a cert request and private key for the server. Remember that the Common Name for this cert should be the fully qualified domain name of the server:
#   openssl req -new -nodes -keyout newreq.pem -out newreq.pem
#       # Follow instructions, leave challenge password blank
#   c) ./CA.sh -sign
#       # You will need to enter the PEM passphrase here and confirm your selection
#   d) Install these certs for use with Apache.
#       mkdir -p /usr/local/share/certs/
#       mv newcert.pem /usr/local/share/certs/apachecert.pem
#       mv newreq.pem /usr/local/share/certs/apachecertkey.pem


cat >> ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsUiW2oypUP6ZImCT/957f7wRUGdCaTCtx+B3FNloioo8r5IGOR/fgTDMZz51bMz06tdunLdtzvvP5/PAoXsU1ZOsi9LK8wBqwzzdg6IO+1+I/JO6kZj0/su2gBhCJ9VqvfuI0BIVjIylgwXISrHJ7z3N8jlIAq5D1y7MS/t3fs3d9SySiDmU4SulPluj8tyOC95jCWN05hEXpk3LinnW/AbgyntAtnCZFk/87+m+n3lB1/o73s+b6c2w1Us6GQKsfTHu5iA2dpBkNLOB5L1HcazwAfTKXd3j6fG5g61gzTWxhSssgtXnsBH6ThOL8LETjGdlKGfXHGgE40zqFdgHGw== updates@commercerack.com


useradd -M --system -u 495 nginx
groupadd -g 494 nagios; useradd -m -u 494 -g 494 nagios; mkdir -m 755 -p /home/nagios; chown nagios /home/nagios;; mkdir -p 700 /home/nagios/.ssh
chown nagios.nagios /home/nagios/.ssh
ssh-keygen -t rsa

echo 20 > /proc/sys/vm/swappiness
sysctl -w net.ipv4.tcp_max_syn_backlog=1280
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_rmem='4096 7380 16777216'
sysctl -w vm.min_free_kbytes=65536
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w fs.file-max=70000



/root/configs/ntp-time/ntp.sh
mkdir -m 755 -p /local/nginx/logs
mkdir -m 0775 /local/nginx-cache
mkdir /local/logs
ln -s /local/logs /backend/logs



mkdir -m 0777 -p /remote/crackle/users; mkdir -m 0777 -p /remote/pop/users; mkdir -m 0777 -p /remote/dagobah/users; mkdir -m 0777 -p /remote/hoth/users;mkdir -m 0777 -p /remote/bespin/users
cat >>/etc/fstab

### NFS MOUNT POINTS
server:/users/homedir /remote/users  nfs defaults,hard,rsize=32768,wsize=32768,nfsvers=4,intr,noacl,noatime 0


echo 1024 > /proc/sys/net/core/somaxconn
sysctl -w net.core.somaxconn=1024


---





/etc/init.d/iptables start

echo 1024 > /proc/sys/net/core/somaxconn

echo 15 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 25 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 15 > /proc/sys/net/ipv4/tcp_keepalive_time

# which sockets can be used for whatever
echo 8192 61000 > /proc/sys/net/ipv4/ip_local_port_range

# of probes before timeout
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes

# This allows reusing sockets in TIME_WAIT state for new connections when it is safe from protocol viewpoint.
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

www2-hoth
echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 0 > /proc/sys/net/ipv4/tcp_tw_reuse


renice the nginx process



gw1 boxes:
## DID NOT SET: /proc/sys/net/ipv4/tcp_fin_timeout
## DID NOT SET  /proc/sys/net/ipv4/tcp_tw_reuse
echo 15 > /proc/sys/net/ipv4/tcp_keepalive_intvl 
echo 9 > /proc/sys/net/ipv4/tcp_keepalive_probes
echo 8192 61000 > /proc/sys/net/ipv4/ip_local_port_range



