#!/bin/bash

HOTH="gw1-hoth www1-hoth www2-hoth www3-hoth www4-hoth www5-hoth"
CRACKLE="gw1-crackle www1-crackle www2-crackle www3-crackle www4-crackle www5-crackle"
POP="gw1-pop www1-pop www2-pop www3-pop www4-pop www5-pop"
BESPIN="gw1-bespin www1-bespin www2-bespin www3-bespin www4-bespin www5-bespin"
HOTH="gw1-hoth www1-hoth www2-hoth www3-hoth www4-hoth www5-hoth"
DAGOBAH="gw1-dagobah www1-dagobah www2-dagobah www3-dagobah www4-dagobah www5-dagobah"

SERVERS="$CRACKLE $POP $HOTH $BESPIN $DAGOBAH"
# SERVERS="$DAGOBAH"
# SERVERS="$BESPIN"

FOCUS="www1-hoth www2-hoth www3-hoth www4-hoth www5-hoth"

for d in $SERVERS ; do 

	echo $d;
   
   
   ## install new crontab
   cat crontab | ssh $d "cat | crontab"
#scp /root/configs/logrotate/* $d:/root/configs/logrotate/
#scp /root/configs/logrotate/http $d:/etc/logrotate.d/
#scp /root/configs/logrotate/kevorkian $d:/etc/logrotate.d/
#scp /root/configs/logrotate/nginx $d:/etc/logrotate.d/


#scp /root/configs/servers.txt $d:/root/configs/servers.txt
#ssh $d "echo /root/configs/kevorkian >> /etc/rc.d/rc.local"
	
#	ssh $d "echo ## refresh dns records (ssl certificates) >>  /etc/rc.d/rc.local ; echo /root/configs/dump-shm-files.pl >> /etc/rc.d/rc.local";
	
	# ssh $d "uptime; free -m";
	
#	cat rc.local | ssh $d "cat >/tmp/runme; sh /tmp/runme;"
	
#	ssh $d "uptime;";
	
#	echo $d "echo 15 > /proc/sys/net/ipv4/tcp_keepalive_intvl;"
#	ssh $d "netstat -nopt | grep -c 'tcp'"
#	echo ;

#	ssh $d "cat /etc/fstab | grep -v 'hoth' > /etc/fstab.now ; echo 'hoth:/data/users-hoth /remote/hoth/users nfs defaults,nolock,retrans=3,timeo=15,hard,rsize=8192,wsize=8192,nfsvers=4,intr,noatime 0 0' >> /etc/fstab.now ; cp /etc/fstab.now /etc/fstab; killall -9 /httpd/bin/httpd.x86_64; sleep 5 ; umount /remote/hoth/users; umount /remote/hoth/users-sync; mount -a ; /httpd/bin/apachectl start";
#	ssh $d "cp /etc/fstab /etc/fstab.20130227; cat /etc/fstab | grep -v 'bespin' > /etc/fstab.now ; echo 'bespin:/data/users-bespin /remote/bespin/users nfs defaults,nolock,retrans=3,timeo=15,hard,rsize=16384,wsize=16384,nfsvers=4,intr,noatime 0 0' >> /etc/fstab.now ; cp /etc/fstab.now /etc/fstab; killall -9 /httpd/bin/httpd.x86_64; sleep 5 ; umount /remote/bespin/users; umount /remote/bespin/users-sync; mount -a ; /httpd/bin/apachectl start";

#	ssh $d "/root/configs/dump-shm-files.pl"
		
#	ssh $d "/etc/init.d/iptables stop";
#	ssh $d "rm -Rf /local/cache/panrack"; 

#	ssh $d " hpasmcli -s 'show server' | grep 'ROM version'";
	
#	ssh $d "echo relayhost = 66.240.244.203 >> /etc/postfix/main.cf.x; cat /etc/postfix/main.cf >> /etc/postfix/main.cf.x; mv /etc/postfix/main.cf.x /etc/postfix/main.cf ; postfix reload;  postfix flush";
	
#	/usr/local/nagios/libexec/check_http -H $d -p 81
	
#	ssh $d "mii-tool eth0"
#	ssh $d 'ethtool  eth0 | egrep "Speed|Duplex|Auto-neg|pause"';
	
#	if [[ $d =~ ^gw ]] ; then
#		echo "GATEWAY"
#		ssh $d 'ethtool eth1 | egrep "Speed|Duplex|Auto-neg|pause"';
#	 fi
	
#	if [[ $d =~ "gw1" ]] ; then
#		echo $d;
#	fi

#	scp /httpd/conf/httpd.conf $d:/httpd/conf/httpd.conf
#	ssh $d "/httpd/bin/apachectl restart";

#	ssh $d "yum -y install tcpdump"
	 
	#scp iptables $d:/etc/sysconfig/iptables
	#scp rc.local $d:/etc/rc.d/rc.local
	# ssh $d "yum -y install jwhois"
	 
	## copy out new sysctl settings
	# scp sysctl.conf $d:/etc/sysctl.conf; ssh $d "sysctl -p";

	## restart all webservers
	#ssh $d "/httpd/bin/apachectl restart";

	## install new crontab
	## cat crontab | ssh $d "cat | crontab"

	##
	# ssh $d "/root/configs/ntp-time/ntp.sh"

	## 2/21 - add ntp sync to startup
	# ssh $d "echo /root/configs/ntp-time/ntp.sh >> /etc/rc.d/rc.local"
done

