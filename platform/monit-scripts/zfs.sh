echo "" > /etc/monit.d/zfs
for fs in `zfs list -H -t filesystem | cut -f 5` ; do
   service=`echo $fs | sed "s/\//\_/g"`
   echo "check filesystem $service with path $fs" >> /etc/monit.d/zfs
   echo "   if space usage > 90% then alert" >> /etc/monit.d/zfs
   echo "" >> /etc/monit.d/zfs
done
