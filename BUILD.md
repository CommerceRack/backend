
##
## 201407 BUILD process
##
# using a standard centos box
##

useradd commercerack

## similiar to tinydns, etc. we use a root level directory to minimize stat calls to the root fs
## /backend is the path for the main server.
mkdir -p /backend

echo "/usr/local/lib" > /etc/ld.so.conf.d/usr-local-lib.conf
ldconfig

ln -sf /usr/share/zoneinfo/US/Pacific-New /etc/localtime


cat >> ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsUiW2oypUP6ZImCT/957f7wRUGdCaTCtx+B3FNloioo8r5IGOR/fgTDMZz51bMz06tdunLdtzvvP5/PAoXsU1ZOsi9LK8wBqwzzdg6IO+1+I/JO6kZj0/su2gBhCJ9VqvfuI0BIVjIylgwXISrHJ7z3N8jlIAq5D1y7MS/t3fs3d9SySiDmU4SulPluj8tyOC95jCWN05hEXpk3LinnW/AbgyntAtnCZFk/87+m+n3lB1/o73s+b6c2w1Us6GQKsfTHu5iA2dpBkNLOB5L1HcazwAfTKXd3j6fG5g61gzTWxhSssgtXnsBH6ThOL8LETjGdlKGfXHGgE40zqFdgHGw== root@dev
^D




# what i've done
# copied /root/configs

## we don't need ip forwarding anymore
#modify /etc/rc.d/rc.local set 
#	echo 1 > /proc/sys/net/ipv4/ip_forward

## 
## iostat -- in sysstat

#===========================================
## INSTALL ZFS
#===========================================
yum -y install rpm-build kernel-devel zlib-devel libuuid-devel libblkid-devel libselinux-devel  e2fsprogs-devel parted lsscsi
yum -y localinstall --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release-1-3.el6.noarch.rpm

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

#===========================================
##  
#===========================================
yum update
yum -y install cronie ftp postfix openssh openssl openssh-clients rdist ntpdate gcc make postfix mailx telnet openssh man wget
yum -y install libtool-ltdl-devel glibc-devel apr-devel apr-util-devel aspell-devel binutils-devel bison-devel boost-devel boost-mpich2-devel boost-openmpi-devel 
yum -y install inotify-tools incrond vixie-cron


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
 tcpdump iotop bind-utils asciidoc libatomic_ops-devel openssl-devel perl perl-ExtUtils-MakeMaker perl-ExtUtils-ParseXS perl-Module-Pluggable \
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
## we use openresty to get a lot of modules for nginx, but we don't install them all.
##
cd /usr/local/src;
wget http://openresty.org/download/ngx_openresty-1.5.8.1.tar.gz;
tar -xzvf ngx_openresty-1.5.8.1.tar.gz; cd ngx_openresty-1.5.8.1;
./configure;


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
	--with-pcre-jit \
	--add-module=../ngx_openresty-1.5.8.1/bundle/auth-request-nginx-module-0.2 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/echo-nginx-module-0.51 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/headers-more-nginx-module-0.25 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/ngx_coolkit-0.2rc1 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/ngx_devel_kit-0.2.19 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/redis-nginx-module-0.3.7 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/redis2-nginx-module-0.10 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/set-misc-nginx-module-0.24 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/srcache-nginx-module-0.25 \
	--add-module=../ngx_openresty-1.5.8.1/bundle/memc-nginx-module-0.14 
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

## we don't use this anymore.
## yum -y install gitolite gitolite3

## raise the number of file descriptors
cat >> /etc/security/limits.conf
nginx       soft    nofile   10000
nginx       hard    nofile  30000
^D


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
cd /usr/local/src/
wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar -xzvf redis-2.6.16.tar.gz
cd redis-2.6.16
make install

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


#----------------------------------------
## MORE PERL
## just follow the prompts, yes to everything
cpanm UNIVERSAL::require;
cpanm Exporter::Easy;
cpanm File::Find::Rule;
cpanm common::sense;
cpanm JSON::XS;
cpanm Test::More;

cpanm Business::EDI;
cpanm Business::UPC;
cpanm Memcached::libmemcached;
## warnings are okay for Cache::libmemcached (there are no servers installed!)
cpanm Cache::Memcached::libmemcached;
cpanm CDB_File;

cpanm FCGI;
cpanm CGI;
cpanm CGI::Lite;
cpanm Class::Runtime;
cpanm Class::Std;
cpanm Class::Std::Fast::Storable;
cpanm Data::UUID;
cpanm Data::GUID;
cpanm Date::Calc;
cpanm version;
cpanm Perl::OSType;
cpanm Module::Metadata;
cpanm CPAN::Meta::YAML;
cpanm JSON::PP;
cpanm CPAN::Meta::Requirements;
cpanm Parse::CPAN::Meta;
cpanm CPAN::Meta;
cpanm Module::Build;

cpanm Date::Manip;
cpanm Date::Parse;

cpanm ExtUtils::MakeMaker;
cpanm Test::Requires;
cpanm Try::Tiny;
cpanm Test::Fatal;
cpanm Module::Runtime;
cpanm Dist::CheckConflicts;

