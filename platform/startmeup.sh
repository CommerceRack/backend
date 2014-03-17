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

  cd /usr/local/elasticsearch/bin/service
 ./elasticsearch start
    
  /etc/init.d/mysql start
  sleep 10;	## give mysql some time to start
  
  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    
  		lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    
  		DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    
  		DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    
  		DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    
  		HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    
  		ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    
  		/httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    
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
	/httpd/platform/dump-domains.pl
	/etc/init.d/uwsgi start
	/etc/init.d/nginx start

 
## START ELASTIC
  mkdir -p /local/elastic
  chmod 777 /local/elastic
 echo > /tmp/rebuild.sh
## Needs uppercase user to reindex
for USER in `/httpd/platform/cfgecho.pl type:user | tr '[:upper:]' '[:lower:]'` ; do
   echo "/httpd/scripts/elastic/reindex-products.pl $USER" >> /tmp/rebuild.sh
   echo "/httpd/scripts/elastic/reindex-orders.pl $USER" >> /tmp/rebuild.sh
   done
 cat /tmp/rebuild.sh | at now

                
                

## PUSH DNS
 for USER in `/httpd/platform/cfgecho.pl type:user` ; do    
 	/httpd/servers/dns/push.pl $USER; 
 done


## LET SUPPORT KNOW WHERE WE ARE
 for USER in `/httpd/platform/cfgecho.pl type:user` ; do    
 	/httpd/platform/sethost.pl $USER; 
 done

 


























