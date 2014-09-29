#!/bin/bash



## these new instances seem to burn into swap pretty fast.
sysctl vm.swappiness=25



##
## Create SWAP Files
##
mkdir -p /local/swap
export TOTALMEM=`cat /proc/meminfo  | grep "MemTotal" | cut -b 12-25`
export TOTALMEM=`expr $TOTALMEM / 1000`	## KB
export TOTALMEM=`expr $TOTALMEM / 1000`	## MB
if [ $TOTALMEM -lt 2 ] ; then export TOTALMEM=2; fi;	## minimum swap file(s) should be 3 (3gb)
while [ $TOTALMEM -gt 0 ] ; do
	echo $TOTALMEM;
	TOTALMEM=`expr $TOTALMEM - 1`

	SWAPFILE="/local/swap/file$TOTALMEM"
	if [ ! -f $SWAPFILE ] ; then
	  echo "Creating $SWAPFILE";
	  dd if=/dev/zero of=$SWAPFILE bs=1024 count=1000000
	  mkswap $SWAPFILE;
	fi;
	chown root:root $SWAPFILE
	chmod 0600 $SWAPFILE
	echo "Enabling $SWAPFILE";
	swapon $SWAPFILE
done

mkdir "/dev/shm/spooler";
chmod 777 "/dev/shm/spooler";



## 
echo "nameserver 8.8.8.8" > /etc/resolv.conf
  
  mkswap /local/swap/file2
  chown root:root /local/swap/file2
  chmod 0600 /local/swap/file2
  swapon /local/swap/file2

	mkdir -p /local/nginx
	chown nobody.nobody /local/nginx
	mkdir -p /local/nginx/tmp
	chown nobody.nobody /local/nginx/tmp
	
## local directories
  mkdir -p /local/media-cache/
  chmod 777 /local/media-cache/
  mkdir -p /local/media-cache/
  chmod 777 /local/media-cache/
  mkdir -p /local/cache
  chmod 777 /local/cache
  mkdir -p /local/disk1
  chmod 777 /local/disk1
  ln -s /local/disk1 /disk1
  mkdir -p /local/navbuttons
  chmod 777 /local/navbuttons
  mkdir -p /local/tmp
  chmod 777 /local/tmp
  mkdir -p /var/run/mysql
  chown mysql.mysql /var/run/mysql
  chmod 755 /var/run/mysql
  mkdir -p /local/mysql/tmp
  chown mysql.mysql /local/mysql/tmp
  chmod 755 /local/mysql/tmp
  mkdir -p /local/mysql/logs
  chown mysql.mysql /local/mysql/logs
  chmod 755 /local/mysql/logs
  
  
  mkdir /users
  cd /users; ln -sv /tank-*/* .

  mkdir -p /local/httpd/logs
  rm -Rf /httpd/logs
  ln -sv /local/httpd/logs /httpd/logs
  chown nobody.nobody /local/httpd/logs
  
  /etc/init.d/elasticsearch start
    
 # /etc/init.d/mysql start
  sleep 10;	## give mysql some time to start
  
  for USER in `/backend/platform/cfgecho.pl type:user` ; do    
  		lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    
  		DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    
  		DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    
  		DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    
  		HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    
  		ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    
  		/backend/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    
  		chown -R mysql.mysql "/users/$lcUSER/DATABASE"; 
  	done
  
  mysqladmin reload
  mysql -e 'show databases';

 ##  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done;

  ## memcache
  /etc/init.d/memcached start

	## redis
  mkdir -p /local/redis
  chmod 755 /local/redis
  /etc/init.d/redis start
  sleep 1;
  chmod 777 /var/run/redis.sock
	 	
	/bin/rm /usr/local/nginx/conf/vhosts/*.conf
	/backend/platform/dump-domains.pl
	/etc/init.d/uwsgi start
	/etc/init.d/nginx start

 
## START ELASTIC
  mkdir -p /local/elastic
  chmod 777 /local/elastic
 echo > /tmp/rebuild.sh
## Needs uppercase user to reindex
sudo service elasticsearch start
for USER in `/httpd/platform/cfgecho.pl type:user | tr '[:upper:]' '[:lower:]'` ; do
   echo "/httpd/scripts/elastic/reindex-public.pl $USER" >> /tmp/rebuild.sh
   echo "/httpd/scripts/elastic/reindex-private.pl $USER" >> /tmp/rebuild.sh
   done
 cat /tmp/rebuild.sh | at now

 
## PUSH DNS
# for USER in `/httpd/platform/cfgecho.pl type:user` ; do    
# ##	/httpd/servers/dns/push.pl $USER; 
# #done


## LET SUPPORT KNOW WHERE WE ARE
# for USER in `/httpd/platform/cfgecho.pl type:user` ; do    
# 	/httpd/platform/sethost.pl $USER; 
# done

## initializ monit of filesystems
#echo "" > /etc/monit.d/zfs
#for fs in `zfs list -H -t filesystem | cut -f 5` ; do
#   service=`echo $fs | sed "s/\//\_/g"`
#	echo "check filesystem $service with path $fs" >> /etc/monit.d/zfs
#   echo "   if space usage > 90% then alert" >> /etc/monit.d/zfs
#   echo "" >> /etc/monit.d/zfs
#done
#/etc/init.d/monit restart



            
 