cpanm Module::Runtime;
cpanm Module::Implementation;
cpanm Package::DeprecationManager;
cpanm Package::Stash::XS;
cpanm Package::Stash;
cpanm Class::Load;
cpanm DateTime::TimeZone;
cpanm DateTime;
cpanm DBI;
cpanm Digest::HMAC_SHA1;
cpanm Digest::MD5;
cpanm Digest::SHA1;
cpanm DIME::Message;
## perl -MCPAN -e 'CPAN::Shell->force("install","DIME::Payload");';

cpanm Data::Dump;
cpanm Any::URI::Escape";
cpanm HTTP::Tiny;
cpanm HTTP::Lite;

--
## NOTE: may require:
perl -MCPAN -e 'CPAN::Shell->force("install","ElasticSearch::SearchBuilder");';
##cpanm ElasticSearch::SearchBuilder;

cpanm Log::Any;
cpanm Log::Any::Adapter;
cpanm Log::Any::Adapter::Callback;
cpanm Elasticsearch;


cpanm URI;
cpanm AnyEvent;
cpanm AnyEvent::TLS;
cpanm AnyEvent::HTTP;
cpanm AnyEvent::HTTP::LWP::UserAgent;
cpanm DateTime::Locale;
cpanm DateTime::Format::Strptime;
cpanm JSON;
cpanm Test::Trap;
cpanm Ouch;
cpanm Mouse;
cpanm Any::Moose;
cpanm MIME::Base64::URLSafe;
cpanm Facebook::Graph;
##cpanm File::Basename");';		## included w/ perl (should match ;
## cpanm File::Copy");';		## included w/ perl (should match ;


cpanm Net::Cu;
cpanm Test::HTTP::Serv;
cpanm LWP::Protocol::Net::Cu;

cpanm Filesys::Virtual;
cpanm Filesys::Virtual::Plain;
cpanm File::Find::Rule::Filesys::Virtual;
cpanm --force File::Path;
cpanm File::Slurp;
cpanm File::Spec;
cpanm File::Temp;

cpanm Frontier::Client;
cpanm Frontier::RPC2;
cpanm Class::Measure;

cpanm ExtUtils::MakeMaker;
cpanm MRO::Compat;
cpanm List::MoreUtils;
cpanm Class::Load::XS;

cpanm Eval::Closure;
cpanm Sub::Name;
cpanm Data::OptList;
cpanm Carp;
cpanm Sub::Exporter::Progressive;
cpanm Devel::GlobalDestruction::XS;
cpanm Devel::GlobalDestruction;
cpanm Moose::Role;
cpanm Variable::Magic;
cpanm Class::MO;
cpanm Sub::Identify;
cpanm Sub::Name;
cpanm B::Hooks::EndOfScop;
cpanm namespace::clea;
cpanm namespace::autoclean;
cpanm Mouse;
cpanm Any::Moose;
cpanm GIS::Distance;

## perl -MCPAN -e 'CPAN::Shell->force("install","Google::Checkout::General::GCO");';
cpanm XML::Writer;
cpanm HTML::Entities;
## NO LONGER USED
##cpanm HTML::Mason;
##cpanm HTML::Mason::ApacheHandler;
cpanm HTML::Parser;
cpanm HTML::Tagset;
cpanm LWP::MediaTypes;
cpanm Encode::Locale;
cpanm IO::HTML;
cpanm HTTP::Date;
cpanm Compress::Raw::Bzip2;
cpanm Compress::Raw::Zlib;
cpanm IO::Compress::Bzip2;
cpanm IO::Uncompress::Bunzip;

cpanm HTTP::Headers;
cpanm HTTP::Cookies;
cpanm HTTP::Date;
cpanm HTTP::Request;
cpanm HTTP::Request::Common;
cpanm HTTP::Response;
cpanm IO::File;
cpanm IO::Scalar;
cpanm IO::String;
cpanm JSON::Syck;
cpanm JSON::XS;

cpanm Lingua::EN::Infinitive;
cpanm HTTP::Negotiate;
cpanm File::Listing;
cpanm HTTP::Daemon;
cpanm Net::HTTP;
cpanm WWW::RobotRules;
cpanm LWP;
cpanm LWP::UserAgent;
cpanm LWP::Simple;
cpanm Mail::DKIM::PrivateKey;
cpanm Mail::DKIM::Signer;
cpanm MIME::Base64;
cpanm MIME::Entity;
cpanm MIME::Lite;
cpanm MIME::Parser;


cpanm Math::BigInt;
cpanm Math::BigInt::FastCalc;
cpanm Math::BigRat;
cpanm Net::DNS;
cpanm Net::FTP;
cpanm Net::POP3;

cpanm Test::use::ok;
cpanm Tie::ToObject;
cpanm Moose;
cpanm Sub::Identify;
cpanm Variable::Magic;
cpanm B::Hooks::EndOfScope;
cpanm namespace::clean;