exit;

   12  killall -1 nginx
   13  tail -f /httpd/logs/*log
   14  ifconfig
   15  ps -fax
   16  ifconfig
   17  telnet localhost 80
   18  ps -fax
   19  mount
   20  ps -fax
   21  /etc/init.d/platform stop
   22  /etc/init.d/platform start
   23  ps -fax
   24  /httpd/bin/apachectl start
   25  tail -f /httpd/logs/*
   26  ps -fax
   27  df -k
   28  cd /httpd/logsls
   29  cd /httpd/logs
   30  ls
   31  ls -la
   32  rm *
   33  cd /usr/local/src
   34  ls
   35  cd /usr/local/src
   36  ls
   37  cd /var/logs
   38  ls
   39  cd /var
   40  ls
   41  du
   42  cd swap/
   43  ls
   44  rm swap1 
   45  ls
   46  ps -fax
   47  uptime
   48  df
   49  df -k | more
   50  ls
   51  cd /
   52  ls
   53  cd isk
   54  cd disk1/
   55  ls
   56  ls -la
   57  cd ..
   58  rm -Rf disk1/
   59  /httpd/bin/apachectl stop
   60  /etc/init.d/platform stop
   61  mv disk1 disk2
   62  mkdir /local/disk1
   63  ln -s /local/disk1 .
   64  ls
   65  rm disk1
   66  ls -la /local/disk1 
   67  rm /local/disk1
   68  mkdir /local/disk1
   69  ln -s /local/disk1
   70  ls
   71  /etc/init.d/platform start
   72  /httpd/bin/apachectl start
   73  ps f-ax
   74  ps -fax
   75  ls
   76  ls -la
   77  cd logs
   78  ls
   79  cd/proxy
   80  ls
   81  cd /local/disk1/1
   82  ls
   83  cd /local/disk1/
   84  ls
   85  ls -la
   86  du
   87  tail -f /local/httpd/logs/*
   88  tail -f /httpd/logs/*
   89  ps -fax
   90  mysql
   91  cd /local/httpd/
   92  ls
   93  cd /httpd/logs
   94  ls
   95  ls -la
   96  tail -f error_log  | more
   97  chmod 777 /var/run/redis.sock
   98  tail -f error_log  | more
   99  exit
  100  ps f-ax
  101  ps -fax
  102  ls
  103  ls -la
  104  cd /
  105  ls
  106  rm -Rf disk2/
  107  df
  108  df -k
  109  exit
  110  ps -fax
  111  top
  112  exit
  113  mysql
  114  w
  115  ps aux
  116  tail -f /httpd/logs/*
  117  df
  118  df -h
  119  cd /var/log/
  120  du
  121  cd /httpd/logs/
  122  du -h
  123  cd /usr/local/nginx/logs/
  124  du -h
  125  lsof
  126  ls -l /usr/lib/locale/locale-archive
  127  ls -lh /usr/lib/locale/locale-archive
  128  ls -lh /tank-2bhip/2bhip/DATABASE/SKU_LOOKUP.MYD
  129  df -h
  130  w
  131  ps aux
  132  ps aux | grep gs
  133  exit
  134  ls /tmp
  135  exit
  136  ls
  137  zpool list
  138  exit
  139  zpool iostat 5 500
  140  exit
  141  df
  142  /etc/init.d/crond start
  143  exit
  144  mysql
  145  zfs list
  146  exit
  147  ps -fax
  148  tail -f /httpd/logs/*
  149  exit
  150  w
  151  ps aux
  152  zfs list
  153  ps aux
  154  w
  155  exit
  156  ps -fax
  157  df
  158  df /
  159  ps f-ax
  160  ps -fax
  161  exit
  162  df -h
  163  exit
  164  joe /etc/redis/redis.conf
  165  exit
  166  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -a -E "select * from SSL_IPADDRESSES"; done;
  167  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  168  exit
  169  zfs list
  170  w
  171  df -h
  172  ls /tmp
  173  cd /tmp
  174  du -h
  175  cd /var/log/
  176  du -h
  177  cd /httpd/logs/
  178  du -h
  179  exit
  180  joe /etc/rc.local 
  181  exit
  182  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done
  183  exit
  184  ps aux | grep cron
  185  ls -l /httpd/servers/dns/push.pl
  186  zfs list
  187  ls -l /httpd/servers/dns/push.pl
  188  exit
  189  for USER in `/httpd/platform/cfgecho.pl type:user` ; do /httpd/servers/dns/push.pl $USER; done
  190  exit
  191  joe /etc/redis/redis.conf
  192  exit
  193  zfs list
  194  ls -l /usr/local/nginx/conf/
  195  exit
  196  joe /etc/commercerack.ini
  197  joe /etc/hosts
  198  exit
  199  /bin/hostname `/httpd/platform/cfgecho.pl global hostname`
  200  exit
  201  zpool destroy tank-2bhip ; zpool destroy tank-endor1; zpool destroy tank-endor1b;
  202  exit
  203  joe /etc/resolv.conf
  204  exit
  205  rm /etc/localtime;
  206  ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime;
  207  date;
  208  exit
  209  w
  210  ps aux
  211  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done
  212  zfs list
  213  exit
  214  mkdir -p /local/elastic
  215  chmod 777 /local/elastic
  216  cd /usr/local/elasticsearch/bin/service
  217  ./elasticsearch start
  218  exit
  219  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done
  220  mysql
  221  zfs list
  222  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done
  223  joe /etc/commercerack/cubworld.ini
  224  /httpd/platform/nginx/dump-vhosts.pl 
  225  /httpd/platform/dump-domains.pl
  226  /httpd/servers/dns/push.pl cubworld
  227  killall -9 nginx;
  228  /httpd/bin/platform.sh start;
  229  exit
  230  zpool import
  231  zpool import tank-cubworld
  263  ## memcache
  264  /etc/init.d/memcached start
  265  mkdir -p /local/redis
  266  chmod 755 /local/redis
  267  /etc/init.d/redis start
  268  chmod 777 /var/run/redis.sock
  269  ## don't forget to rebuild elasticcache
  270  /httpd/platform/dump-domains.pl
  271  /httpd/bin/platform.sh init
  272  /httpd/platform/nginx/dump-vhosts.pl
  273  /etc/init.d/platform start
  274  /httpd/bin/apache start
  275  ## PUSH DNS:
  276  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    /httpd/servers/dns/push.pl $USER; done
  277  /httpd/bin/platform.sh start
  278  /httpd/bin/apachectl start
  279  ps -fax


## START ELASTIC
  mkdir -p /local/elastic
  chmod 777 /local/elastic
  cd /usr/local/elasticsearch/bin/service
 ./elasticsearch start
 for USER in `/httpd/platform/cfgecho.pl type:user` ; do    /httpd/scripts/elastic/reindex-products.pl $USER; done



  296  date
  297  ps -fax
  298  exit
  299  joe /httpd/modules/BATCHJOB.pm 
  300  tail -f /httpd/logs/*
  301  fg
  302  touch /dev/shm/reload 
  303  tail -f /local/httpd/logs/*
  304  tail -f /httpd/logs/*
  305  fg
  306  touch /dev/shm/reload 
  307  cat /tmp/job 
  308  joe /tmp/job 
  309  chmodd 777 tmp
  310  chmodd 777 tmp/job
  311  chmod 777 /tmp/job
  312  /tmp/job 
  313  fg
  314  /tmp/job 
  315  fg
  316  /tmp/job 
  317  /tmp/job fg
  318  fg
  319  /tmp/job fg
  320  fg
  321  /tmp/job fg
  322  fg
  323  /tmp/job fg
  324  fg
  325  joe /tmp/job
  326  /tmp/job fg
  327  /tmp/job 
  328  fg
  329  /tmp/job 
  330  fg
  331  ls
  332  joe /tmp/job2 
  333  exit
  334  fg
  335  exit
  336  mysql
  337  mysql CUBWORLD
  338  ls
  339  cd /local/httpd/logs
  340  ls
  341  cd/httpd/logsls
  342  cd /httpd/logs
  343  ls
  344  ls -la
  345  rm nginx-2bhip-*
  346  ls
  347  ls -la
  348  exit
  349  touch /dev/shm/reload
  350  joe /httpd/modules/BATCHJOB.pm
  351  touch /dev/shm/reload
  352  fg
  353  joe /httpd/psgi-apps/jsonapi.l
  354  joe /httpd/psgi-apps/jsonapi.ini 
  355  /httpd/logs/uwsgi-jsonapi.log
  356  ls -la /httpd/logs/uwsgi-jsonapi.log
  357  tail -f /httpd/logs/uwsgi-jsonapi.log
  358  exit
  359  exit;
  360  mysql ORDERS
  361  mysql SNAP
  362  mysql
  363  exit
  364  ls -la /var/run/mysql/mysql.sock
  365  mysql
  366  mysql /var/run/mysql/mysql.sock
  367  mysql --help
  368  mysql --socket /var/run/mysql/mysql.sock
  369  exit
  370  perl -e 'use lib "/httpd/modules"; ZOOVY::resolve_user_db("gourmet");
  371  perl -e 'use lib "/httpd/modules"; ZOOVY::resolve_user_db("gourmet");'
  372  perl -e 'use lib "/httpd/modules"; use ZOVOY; ZOOVY::resolve_user_db("gourmet");'
  373  perl -e 'use lib "/httpd/modules"; use ZOOVY; ZOOVY::resolve_user_db("gourmet");'
  374  perl -e 'use lib "/httpd/modules"; use ZOOVY; print Dumper(ZOOVY::resolve_user_db("gourmet"));'
  375  perl -e 'use lib "/httpd/modules"; use ZOOVY; print Dumper(ZOOVY::resolve_user_db("gourmet")); use Data::Dumper;'
  376  exit
  377  touch /dev/shm/reload 
  378  tail -f /httpd/logs/*
  379  joe /httpd/modules/BATCHJOB.pm
  380  tail -f /httpd/logs/*
  381  exit
  382  cd /users
  383  uptime
  384  find . -type l -exec test ! -e {} \; -delete
  385  ls
  386  find /users -type l -exec test ! -e {} \; -delete
  387  exit
  388  mysql -e "set @@GLOBAL.sql_mode='';"; exit;
  389  mkdir /usr/local/src
  390  cd /usr/local/src
  391  wget http://search.cpan.org/CPAN/authors/id/G/GM/GMPASSOS/XML-Smart-1.6.9.tar.gz
  392  tar -xzvf XML-Smart-1.6.9.tar.gz
  393  cd XML-Smart-1.6.9
  394  perl Makefile.PL
  395  make install
  396  exit
  397  exit;
  398  joe /httpd/bin/platform.sh
  399  for d in $EC2; do ssh $d "/httpd/bin/uwsgi --init /httpd/psgi-apps/static.ini -HUP; /httpd/bin/uwsgi --init /httpd/psgi-apps/jsonapi.ini -HUP"; done
  400  exit
  401  ps -fea
  402  ps f-ax
  403  ps -fax
  404  exit
  405  cd /tank-
  406  ls
  407  cd /tank-cubworld/cubworld/
  408  ls
  409  ls -la
  410  exit
  411  mysql -e "set @@GLOBAL.sql_mode=''"; exit;
  412  ps f-ax
  413  ps -fax
  414  uptime
  415  tail -f /local/httpd/logs/*
  416  tail -f /httpd/logs/*
  417  /etc/init.d//mysql start
  418  ps -fax
  419  mysqld
  420  chmod 777 /local/mysql/tmp
  421  mysqld
  422  chmod -R 777 /local/mysql/tmp
  423  mysqld
  424  cd /local/mysql/
  425  cd logs
  426  ls
  427  ls -la
  428  chmod mysql.mysql -R *
  429  chmod -R mysql.mysql  *
  430  chown -R mysql.mysql  *
  431  /etc/init.d//mysql start
  432  mysqld
  433  df -k
  434  cd /var/log
  435  ls
  436  cd /usr/local/src
  437  ls
  438  cd /httpd
  439  ls
  440  cd logs
  441  ls
  442  ls -la
  443  rm *
  444  cd /
  445  ls
  446  cd /root
  447  ls
  448  ls -la
  449  df -k
  450  cd /
  451  ls
  452  cd home
  453  ls
  454  cd..
  455  ls
  456  cd var
  457  ls
  458  cd /var/
  459  ls
  460  cd log
  461  ls
  462  ls -la
  463  dmesg
  464  ls
  465  cd /tmp
  466  ls
  467  ls -la
  468  ls -la | more
  469    
  470  rm *
  471  rm -Rf BUY-cubworld-138316*
  472  df
  473  df -k
  474  cd /
  475  ls
  476  cd backup
  477  ls
  478  cd ..
  479  cd /var/lib
  480  ls
  481  cd /var/llib
  482  ls
  483  cd /var/lib
  484  cd mysql/
  485  ls
  486  ls -la
  487  cd mysql
  488  ls
  489  du
  490  cd ..
  491  ls
  492  du
  493  cd ..
  494  ls
  495  du
  496  cd /
  497  cd /ur
  498  ls
  499  rm /var/swap/swap1 
  500  swapoff /var/swap/swap1 
  501  rm /var/swap/swap1
  502  /etc/init.d/mysql start
  503  ps f-ax
  504  ps -fax
  505  ls
  506  exit
  507  mysql
  508  ps -fea
  509  mysql
  510  chown -R mysql.mysql /var/lib/mysql/
  511  ls
  512  ps -fax
  513  cd /usr/
  514  ls
  515  cd /var
  516  ls
  517  du
  518  cd spool/
  519  ls
  520  du
  521  df -k
  522  cd /
  523  ls
  524  ls -la
  525  cd tank-2bhip/
  526  l
  527  ls
  528  cd..
  529  ls
  530  zpool remove tank-2bhip
  531  cd medi
  532  ls
  533  cd lost
  534  ls
  535  cd root
  536  ls
  537  cd /httpd
  538  cd static
  539  ls
  540  ls -la
  541  du | more
  542  ls
  543  cd zmvc/ls
  544  ls
  545  ls -la
  546  cd zmvc
  547  ls
  548  rm -Rf 201203
  549  rm -Rf 201205
  550  rm -Rf 201209
  551  rm -Rf 201211
  552  df
  553  exit
  554  joe /etc/fstab 
  555  mount
  556  df -k
  557  mount
  558  df
  559  df -k
  560  exit
  561  ls
  562  ls -la
  563  exit
  564  df
  565  df-k
  566  exit
  567  zpool create tank-smbsi /dev/xvdf
  568  zpool create tank-stateofnine /dev/xvdg
  569  hostname dagobah1
  570  exit
  571  zfs list
  572  zfs set recordsize=64k tank-sbmsi
  573  zfs set recordsize=64k tank-smbsi
  574  zfs set recordsize=64k tank-stateofnine
  575  zfs set atime=off tank-sbmsi
  576  zfs set atime=off tank-smbsi
  577  zfs set atime=off tank-stateofnine
  578  zfs list
  579  exit
  580  zpool list
  581  hostname dagobah2
  582  joe /etc/hosts
  583  ifconfig
  584  fg
  585  joe /etc/hosts
  586  exit
  587  joe /etc/commercerack.ini
  588  echo > /etc/resolv.conf
  589  echo "nameserver 192.168.6.2" >> /etc/resolv.conf
  590  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  591  joe /etc/commercerack.ini
  592  mkdir -p /local/media-cache/
  593  chmod 777 /local/media-cache/
  594  mkdir -p /local/cache
  595  chmod 777 /local/cache
  596  mkdir -p /local/disk1
  597  chmod 777 /local/disk1
  598  ln -s /local/disk1 /disk1
  599  mkdir -p /local/navbuttons
  600  chmod 777 /local/navbuttons
  601  mkdir -p /local/tmp
  602  chmod 777 /local/tmp
  603  mkdir -p /var/run/mysql
  604  chown mysql.mysql /var/run/mysql
  605  chmod 755 /var/run/mysql
  606  mkdir -p /local/mysql/tmp
  607  chown mysql.mysql /local/mysql/tmp
  608  chmod 755 /local/mysql/tmp
  609  mkdir -p /local/mysql/logs
  610  chown mysql.mysql /local/mysql/logs
  611  chmod 755 /local/mysql/logs
  612  rmdir /httpd/logs
  613  mkdir -p /local/httpd/logs
  614  ln -s /local/httpd/logs /httpd/logs
  615  ## start elastic now.. so it's ready later.
  616  mkdir -p /local/elastic
  617  chmod 777 /local/elastic
  618  cd /usr/local/elasticsearch/bin/service
  619  ./elasticsearch start
  620  rm /users/*
  621  mkdir /users
  622  cd /users; ln -s /tank-*/* .
  623  ln -s /etc/my.cnf /var/lib/mysql/my.cnf
  624  ln -fvs /etc/my.cnf /usr/share/my.cnf 
  625  rm /users/cubworld
  626  rm /etc/commercerack/cubworld.ini
  627  rm /usr/local/nginx/conf/vhosts/cubworld.conf
  628  /etc/init.d/mysql start
  629  zpool list
  630  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    /httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    chown -R mysql.mysql "/users/$lcUSER/DATABASE"; done
  631  mysqladmin reload
  632  mysql -e 'show databases';
  633  for USER in `/httpd/platform/cfgecho.pl type:user` ; do smbsi/mysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  634  zfs list
  635  exit
  636  mkdir /local/swap
  643  exot
  644  exit
  645  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    /httpd/servers/dns/push.pl $USER; done
  646  mysql SMBSI
  647  mysql
  648  mysqld_safe 
  649  INSERT INTO `DOMAIN_HOSTS` VALUES ('2013-10-17 17:59:48',63900,'8185f9.dagobah.zoovy.net','APP','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=&REDIR=&URI=',''),('2013-10-17 17:59:48',63900,'8185f9.dagobah.zoovy.net','M','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=',''),('2013-10-17 17:59:48',63900,'8185f9.dagobah.zoovy.net','WWW','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=05891A38%2dE9B0%2d11E2%2d8838%2dA660F167',''),('2013-10-17 17:59:48',63900,'8195b7aa5.dagobah.zoovy.net','APP','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=9A19A3AC%2dC278%2d11E2%2d9E1A%2dF0EA5310',''),('2013-10-17 17:59:48',63900,'8195b7aa5.dagobah.zoovy.net','M','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=9A19A3AC%2dC278%2d11E2%2d9E1A%2dF0EA5310',''),('2013-10-17 17:59:48',63900,'8195b7aa5.dagobah.zoovy.net','WWW','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=9A19A3AC%2dC278%2d11E2%2d9E1A%2dF0EA5310',''),('2013-10-30 15:09:07',63900,'allcosmeticswholesale.com','APP','REDIR','CHKOUT=app%2dallcosmeticswholesale%2dcom%2eapp%2dhosted%2ecom&HOSTNAME=APP&HOSTTYPE=REDIR&luser=support%2ftimo&PROJECT=C9F733A8%2d8A9E%2d11E2%2d8BCA%2d1ACFEA1F&REDIR=www%2eallcosmeticswholesale%2ecom&ts=1379370989&URI=','app-allcosmeticswholesale-com.app-hosted.com'),('2013-10-30 15:09:07',63900,'allcosmeticswholesale.com','M','REDIR','CHKOUT=m%2dallcosmeticswholesale%2dcom%2eapp%2dhosted%2ecom&HOSTNAME=M&HOSTTYPE=REDIR&REDIR=app%2eallcosmeticswholesale%2ecom&URI=','m-allcosmeticswholesale-com.app-hosted.com'),('2013-10-30 15:09:07',63900,'allcosmeticswholesale.com','WWW','VSTORE','BING_SITEMAP=%3cmeta+name&CHKOUT=www%2dallcosmeticswholesale%2dcom%2eapp%2dhosted%2ecom&GOOGLE_SITEMAP=%3cmeta+name&HOSTNAME=WWW&HOSTTYPE=VSTORE','www-allcosmeticswholesale-com.app-hosted.com'),('2013-10-17 17:59:48',63900,'smbsi.zoovy.com','APP','REDIR','CHKOUT=&HOSTTYPE=REDIR&PROJECT=&REDIR=&URI=',''),('2013-10-17 17:59:48',63900,'smbsi.zoovy.com','M','REDIR','CHKOUT=&HOSTTYPE=REDIR&REDIR=m%2esuite7beauty%2ecom&URI=',''),('2013-10-17 17:59:48',63900,'smbsi.zoovy.com','WWW','REDIR','CHKOUT=&HOSTTYPE=REDIR&REDIR=suite7beauty%2ecom&URI=',''),('2013-10-17 17:59:48',63900,'suite7beauty.com','M','VSTORE','CHKOUT=&HOSTTYPE=VSTORE',''),('2013-10-17 17:59:48',63900,'suite7beauty.com','WWW','VSTORE','CHKOUT=&HOSTTYPE=VSTORE',''),('2013-10-28 15:36:40',63900,'sweet7beauty.com','M','REDIR','CHKOUT=m%2dsweet7beauty%2dcom%2eapp%2dhosted%2ecom&HOSTNAME=M&HOSTTYPE=REDIR&REDIR=m%2esuite7beauty%2ecom&URI=','m-sweet7beauty-com.app-hosted.com'),('2013-10-28 15:36:40',63900,'sweet7beauty.com','WWW','REDIR','CHKOUT=www%2dsweet7beauty%2dcom%2eapp%2dhosted%2ecom&HOSTNAME=WWW&HOSTTYPE=REDIR&REDIR=suite7beauty%2ecom&URI=','www-sweet7beauty-com.app-hosted.com'),('2013-10-17 17:59:48',63900,'thesev.com','APP','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=9A19A3AC%2dC278%2d11E2%2d9E1A%2dF0EA5310',''),('2013-10-17 17:59:48',63900,'thesev.com','WWW','APP','CHKOUT=&HOSTTYPE=APP&PROJECT=9A19A3AC%2dC278%2d11E2%2d9E1A%2dF0EA5310','');
  650  mysql SMBSI
  651  ps -fea
  652  tail -f /var/log/mysqld.log
  653  ls -la
  654  exit
  655  ls
  656  ls -la
  657  mysql SMBSI < dump 
  658  mysql
  659  pwd
  660  mysqladmin shutdown
  661  mysql SMBSI < dump 
  662  joe dump 
  663  mysql SMBSI < dump 
  664  joe dump 
  665  mysql SMBSI < dump 
  666  mysql STATEOFNINE
  667  mysql
  668  mysqlmadin shutdown
  669  mysqladmin shutdown
  670  rm /users/*
  671  mkdir /users
  672  cd /users; ln -s /tank-*/* .
  673  /etc/init.d/mysql start
  674  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    /httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    chown -R mysql.mysql "/users/$lcUSER/DATABASE";  done;
  675  /etc/init.d/mysql start
  676  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    /httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    chown -R mysql.mysql "/users/$lcUSER/DATABASE"
  677  mysqladmin reload
  678  mysql -e 'show databases';
  679  for USER in `/httpd/platform/cfgecho.pl type:user` ; do smysql $USER -A -e "select * from SSL_IPADDRESSES"; done;for USER in `/httpd/platform/cfgecho.pl type:user` ; do smysql $USER -A -e "select * from SSL_IPADDRESSES";
  680  for USER in `/httpd/platform/cfgecho.pl type:user` ; do smysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  681  cd
  682  for USER in `/httpd/platform/cfgecho.pl type:user` ; do smysql $USER -A -e "select * from SSL_IPADDRESSES";
  683  exit
  684  for USER in `/httpd/platform/cfgecho.pl type:user` ; do smysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  685  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  686  /etc/init.d/memcached  start
  687  mkdir -p /local/redis
  688  /etc/init.d/redis start
  689  chmod 777 /var/run/redis.soc
  690  ps f-ax
  691  ps -fax
  692  ps -fax | grep "mem"
  693  mkdir -p /local/httpd/logs
  694  /httpd/platform/dump-domains.pl
  695  chown -R mysql.mysql /tank*/*DATABASE
  696  chown -R mysql.mysql /tank*/*/DATABASE
  697  /httpd/platform/dump-domains.pl
  698  /httpd/platform/nginx/dump-vhosts.pl
  699  /etc/init.d/platform start
  700  /httpd/bin/apache start
  701  cd /httpd
  702  ls
  703  cd bin
  704  ls
  705  /httpd/bin/apache start
  706  /httpd/bin/apachectl start
  707  /etc/init.d/platform start
  708  /httpd/bin/platform.sh startfor USER in `/httpd/platform/cfgecho.pl type:user` ; do
  709     /httpd/servers/dns/push.pl $USER
  710  mysql
  711  mysql SMBSI
  712  /httpd/platform/nginx/dump-vhosts.pl
  713  /httpd/platform/dump-domains.pl
  714  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    /httpd/servers/dns/push.pl $USER; done
  715  /httpd/servers/dns/push.pl thesev.com
  716  /httpd/servers/dns/push.pl smbsi
  717  telnet localhost
  718  telnet localhost 4000
  719  /httpd/platform/nginx/dump-vhosts.pl
  720  /httpd/platform/dump-domains.pl
  721  /httpd/modules/binedit.pl /dev/shm/domainhost-detail.bin 
  722  /httpd/servers/dns/push.pl smbsi
  723  exit
  724  fg
  725  exit
  726  joe /etc/fstab
  727  ls
  728  joe /etc/hosts
  729  ifconfig
  730  fg
  731  cat /etc/commercerack.ini
  732  zfs list
  733  rm /users/*
  734  mkdir /users
  735  cd /users; ln -s /tank-*/* .
  736  ln -s /etc/my.cnf /var/lib/mysql/my.cnf
  737  ln -fvs /etc/my.cnf /usr/share/my.cnf 
  738  rm /users/cubworld
  739  rm /etc/commercerack/cubworld.ini
  740  rm /usr/local/nginx/conf/vhosts/cubworld.conf
  741  /etc/init.d/mysql start
  742  for USER in `/httpd/platform/cfgecho.pl type:user` ; do    lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    /httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    chown -R mysql.mysql "/users/$lcUSER/DATABASE"; done
  743  mysqladmin reload
  744  mysql -e 'show databases';
  745  ls
  746  cd /users/
  747  lls
  748  ls
  749  cd 
  750  rm /users/*
  751  mkdir /users
  752  cd /users; ln -s /tank-*/* .
  753  rm /users/*
  754  mkdir /users
  755  cd /users; ln -s /tank-*/* .
  756  cd /users; ln -sv /tank-*/* .
  757  ls
  758  ls -la
  759  zfs list
  760  rm /users/*
  761  mkdir /users
  762  cd /users; ln -s /tank-*/* .
  763  ls
  764  cd /tank-stateofnine/
  765  ls
  766  for USER in `/httpd/platform/cfgecho.pl type:user` ; do mysql $USER -A -e "select * from SSL_IPADDRESSES"; done;
  767  ## make sure db permissions are set right
  768  chown nobody:nobody -R /tank*/*
  769  chown mysql:mysql -R /tank*/*/DATABASE
  770  /etc/init.d/memcached  start
  771  mkdir -p /local/redis
  772  /etc/init.d/redis start
  773  chmod 777 /var/run/redis.sock
  774  mkdir -p /local/httpd/logs
  775  /httpd/platform/dump-domains.pl
  776  /httpd/platform/nginx/dump-vhosts.pl
  777  /etc/init.d/memcached  start
  778  mkdir -p /local/redis
  779  /etc/init.d/redis start
  780  chmod 777 /var/run/redis.sock
  781  mkdir -p /local/httpd/logs
  782  /httpd/platform/dump-domains.pl
  783  /httpd/platform/nginx/dump-vhosts.pl
  784  /etc/init.d/platform start
  785  /httpd/bin/platform.sh start
  786  /httpd/bin/apache start


