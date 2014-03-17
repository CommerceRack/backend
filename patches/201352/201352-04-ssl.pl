      ## we use the same basic function for notifying load balancers
      $pstmt = "select DOMAIN,KEYTXT,CERTTXT from SSL_CERTIFICATES where ACTIVATED_TS>0 and MID=".($MID)." and DOMAIN like conca
      $sth = $udbh->prepare($pstmt);
      $sth->execute();
      while ( my ($HOSTDOMAIN,$SSL_KEY,$SSL_CERT) = $sth->fetchrow() ) {
         my ($sslHOST,$sslDOMAIN) = split(/\./,$HOSTDOMAIN,2);
         $sslHOST = uc($sslHOST);
         $sslDOMAIN = lc($sslDOMAIN);
         next if ($sslDOMAIN ne $DOMAIN);
      # print "$sslDOMAIN eq $DOMAIN\n";
            if (defined $REF{'%HOSTS'}->{$sslHOST}) {
               $REF{'%HOSTS'}->{$sslHOST}->{'SSL_KEY'} = $SSL_KEY;
               $REF{'%HOSTS'}->{$sslHOST}->{'SSL_CERT'} = $SSL_CERT;
               }
            else {
               warn "[WARN] SSL_CERTIFICATE for undefined host:$sslHOST\n";
               }
            }
         $sth->finish();