cpanm Data::Visitor::Callback;
cpanm MooseX::Aliases;
cpanm MooseX::Role::Parameterized;
cpanm Net::OAuth;
cpanm DateTime::Locale;
cpanm DateTime::Format::Strptime;

cpanm TAP::Harness::Env;
cpanm ExtUtils::Helpers;
cpanm ExtUtils::Config;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm namespace::autoclean;
cpanm Net::Twitter;
cpanm Pod::Parser;
## cpanm POSIX");';	## included with;

cpanm Redis;
cpanm Scalar::Util;
cpanm Text::CSV;
cpanm Text::CSV_XS;
cpanm Text::Metaphone;
cpanm Text::Soundex;
cpanm Tie::Hash::Indexed;
cpanm Time::HiRes;


cpanm URI;
cpanm URI::Escape;
cpanm URI::Escape::XS;
cpanm URI::Split;
cpanm XML::LibXML;
cpanm XML::Parser;
cpanm XML::Parser::EasyTree;
cpanm XML::RSS;
cpanm XML::SAX::Base;

## NOTE: XML::SAX requires we press 'Y'
cpanm XML::SAX;




<<<<<<< HEAD
cpanm XML::Handler::Trees;
cpanm XML::SAX::Expat;
cpanm XML::Simple;
	cpanm XML::SAX::Simple;
cpanm Object::MultiType;
cpanm XML::Smart;
cpanm XML::Writer;
cpanm YAML::Syck;
cpanm YAML::XS;

cpanm Text::WikiCreole;
cpanm JSON::XS;
cpanm Date::Calc;
cpanm Text::Wrap;
cpanm Digest::SHA1;
cpanm DIME::Payload;
cpanm Compress::Bzip2;
cpanm HTML::Tiny;
cpanm Captcha::reCAPTCHA;
cpanm HTML::Tiny;
cpanm Captcha::reCAPTCHA;
cpanm File::Type;
cpanm CGI::Lite::Request;
cpanm File::Type;
cpanm CGI::Lite::Request;
cpanm Regexp::Common;
cpanm Parse::RecDescent;
cpanm Capture::Tiny;
cpanm Email::Address;
cpanm Email::MessageID;
cpanm Email::Simple::Creator;
cpanm Email::MIME::Encodings;
cpanm Email::MIME::ContentType;
cpanm Email::MIME;
cpanm Email::MessageID;
cpanm Email::MIME::Encodings;
cpanm Email::MIME::ContentType;
cpanm Email::Simple;

cpanm AnyEvent;
cpanm Encode::IMAPUTF7;
cpanm Email::MIME::ContentType;
cpanm EV;
cpanm Guard;
cpanm Coro;

cpanm Net::Server;
cpanm Net::Server::Coro;

cpanm Net::Server;
# perl -MCPAN -e 'CPAN::Shell->force("install","Coro");';
# cpanm Net::Server::Coro;
cpanm Email::MIME;
# perl -MCPAN -e 'CPAN::Shell->notest("install","Net::IMAP::Simple");';		
cpanm Net::IMAP::Simple

cpanm App::ElasticSearch::Utilities;


##
## 201401
##
cpanm AnyEvent::Redis;
cpanm String::Urandom;
cpanm --force Net::AWS::SES;
cpanm Nginx;
cpanm Net::Domain::TLD;
cpanm Data::Validate::Domain;
cpanm Data::Validate::Email;
cpanm Email::Valid;
cpanm CSS::Minifier::XS;
cpanm MediaWiki::API;


## 201401b
#cd /usr/local/src/;
#wget ftp://megrez.math.u-bordeaux.fr/pub/pari/unix/pari-2.5.5.tar.gz
#tar -xzvf pari-2.5.5.tar.gz;
#cd pari-2.5.5
#./Configure

cpanm XML::Handler::Trees
cpanm XML::SAX::Expat
cpanm XML::Simple
cpanm Object::MultiType
cpanm XML::Smart

cpanm XML::Writer
cpanm YAML::Syck
cpanm YAML::XS

cpanm Text::WikiCreole
cpanm JSON::XS
cpanm Date::Calc
cpanm Text::Wrap
cpanm Digest::SHA1
cpanm DIME::Payload
cpanm Compress::Bzip2
cpanm HTML::Tiny
cpanm Captcha::reCAPTCHA
cpanm HTML::Tiny
cpanm Captcha::reCAPTCHA
cpanm File::Type
cpanm CGI::Lite::Request
cpanm File::Type
cpanm CGI::Lite::Request
cpanm Regexp::Common
cpanm Parse::RecDescent
cpanm Capture::Tiny
cpanm Email::Address
cpanm Email::MessageID
cpanm Email::Simple::Creator
cpanm Email::MIME::Encodings
cpanm Email::MIME::ContentType
cpanm Email::MIME
cpanm Email::MessageID
cpanm Email::MIME::Encodings
cpanm Email::MIME::ContentType
cpanm Email::Simple

cpanm AnyEvent
cpanm Encode::IMAPUTF7
cpanm Email::MIME::ContentType
cpanm EV
cpanm Guard

cpanm Coro
cpanm Net::Server
cpanm Net::Server::Coro