## PUSH DNS:
for USER in `/httpd/platform/cfgecho.pl type:user` ; do    /httpd/servers/dns/push.pl $USER; done

for USER in `/httpd/platform/cfgecho.pl type:user` ; do    lcUSER=`echo $USER | tr '[:upper:]' '[:lower:]'`;    DBPASS=`/httpd/platform/cfgecho.pl $USER dbpass`;    DBUSER=`/httpd/platform/cfgecho.pl $USER dbuser`;    DBNAME=`/httpd/platform/cfgecho.pl $USER dbname`;    HOME=`/httpd/platform/cfgecho.pl "$USER" home`;    ln -sfv "/users/$lcUSER/DATABASE" "/var/lib/mysql/$USER";    /httpd/platform/mysql/grant.pl "$USER" "$DBUSER" "$DBPASS" | mysql;    chown -R mysql.mysql "/users/$lcUSER/DATABASE"; done


  838  mysql
  839  mysql SMBSI < foo
  840  mysql
  841  mysql SMBSI
  842  s
  843  ls
  844  cat foo 
  845  joe foo
  846  mysqldump SMBSI AMAZON_DOCUMENT_CONTENTS BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  847  mysqldump --nolock SMBSI AMAZON_DOCUMENT_CONTENTS BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  848  mysqldump | grep "lock"
  849  mysqldump | more
  850  mysqldump --help | grep "lock"
  851  mysqldump --skip-lock SMBSI AMAZON_DOCUMENT_CONTENTS BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  852  mysqldump --skip-lock-all-tables SMBSI AMAZON_DOCUMENT_CONTENTS BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  853  mysql
  854  mysqldump --skip-lock-all-tables SMBSI AMAZON_DOCUMENT_CONTENT
  855  mysqldump --skip-lock-all-tables SMBSI AMAZON_DOCUMENT_CONTENTS
  856  mysql
  857  ls
  858  mysqldump --skip-lock-all-tables SMBSI BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  859  mysqldump --skip-lock-all-tables --skip-add-locks SMBSI BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  860  mysqldump --single-transaction --skip-lock-all-tables --skip-add-locks SMBSI BATCH_PARAMETERS CAMPAIGNS CIENGINE_AGENTS DEVICES DOMAIN_HOSTS DOMAINS_POOL DSS_COMPETITORS EBAY_JOBS EBAY_PROFILES EVENT_RECOVERY_TXNS GUID_REGISTRY INVENTORY_DETAIL OAUTH_SESSIONS;
  861  ls
  862  mysql
  863  mysql SMBSI
  864  ls
  865  rm DOMAIN_HOSTS.ibd 
  866  fg
  867  ls
  868  joe foo 
  869  cat foo
  870  mysql SMBSI --v
  871  mysql SMBSI -V
  872  mysql SMBSI 
  873  mysql SMBSI
  874  mysqld
  875  cd SMBSI
  876  cp ~/DOMAIN* .
  877  ls
  878  cd
  879  cp ~/root/DOMAIN* .
  880  cp /root/DOMAIN* .
  881  ls
  882  mysqld
  883  ~>
  884  mkdir old
  885  mv *.ibd old
  886  ls
  887  ls old/
  888  mysqld
  889  joe /etc/my.cnf
  890  mysqld
  891  joe /etc/commercerack/stateofnine.ini
  892  whois stateofnine.com
  893  fg
  894  chown nobody:nobody -R /tank*/*
  895  ps -fax
  896  tai -f /local/httpd/logs/*
  897  tail -f /httpd/logs/*
  898  mysql STATEOFNINE
  899  ls
  900  chown mysql:mysql -R /tank*/*/DATABASE
  901  mysqladmin reload
  902  mysqladmin refresh
  903  tail -f /httpd/logs/*
  904  exit
  905  ls
  906  ssh bespin2
  907  exit
  908  ps -fax
  909  mysql
  910  /etc/init.d/mysql start
  911  ps -fax
  912  mysql
  913  ls
  914  cd /etc/init
  915  exit
  916  history | grep "mkdir"
  917   mkdir -p /local/elastic
  918   mkdir -p /local/media-cache/
  919  mkdir -p /local/cache
  920   mkdir -p /local/disk1
  921   mkdir -p /local/navbuttons
  922   mkdir -p /local/tmp
  923   mkdir -p /var/run/mysql
  924   mkdir -p /local/mysql/tmp
  925    mkdir -p /local/mysql/logs
  926  mkdir /users
  927   mkdir -p /local/redis
  928   mkdir -p /local/elastic
  929  mkdir -p /local/navbuttons
  930   mkdir -p /local/redis
  931   mkdir -p /local/httpd/logs
  932  chown mysql.mysql /local/mysql/
  933  chown nobody.nobody /local/*
  934  chown mysql.mysql /local/mysql/
  935  chown mysql.mysql /local/mysql
  936  /etc/init.d/mysql 
  937  /etc/init.d/mysql start
  938  /etc/init.d/redis start
  939  /etc/init.d/memcached start
  940  ps -fax
  941  joe /httpd/conf/httpd.conf
  942  ps -fax
  943  ls
  944  ps f-ax
  945  ps -fax
  946  /httpd/platform/dump-domains.pl
  947  zfs list
  948  history > foo\
  949  history > foo
  950  joe foo
  951  mysql
  952  ls /var/run/mysql/
  953  ls -la 
  954  ls /var/run/mysql/my
  955  ps -fax
  956  /etc/init.d/mysql  start
  957  mysqld
  958  mkdir -p /local/tmp/mysql
  959  chown mysql.mysql /local/tmp/mysql
  960  mysqld
  961  chmod 777 /local/tmp/mysql
  962  mysqld
  963  cd /local/mysql/tmp
  964  ls
  965  mount
  966  cd /
  967  ls
  968  ls -la
  969  mysqld
  970  chmod 755 /local/mysql/
  971  chmod 755 /local/mysql
  972  mysqld
  973  ls -la /local/mysql/tmp
  974  chown mysql.mysql  /local/mysql/tmp
  975  ls -la /local/mysql/tmp
  976  mysqld
  977  chown mysql.mysql -R /local/mysql
  978  mysqld
  979  joe /etc/my.cnf
  980  /etc/init.d/mysql  start
  981  /httpd/platform/dump-domains.pl
  982  /httpd/platform/nginx/dump-vhosts.pl
  983  ifconfig
  984  ls -la /local
  985  ls -la /local/
  986  /etc/init.d/redis start
  987  /etc/init.d/memcached start
  988  /httpd/bin/platform.sh start
  989  ps f-ax
  990  ps -fax
  991  /httpd/bin/apachectl start
  992  ps -fax
  993  ls
  994  ls -la
  995  df -k
  996  du
  997  ls
  998  ls-la
  999  ls -la
 1000  exit
 1001  istory
 1002  history
 1003  history > startmeup.sh