cpanm Net::Server
# perl -MCPAN -e 'CPAN::Shell->force("install","Coro
# cpanm Net::Server::Coro
cpanm Email::MIME
cpanm Net::IMAP::Simple
cpanm App::ElasticSearch::Utilities

cpanm AnyEvent::Redis
cpanm String::Urandom
cpanm Net::AWS::SES
cpanm Nginx
cpanm Net::Domain::TLD
cpanm Data::Validate::Domain
cpanm Data::Validate::Email
cpanm Email::Valid
cpanm CSS::Minifier::XS
cpanm MediaWiki::API

cpanm Math::Pari

#rm /usr/local/lib/libpari*
#cd /usr/local/src
#wget http://search.cpan.org/CPAN/authors/id/I/IL/ILYAZ/modules/Math-Pari-2.01080605.tar.gz
#tar -xzvf Math-Pari-2.01080605.tar.gz
#cd Math-Pari*
#perl Makefile.PL force_download
>>>>>>> 6c0b6a7bafbd6454522961436ec8710f96db3ed1
#make install

<<<<<<< HEAD
cpanm Data::Buffer;
cpanm Sort::Versions;
cpanm Class::Loader;
cpanm Math::Pari;
cpanm Crypt::Random;
cpanm Crypt::Primes;
cpanm Crypt::Blowfish;
cpanm Tie::EncryptedHash;
cpanm Digest::MD5;
cpanm Convert::ASCII::Armour;
cpanm Crypt::RSA;

## these tests lock up
cpanm Path::Tiny;
cpanm Exporter::Tiny;
cpanm Type::Tiny;
cpanm Types::Standard;
cpanm Sub::Infix;
cpanm match::simple;

cpanm Test::Synopsis;
cpanm Test::Poe;
cpanm Test::Strict;
cpanm PPI;
cpanm PPIx::Regex;
cpanm Perl::MinimumVersion;
cpanm Term::ANSIColor;

cpanm Term::ANSIColo4;
cpanm Text::Aligned;
cpanm Text::Table;

cpanm Test::Without::Module;
cpanm JSON::Any;
cpanm Test::JSON;
cpanm Test::MockModule;
cpanm DBIx::Connector;
cpanm MooseX::ArrayRef;
cpanm Module::Load;
cpanm Module::CoreList;
cpanm Module::Load::Conditional;
cpanm XML::Namespace;
cpanm XML::NamespaceFactory;
cpanm XML::CommonNS;
cpanm Algorithm::Combinatorics;

cpanm ExtUtils::Depends;
cpanm B::Hooks::OP::Check;
cpanm B::Hooks::OP::PPAddr;
cpanm Module::Build::Tiny;
cpanm MooseX::Traits;
cpanm MooseX::Types::Moose;

cpanm Class::Tiny;
cpanm Devel::PartialDump;

cpanm MooseX::Types::DateTime;
cpanm MooseX::Types::Structured;
cpanm MooseX::Types;

cpanm aliases;
cpanm Parse::Method::Signatures;


cpanm Scope::Upper;
cpanm Devel::Declare;
cpanm TryCatch;


cpanm Set::Scalar;
cpanm RDF::TriN3;
cpanm RDF::Query;
cpanm Crypt::X509;
cpanm namespace::sweet;
cpanm Web::ID;


cpanm Net::FTPSSL;
cpanm SOAP::WSDL;
cpanm Crypt::CBC;
cpanm Crypt::Twofish;
cpanm Crypt::DES;
cpanm Data::Dumper::Concise;
cpanm Config::General;
cpanm Config::Any;
cpanm Class::XSAccessor;
cpanm Test::Exception;
cpanm Class::Accessor::Grouped;
cpanm Hash::Merge;
cpanm Params::Validate;
cpanm Test::Tester;
cpanm Test::Warnings;
cpanm Getopt::Long::Descriptive;
cpanm SQL::Abstract;
cpanm Data::Dumper::Concise;


cpanm ok;
cpanm Config::Any;
cpanm SQL::Abstract;
cpanm Context::Preserve;
cpanm Test::Exception;
cpanm Data::Compare;
cpanm Path::Class;
cpanm Scope::Guard;
cpanm DBD::SQLite;
cpanm Hash::Merge;
cpanm Class::Accessor::Chained::Fast;

cpanm Module::Find;
cpanm Data::Page;
cpanm Algorithm::C3;
cpanm Class::C3;
cpanm Class::C3::Componentised;

cpanm strictures;
cpanm Role::Tiny;
cpanm Class::Method::Modifiers;
cpanm Devel::GlobalDestruction;

cpanm Moo;
	
cpanm Math::Symbolic;
cpanm Sub::Identify;
cpanm Variable::Magic;
cpanm B::Hooks::EndOfScope;
cpanm namespace::clean;
cpanm DBIx::Class;
cpanm Proc::PID::File;
cpanm Acme::Damn;
cpanm Sys::SigAction;
cpanm forks;
cpanm XML::SimpleObject;
cpanm Net::Netmask;
cpanm DBD::SQLite;

cpanm File::Pid;
cpanm Log::Log4perl;
cpanm Sysadm::Install;
cpanm App::Daemon;

## Needed for Webdoc parsing.
cpanm HTML::Entities::Numbered;
cpanm HTML::TreeBuilder;
## cpanm HTML::Tidy");';	 <<- doesn't ;
echo "" | cpanm XML::Twig;


## 201316
cpanm ExtUtils::Config;
cpanm File::ShareDir::Install;
cpanm Apache::LogFormat::Compiler;
cpanm Stream::Buffered;
cpanm Test::SharedFork;
cpanm Test::TCP;
cpanm File::ShareDir;
cpanm ExtUtils::Helpers;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm Hash::MultiValue;
cpanm Devel::StackTrace;
cpanm HTTP::Body;
cpanm Filesys::Notify::Simple;
cpanm Devel::StackTrace::AsHTML;
cpanm Plack;
cpanm HTTP::Message::PSGI;
cpanm Test::UseAllModules;
cpanm Plack::Request;

cpanm Test::Fake::HTTPD;
cpanm Class::Accessor::Lite;
cpanm Test::Flatten;
cpanm WWW::Google::Cloud::Messaging;
cpanm Text::WikiCreole;
cpanm Test::Class;

cpanm Data::OptList;
cpanm CPAN::Meta::Check;
cpanm Test::CheckDeps;
cpanm Test::Mouse;
cpanm Any::Moose;
cpanm Test::Moose;
cpanm Net::APNS;

cpanm Amazon::SQS::Simple;
## cpanm Amazon::SQS::ProducerConsum;

cpanm Data::Buffer
cpanm Sort::Versions
cpanm Class::Loader
cpanm Math::Pari
cpanm Crypt::Random
cpanm Crypt::Primes
cpanm Crypt::Blowfish
cpanm Tie::EncryptedHash
cpanm Digest::MD2
cpanm Convert::ASCII::Armour
cpanm Crypt::RSA

## these tests lock up
cpanm Path::Tiny
cpanm Exporter::Tiny
cpanm Type::Tiny
cpanm Types::Standard
cpanm Sub::Infix
cpanm match::simple

cpanm Test::Synopsis
cpanm Test::Pod
cpanm Test::Strict
cpanm PPI
cpanm PPIx::Regexp
cpanm Perl::MinimumVersion
cpanm Term::ANSIColor
perl -MCPAN -e 'CPAN::Shell->force("install","Term::ANSIColor");'

cpanm Term::ANSIColor
cpanm Text::Aligner
cpanm Text::Table

cpanm Test::Without::Module
cpanm JSON::Any
cpanm Test::JSON
cpanm Test::MockModule
cpanm DBIx::Connector
cpanm MooseX::ArrayRef
cpanm Module::Load
cpanm Module::CoreList
cpanm Module::Load::Conditional
cpanm XML::Namespace
cpanm XML::NamespaceFactory
cpanm XML::CommonNS
cpanm Algorithm::Combinatorics

cpanm ExtUtils::Depends
cpanm B::Hooks::OP::Check
cpanm B::Hooks::OP::PPAddr
cpanm Module::Build::Tiny
cpanm MooseX::Traits
cpanm MooseX::Types::Moose

cpanm Class::Tiny
cpanm Devel::PartialDump

cpanm MooseX::Types::DateTime
cpanm MooseX::Types::Structured
cpanm MooseX::Types

cpanm aliased
cpanm Parse::Method::Signatures


cpanm Scope::Upper
cpanm Devel::Declare
cpanm TryCatch

cpanm Set::Scalar
cpanm RDF::Trine
cpanm RDF::Query
cpanm Crypt::X509
cpanm namespace::sweep
cpanm Web::ID






cpanm Net::FTPSSL
cpanm SOAP::WSDL
cpanm Crypt::CBC
cpanm Crypt::Twofish
cpanm Crypt::DES
cpanm Data::Dumper::Concise
cpanm Config::General
cpanm Config::Any
cpanm Class::XSAccessor
cpanm Test::Exception
cpanm Class::Accessor::Grouped
cpanm Hash::Merge
cpanm Params::Validate
cpanm Test::Tester
cpanm Test::Warnings
cpanm Getopt::Long::Descriptive
cpanm SQL::Abstract
cpanm Data::Dumper::Concise


cpanm ok
cpanm Config::Any
cpanm SQL::Abstract
cpanm Context::Preserve
cpanm Test::Exception
cpanm Data::Compare
cpanm Path::Class
cpanm Scope::Guard
cpanm DBD::SQLite
cpanm Hash::Merge
cpanm Class::Accessor::Chained::Fast

cpanm Module::Find
cpanm Data::Page
cpanm Algorithm::C3
cpanm Class::C3
cpanm Class::C3::Componentised

cpanm strictures
cpanm Role::Tiny
cpanm Class::Method::Modifiers
cpanm Devel::GlobalDestruction

cpanm Moo
	
cpanm Math::Symbolic
cpanm Sub::Identify
cpanm Variable::Magic
cpanm B::Hooks::EndOfScope
cpanm namespace::clean
cpanm DBIx::Class
cpanm Proc::PID::File
cpanm Acme::Damn
cpanm Sys::SigAction
cpanm forks
cpanm XML::SimpleObject
cpanm Net::Netmask
cpanm DBD::SQLite

cpanm File::Pid
cpanm Log::Log4perl
cpanm Sysadm::Install
cpanm App::Daemon

## Needed for Webdoc parsing.
cpanm HTML::Entities::Numbered
cpanm HTML::TreeBuilder
## cpanm HTML::Tidy	 <<- doesn't work!
echo "" | cpanm XML::Twig


## 201316
cpanm ExtUtils::Config
cpanm File::ShareDir::Install
cpanm Apache::LogFormat::Compiler
cpanm Stream::Buffered
cpanm Test::SharedFork
cpanm Test::TCP
cpanm File::ShareDir
cpanm ExtUtils::Helpers
cpanm ExtUtils::InstallPaths
cpanm Module::Build::Tiny
cpanm Hash::MultiValue
cpanm Devel::StackTrace
cpanm HTTP::Body
cpanm Filesys::Notify::Simple
cpanm Devel::StackTrace::AsHTML
cpanm Plack
cpanm HTTP::Message::PSGI
cpanm Test::UseAllModules
cpanm Plack::Request

cpanm Test::Fake::HTTPD
cpanm Class::Accessor::Lite
cpanm Test::Flatten
cpanm WWW::Google::Cloud::Messaging
cpanm Text::WikiCreole
cpanm Test::Class

cpanm Data::OptList
cpanm CPAN::Meta::Check
cpanm Test::CheckDeps
cpanm Test::Mouse
cpanm Any::Moose
cpanm Test::Moose
cpanm Test::Class
cpanm Net::APNS

cpanm Amazon::SQS::Simple
>>>>>>> 6c0b6a7bafbd6454522961436ec8710f96db3ed1


##
## STARLET REQUIREMENTS:
<<<<<<< HEAD
cpanm Proc::Wait3;
cpanm Server::Starter;
cpanm Parallel::Prefork;
cpanm Starlet;

## STARMAN:
cpanm ExtUtils::Helpers;
cpanm ExtUtils::Config;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm HTTP::Parser::XS;



cpanm Net::OAuth2;

## http://search.cpan.org/CPAN/authors/id/X/XA/XAICRON/JSON-WebToken-0.07.tar.gz
cpanm Test::Mock::Guard";
cpanm JSON::WebToken";

## http://search.cpan.org/CPAN/authors/id/R/RI/RIZEN/Facebook-Graph-1.0600.tar.gz
cpanm Facebook::Graph";

## http://search.cpan.org/CPAN/authors/id/I/IA/IAMCAL/CSS-1.09.tar.gz
cpanm CSS";
## http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/CSS-Tiny-1.19.tar.gz
cpanm CSS::Tiny;


cpanm Test::HexString;
cpanm CPAN::Meta::Prereqs;
cpanm CPAN::Meta::Check;
cpanm Test::CheckDep;
## cpanm Protocol::UWSGI;

## 201352
cpanm String::Urando;
cpanm Net::AWS::SES;
cpanm Nginx;
cpanm Net::Domain::TL;
cpanm Data::Validate::Domai;
cpanm Data::Validate::Emai;
cpanm Email::Vali;
cpanm CSS::Minifier::X;
cpanm MediaWiki::AP;

cpanm Proc::Wait3
cpanm Server::Starter
cpanm Parallel::Prefork
cpanm Starlet

## STARMAN:
cpanm ExtUtils::Helpers
cpanm ExtUtils::Config
cpanm ExtUtils::InstallPaths
cpanm Module::Build::Tiny
cpanm HTTP::Parser::XS

cpanm Net::OAuth2

## http://search.cpan.org/CPAN/authors/id/X/XA/XAICRON/JSON-WebToken-0.07.tar.gz
cpanm Test::Mock::Guard 
cpanm JSON::WebToken 

## http://search.cpan.org/CPAN/authors/id/R/RI/RIZEN/Facebook-Graph-1.0600.tar.gz
cpanm Facebook::Graph 

## http://search.cpan.org/CPAN/authors/id/I/IA/IAMCAL/CSS-1.09.tar.gz
cpanm CSS 
## http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/CSS-Tiny-1.19.tar.gz
cpanm CSS::Tiny


cpanm Test::HexString
cpanm CPAN::Meta::Prereqs
cpanm CPAN::Meta::Check
cpanm Test::CheckDeps
## cpanm Protocol::UWSGI

## 201352
cpanm String::Urandom
cpanm Net::AWS::SES
cpanm Nginx

cpanm Net::Domain::TLD
cpanm Data::Validate::Domain
cpanm Data::Validate::Email
cpanm Email::Valid

cpanm CSS::Minifier::XS
cpanm MediaWiki::API


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

cpanm IO::CaptureOutput
cpanm Devel::CheckLib

yum -y install yum;
cpanm ExtUtils::CBuilder
cpanm String::ShellQuote
cpanm Alien::ZMQ
cpanm ZMQ::Constants
cpanm ZMQ::LibZMQ3

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



 cd /usr/local
 rm -Rf elasticsearch*
 rm -f /etc/init.d/elasticsearch
 
 ## wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.0.1.noarch.rpm
 ## rpm --install elasticsearch-1.0.1.noarch.rpm
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.1.noarch.rpm
rpm --install elasticsearch-1.3.1.noarch.rpm
 
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
wget http://dev.mysql.com/get/Downloads/MySQL-5.6/MySQL-5.6.14-1.el6.x86_64.rpm-bundle.tar/from/http://cdn.mysql.com/
tar -xvf *.tar
rm MySQL-5.6.14-1.el6.x86_64.rpm-bundle.tar
rpm --install MySQL-client-5.6.14-1.el6.x86_64.rpm MySQL-devel-5.6.14-1.el6.x86_64.rpm \
	MySQL-server-5.6.14-1.el6.x86_64.rpm MySQL-shared-5.6.14-1.el6.x86_64.rpm \
	MySQL-shared-compat-5.6.14-1.el6.x86_64.rpm

service mysql start


##
## SOME MORE PERL LIBRARIES
##
cpanm DBIx::ContextualFetch;
cpanm Ima::DBI;
cpanm UNIVERSAL::moniker;
cpanm Class::DBI;
cpanm DBD::mysql;

cpanm Stream::Buffered;
cpanm Test::SharedFork;
cpanm Test::TCP;
cpanm File::ShareDir;
cpanm Hash::MultiValue;
cpanm Devel::StackTrace;
cpanm HTTP::Body;
cpanm Filesys::Notify::Simple;
cpanm Devel::StackTrace::AsHTML;
cpanm Mojolicious;
cpanm AnyEvent;
cpanm WWW::Twilio::API;
cpanm Text::Wrap;
cpanm Plack;

cpanm Digest::SHA1;
cpanm DIME::Payload;
cpanm IPC::Lock::Memcached;
cpanm IPC::ConcurrencyLimit::Lock;

## s3fs
yum remove -y fuse fuse-devel libguestfs perl-Sys-Guestfs
here are the instructions:
## S3 FUSE FILESYSTEM ##

http://sourceforge.net/projects/httpfs/files/latest/download?source=files

## s3fs requires a higher version of fuse than comes with centos
yum remove -y fuse fuse-devel libguestfs perl-Sys-Guestfs
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
make;
make install;

mkdir /mnt/configs
# public:
/usr/local/bin/s3fs commercerack-configs /mnt/configs -odefault_acl=public-read -opublic_bucket=1 -ouse_cache=/tmp
# private (rw)
/usr/local/bin/s3fs commercerack-configs /mnt/configs -odefault_acl=public-read -ouse_cache=/tmp


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



## CANT GET ZEROMQ TO COMPILE UNPATCHED, Alien::ZMQ fixes it.
## ./configure --with-pgm --enable-static --enable-shared --with-gnu-ld
cpanm ExtUtils::CBuilder;
cpanm String::ShellQuote;

cpanm Alien::ZMQ;
cpanm ZMQ::LibZMQ;
cpanm String::Urandom;

yum -y install help2man texinfo libtool



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
cd /usr/local/src
wget http://redis.googlecode.com/files/redis-2.6.10.tar.gz
tar xzf redis-2.6.10.tar.gz
cd redis-2.6.10
make 
make install



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

yum -y install asciidoc

cpanm Data::JavaScript::LiteObject
cpanm JavaScript::Minifier


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
 
##

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
 
cpanm ExtUtils::Constant
cpanm Socket
cpanm Net::Ping
cpanm Hijk
cpanm HTTP::Tiny
cpanm Elasticsearch
cpanm Pegex::Parser
cpanm Mo::builder
cpanm Net::AWS::SES

## 201403




/root/configs/ntp-time/ntp.sh

sysctl -w net.core.somaxconn=1024


yum -y install mysql mysql-devel mysql-client



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



# Cut and paste the following into it:
################################################
#!/bin/sh
#
# Startup script for the Apache Web Server
#
# chkconfig: 345 85 15
# description: Apache is a World Wide Web server.  It is used to serve \
#        HTML files and CGI.
# processname: httpd
# pidfile: /var/run/httpd.pid
# config: /usr/local/apache/conf/httpd.conf

basedir=/usr/local/apache

# Source function library.
. /etc/rc.d/init.d/functions

# See how we were called.
case "$1" in
start)
echo -n "Starting httpd: "
daemon $basedir/bin/httpd -D SSL
echo
touch /var/lock/subsys/httpd
;;
stop)
echo -n "Shutting down http: "
killproc $basedir/bin/httpd
echo
rm -f /var/lock/subsys/httpd
rm -f /var/run/httpd.pid
;;
status)
status $basedir/bin/httpd
;;
restart)
$0 stop
$0 start
;;
reload)
echo -n "Reloading httpd: "
killproc $basedir/bin/httpd -HUP
echo
;;
*)
echo "Usage: $0 {start|stop|restart|reload|status}"
exit 1
esac

exit 0


################################################

17) make the startup script executable
chmod 755 /etc/init.d/httpd

18) Add apache to the appropriate run levels
chkconfig --levels 345 httpd on

19) edit your httpd.conf file how you like it or need it
vi /usr/local/apache/conf/httpd.conf
# Make sure you run the server as webman

20) Make error logs
mkdir -p /var/log/httpd/apache

21) Start apache
### skip starting apache if you are copying httpd.conf config files from another machine, until you have have completed all steps in this document
/etc/init.d/httpd start

22) Copy the /etc/passwd /etc/group and /etc/shadow to the new machine

23) Make sure that the accounts for programs have no shell access, apache, mysql, etc
# Change their accounts from /bin/bash
# to: /sbin/nologin

24) Set webman to /sbin/nologin


=====
HOST=z200 ; cat /root/.ssh/id_rsa.pub | ssh $HOST "cat >> ~/.ssh/authorized_keys"


mkdir -m 700 ~nagios/.ssh;

cat >> ~nagios/.ssh/authorized_keys
ssh-dss AAAAB3NzaC1kc3MAAACBAKRKJYFTG44RbnkmqMj8xVeqYXxCzIpqsrp1llKwRpw7Vdj1BKhT1Lkanum+t/VOD8GhVHzAdGKEWiq6N9OBB1Eu+ug/w87Rt9dDQIpAJcQMfuAGRDUPpfPYszi9ES2FHWD3IDPI3WxrFSoRW1483aHjMynDUdk2o/OXUErxCwPBAAAAFQDFP1EVWEd47iDXXqMZbpZLhlSMAwAAAIEAmla9noFI3uzZ7Nmi1ml7cyBzShzZnKpfobSGrTIrzDsOe2Xykzd1BSxkp4pK7PiPWpnS1hAARd9hTcfGPosispsEAdpT0bzQUMwngMshEkZn4yDTh1lRzADSy944NJkhH8QqlSdLlUdUT6AiNZNJeVT75ZdQ3l1LmYlbP/yty+sAAACAN8mYEqq/P7ltO61W/qlfxJpWGbI7uiZn81pbVNt5SadW3pvtaoqaQvsCET/YSnGZb+dUoh8GsPWkZMQpQhCJCLJ9LdhYrBroLFnvQLgweTFdA7KI/Ejk324OThNm1Kb8sC1tAAh4TzMi4RDkK6EifSsi1bwsfkJ8AwDhfsVMIco= nagios@monitor.zoovy.com
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAy/Yiq4g2tF+rNrG4MH5aZ/B65uDViqudCtWq2YweQclJGgHX7r/NI428aMdhU0ZFlSVL7+m5c7YP2QioRjgD4mD74N6oJW6GRxtKC9nKhkgi6aricaDNuu3ldQFosxavO7vS0+D6G40NR7JXpk9tLopQqInl/figBNuFzwpixRJajdMm3rpsbKsWcleDREp116lnohfTmSLdJlkcm+mqnQpOjpuWiGXJS7uwlz1LVZC9p09C9HLqhaoF6SUo7eqxY4I/6Xm4TOhQnpyMv3XBmzmXvsLO+3rDT7H7nXBFm1mftWpY9EGrGDxZ5gwEFvCrYaAxHGOlYpajNgOa9ech7w== nagios@monitor.zoovy.com
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsUiW2oypUP6ZImCT/957f7wRUGdCaTCtx+B3FNloioo8r5IGOR/fgTDMZz51bMz06tdunLdtzvvP5/PAoXsU1ZOsi9LK8wBqwzzdg6IO+1+I/JO6kZj0/su2gBhCJ9VqvfuI0BIVjIylgwXISrHJ7z3N8jlIAq5D1y7MS/t3fs3d9SySiDmU4SulPluj8tyOC95jCWN05hEXpk3LinnW/AbgyntAtnCZFk/87+m+n3lB1/o73s+b6c2w1Us6GQKsfTHu5iA2dpBkNLOB5L1HcazwAfTKXd3j6fG5g61gzTWxhSssgtXnsBH6ThOL8LETjGdlKGfXHGgE40zqFdgHGw== root@dev



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



cat /root/.ssh/id_rsa.pub | ssh www1-crackle "cat >> ~/.ssh/authorized_keys"
/root/configs/ntp-time/ntp.sh


mkdir -m 755 -p /local/nginx/logs
mkdir -m 0775 /local/nginx-cache
mkdir -m 0755 -p /remote/crackle/users-sync
mkdir -m 0755 -p /remote/crackle/users
mv /httpd/htdocs /httpd/zoovy-htdocs

/etc/fstab
## MOUNT POINTS
crackle:/data/users-crackle /remote/crackle/users-sync nfs defaults,hard,noac,tcp,nfsvers=3,intr,noatime 0 0
crackle:/data/users-crackle /remote/crackle/users nfs defaults,hard,udp,rsize=8192,wsize=8192,nfsvers=3,intr,noatime 0 0

mount -a

/etc/init.d/iptables stop


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
## BUG FIXED IN 1.6
#ln -s libpng15.so.15. libpng15.so.15



