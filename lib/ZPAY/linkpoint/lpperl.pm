# lpperl.pm - LinkPoint API PERL module
#
#
# Copyright 2004 LinkPoint International, Inc. All Rights Reserved.
# 
# This software is the proprietary information of LinkPoint International, Inc.  
# Use is subject to license terms.

## Y O U   D O   N O T   N E E D   T O   E D I T   T H I S   F I L E ##


package LPPERL;

$LPPERL::REVISION = '$Id: LPPERL.pm,v 3.0.012 01/28/2004 12:00:00 smoffet solson $';
$LPPERL::VERSION  = '3.0.012';

my $debugging = 0;
my $webspace  = 1;  # format xml debug output for browser
my $xmlin     = 0;  # incoming data is in XML format


# FIGURE OUT THE OS WE'RE RUNNING UNDER
# Some systems support the $^O variable.  If not
# available then require() the Config library
unless($OS)
{
    unless($OS = $^O)
    {
	require Config;
	$OS = $Config::Config{'osname'};
    }
}

if($OS=~/Win/i)
{
    $OS = 'WINDOWS';
}

sub new
{
    my($class, $initializer) = @_;
    my $self = {};
    if($class eq "LPPERL")
    {
        bless $self, ref $class || $class || $DefaultClass;
    }
    else
    {
        bless $self, ref $class || $class;
    }
    return $self;
}

    #########################################
    #
    #	S U B   p r o c e s s ( ) 
    #
    #	process a hash table or XML string 
    #	using LIBLPERL.SO and LIBLPSSL.SO
    #
    #########################################

sub process
{
    package liblperl;
    require Exporter;
    require DynaLoader;
    @ISA = qw(Exporter DynaLoader);
    @EXPORT = qw( );
    bootstrap liblperl;
    package LPPERL;
    
    my(%results, $xmlstg);
    my($class, $data) = @_;

    my $base_type = ref($data);
    if($base_type ne "HASH")
    {
        die "Invalid Usage... expected a hash table, got $base_type";
        return 0;
    }

    if ($data->{'xml'})
    {
        $xmlin = 1;
    }

    if ($data->{'webspace'} eq 'false')    # has been explicitly set to false
    {                                      # otherwise, default is 1 - true 
        $webspace = 0;
    }

    if(($data->{'debug'} eq 'true') || ($data->{'debugging'} eq 'true'))
    {   
        $debugging = 1;

        if ($webspace)  # we're in webspace by default
        {
            print "<br>at process, incoming hash:<br>";

            while(my($key, $value) = each %{$data})
            {
                print "$key = ";

                if($key eq 'xml') #format tags for browser
                {
                    $value =~s/</&lt;/gi;
                    $value =~s/\>/&gt;/gi;
                }

                print "$value<br>"
            }
        }
        else        # webspace has been explicitly set to false
        {
            print "\nat process, incoming hash:\n";

            while(my($key, $value) = each %{$data}){
                print "$key = $value\n";}
        }
    }

    if ($xmlin)     # send incoming xml straight through
    {
        $inXml = $data->{'xml'};
    }
    else           # convert incoming hash to xml string
    {
       $inXml = buildXml (@_);
    }


    if($debugging)  # print out string we are about to send
    {
        if ($webspace)  # we're in webspace, so format output for browser
        {
            my $txml = $inXml;
            $txml =~s/</&lt;/gi;
            $txml =~s/\>/&gt;/gi;
            print "<br>sending to LSGS:<br>$txml<br><br>";
        }
        else
        {
            print"\nsending to LSGS:\n $inXml \n\n";
        }
    }

    # prepare connection
    $liblperl::port = $data->{'port'};
    $liblperl::cert = $data->{'keyfile'};
    $liblperl::host = $data->{'host'};
    $liblperl::inXml = $inXml;

    # send transaction to liblperl.so
    liblperl::send_stg();

    if($debugging)  # print server response
    {
        if ($webspace)
        {
            my $txml = $liblperl::outXml;
            $txml =~s/</&lt;/gi;
            $txml =~s/\>/&gt;/gi;
            print "<br>response from LSGS:<br>$txml<br><br>";
        }
        else
        {
            print "response from LSGS: $liblperl::outXml\n\n";
        }
    }
    else
    {
        $instg = $liblperl::outXml;
    }


    if(!$liblperl::outXml) # If $rdata comes back empty, it's am error
    {
        if ($xmlin)     # return a string
        {
            $results = "<r_error>connection error</r_error>";
            return $results;
        }
        else            # return a hash
        {
            $results{"r_error"} = "connection error";
            return %results;
        }
    }

    if ($xmlin)    # send server response straight back
    {
        return $liblperl::outXml;
    }
    else
    {
        # convert server response back to hash
        %rethash = decodeXML($liblperl::outXml);
        return %rethash;
    }
}

    #########################################
    #
    #	S U B  c u r l _ p r o c e s s ( ) 
    #
    #	process a hash table or XML string 
    #	using binary executable CURL
    #
    #########################################


sub curl_process
{
    my(%results, $xmlstg);
    my($class, $data) = @_;

    my $base_type = ref($data);
	%results = ();


    if($base_type ne "HASH")
    {
        die "Invalid Usage... expected a hash table, got $base_type";
        return 0;
    }

    my $rdata;
    undef($rdata);
    my @prm = ();

    if ($data->{'xml'})
    {
        $xmlin = 1;
    }

    if ($data->{'webspace'} eq 'false')    # has been explicitly set to false
    {                                      # otherwise, default is 1 - true 
        $webspace = 0;
    }

    if(($data->{'debug'} eq 'true') || ($data->{'debugging'} eq 'true'))
    {   
        $debugging = 1;

        if ($webspace)  # we're in webspace by default
        {
            print "<br>at curl process, incoming hash:<br>";

            while(my($key, $value) = each %{$data})
            {
                print "$key = ";

                if($key eq 'xml') #format tags for browser
                {
                    $value =~s/</&lt;/gi;
                    $value =~s/\>/&gt;/gi;
                }

                print "$value<br>"
            }
        }
        else        # webspace has been explicitly set to false
        {
            print "\nat curl process, incoming hash:\n";

            while(my($key, $value) = each %{$data}){
                print "$key = $value\n";}
        }
    }


    if ($xmlin)          # send it straight through
    {
        $xml = $data->{'xml'};
    }
    else                 # convert incoming hash to xml string
    {
       $xml = buildXml (@_);
    }

    if($debugging)  # print out string we are about to send
    {
        if ($webspace)  # format output for browser
        {
            my $outxml = $xml;
            $outxml =~s/</&lt;/gi;
            $outxml =~s/\>/&gt;/gi;
            print "<br>sending to LSGS:<br>$outxml<br><br>";
        }
        else
        {
            print"\nsending to LSGS:\n $xml \n\n";
        }
    }


    # prepare connection
    $hoststg = 'https://' . $data->{'host'} . ':' . $data->{'port'} . '/LSGSXML';
    $keyfile = $data->{'keyfile'};

    # if c_path is passed in, use it, else use default
    if($data->{'cpath'})
    {
        $curlpath = $data->{cpath};
    }
    else
    {
        $curlpath = "/usr/bin/curl";
    }

    # TRANSACT
    if ($OS eq 'WINDOWS')
    {
        # if c_args are passed in, use them, else use default
        if($data->{'cargs'})
        {
            $args = $data->{cargs};
        }
        else
        {
            $args = "-m 300 -s -S";
        }
        
        if ($debugging)        # ' -v ' puts curl in 'verbose'
        {
            $rdata = `$curlpath -v $args -E "$keyfile" -d \"$xml\" $hoststg`;
        }
        else
        {
            $rdata = `$curlpath $args -E "$keyfile" -d \"$xml\" $hoststg`;
        }
    }
    else    # WE'RE IN *NIX
    {
        # if c_args are passed in, use them, else use default
        if($data->{'cargs'})
        {
            foreach (parseCSV($data->{'cargs'})) { push @prm, $_; }
        }
        else
        {
    	    foreach (qw !-m 300 -s -S!) { push @prm, $_; }
        }
    
        if ($debugging)       
        {
             unshift @prm, "-v";    # ' -v ' puts curl in 'verbose'
        }
    
    	push @prm, "-E";
    	push @prm, $keyfile;
    	push @prm, "-d";
    	push @prm, $xml;
    	push @prm, $hoststg;
    
    	open (FILE, "-|") || exec $curlpath, @prm;
    	$rdata = join '', <FILE>;
    	close (FILE);

    }

    # evaluate response
    if (!$rdata)  # If $rdata comes back empty, it's a curl error
    {
        if ($xmlin)     # return a string
        {
            $results = "<r_error>curl connection error</r_error>";
            return $results;
        }
        else            # return a hash
        {
            $results{"r_error"} = "curl connection error";
            return %results;
        }
    }

    if ($debugging)  # look at server response XML
    {
        if ($webspace)
        {
            # format for browser
            my $respxml = $rdata;
            $respxml =~s/</&lt;/gi;
            $respxml =~s/\>/&gt;/gi;
            print "<br>response from LSGS:<br>$respxml<br><br>";
        }
        else
        {
            print "\nresponse from LSGS:\n$rdata\n\n";
        }
    }

    if ($xmlin)     # send server response straight back
    {
        return $rdata;
    }
    else            #convert server response back to hash
    {
        %rethash = decodeXML($rdata);
        return %rethash;
    }
}


sub decodeXML
{
    my($data) = @_;
    my $ret = {};

    while ($data =~ /<(.*?)>(.*?)<\x2f\1>/gi)
    {
        if ($1 eq "response")   # check xml is different
        {
            my $chkresp = $2;
            while ($chkresp =~ /<(.*?)>(.*?)<\x2f\1>/gi)
            {
                $ret->{$1} = $2;
            }
            return %$ret;
        }

        $ret->{$1} = $2;
    }

    return %$ret;
}


sub buildXml
{
    my($class, $data) = @_;
    my $xml;

#    while(my($key, $value) = each %{$data}){
#        print "$key = $value\n";}


    ### ORDEROPTIONS NODE ###
    $xml = "<order><orderoptions>";

    if ($data->{ordertype}){
        $xml .= "<ordertype>$data->{ordertype}</ordertype>";}

    if ($data->{result}){
        $xml .= "<result>$data->{result}</result>";} 

    $xml .= "</orderoptions>";


    ### CREDITCARD NODE ###
    $xml .= "<creditcard>";

    if ($data->{cardnumber}){
        $xml .= "<cardnumber>$data->{cardnumber}</cardnumber>";}

    if ($data->{cardexpmonth}){
        $xml .= "<cardexpmonth>$data->{cardexpmonth}</cardexpmonth>";}

    if ($data->{cardexpyear}){
        $xml .= "<cardexpyear>$data->{cardexpyear}</cardexpyear>";}

    if ($data->{cvmvalue}){
        $xml .= "<cvmvalue>$data->{cvmvalue}</cvmvalue>";}

    if ($data->{cvmindicator}){
        $xml .= "<cvmindicator>$data->{cvmindicator}</cvmindicator>";}

    if ($data->{track}){
        $xml .= "<track>$data->{track}</track>";}

    $xml .= "</creditcard>";


    ### BILLING NODE ###
    $xml .= "<billing>";


    if ($data->{name}){
        #$xml .= "<name>$data->{name}</name>";}
        $xml .= "<name><![CDATA[$data->{name}]]></name>";}


    if ($data->{company}){
        $xml .= "<company><![CDATA[$data->{company}]]></company>";}


    if ($data->{address1}){
        $xml .= "<address1><![CDATA[$data->{address1}]]></address1>";}
    elsif ($data->{address}){
        $xml .= "<address><![CDATA[$data->{address}]]></address>";}

    if ($data->{address2}){
        $xml .= "<address2><![CDATA[$data->{address2}]]></address2>";}

    if ($data->{city}){
        $xml .= "<city>$data->{city}</city>";}

    if ($data->{state}){
        $xml .= "<state>$data->{state}</state>";}

    if ($data->{zip}){
        $xml .= "<zip>$data->{zip}</zip>";}

    if ($data->{country}){
        $xml .= "<country>$data->{country}</country>";}

    if ($data->{userid}){
        $xml .= "<userid>$data->{userid}</userid>";}

    if ($data->{email}){
        $xml .= "<email>$data->{email}</email>";}

    if ($data->{phone}){
        $xml .= "<phone>$data->{phone}</phone>";}

    if ($data->{fax}){
        $xml .= "<fax>$data->{fax}</fax>";}

    if ($data->{addrnum}){
        $xml .= "<addrnum>$data->{addrnum}</addrnum>";}

    $xml .= "</billing>";


    ## SHIPPING NODE ##
    $xml .= "<shipping>";
    
    if ($data->{sname}){
        $xml .= "<name><![CDATA[$data->{sname}]]></name>";}

    if ($data->{saddress1}){
        $xml .= "<address1><![CDATA[$data->{saddress1}]]></address1>";}
    elsif ($data->{saddress}){
        $xml .= "<address1><![CDATA[$data->{saddress}]]></address1>";}

    if ($data->{saddress2}){
        $xml .= "<address2><![CDATA[$data->{saddress2}]]></address2>";}

    if ($data->{scity}){
        $xml .= "<city>$data->{scity}</city>";}
    
    if ($data->{sstate}){
        $xml .= "<state>$data->{sstate}</state>";}

    if ($data->{szip}){
        $xml .= "<zip>$data->{szip}</zip>";}

    if ($data->{scountry}){
        $xml .= "<country>$data->{scountry}</country>";}

    if ($data->{scarrier}){
        $xml .= "<carrier>$data->{scarrier}</carrier>";}

    if ($data->{sitems}){
        $xml .= "<items>$data->{sitems}</items>";}

    if ($data->{sweight}){
        $xml .= "<weight>$data->{sweight}</weight>";}

    if ($data->{stotal}){
        $xml .= "<total>$data->{stotal}</total>";}

    $xml .= "</shipping>";   


    ### TRANSACTIONDETAILS NODE ###
    $xml .= "<transactiondetails>";

    if ($data->{oid}){
        $xml .= "<oid>$data->{oid}</oid>";}

    if ($data->{ponumber}){
        $xml .= "<ponumber>$data->{ponumber}</ponumber>";}

    if ($data->{recurring}){
        $xml .= "<recurring>$data->{recurring}</recurring>";}

    if ($data->{taxexempt}){
        $xml .= "<taxexempt>$data->{taxexempt}</taxexempt>";}

    if ($data->{terminaltype}){
        $xml .= "<terminaltype>$data->{terminaltype}</terminaltype>";}
    else{
        $xml .= "<terminaltype>unspecified</terminaltype>";}

    if ($data->{ip}){
        $xml .= "<ip>$data->{ip}</ip>";}  

    if ($data->{reference_number}){
        $xml .= "<reference_number>$data->{reference_number}</reference_number>";}

    if ($data->{transactionorigin}){
        $xml .= "<transactionorigin>$data->{transactionorigin}</transactionorigin>";}

    if ($data->{tdate}){
        $xml .= "<tdate>$data->{tdate}</tdate>";}

    $xml .= "</transactiondetails>";


    ### MARCHANTINFO NODE ###
    $xml .= "<merchantinfo>";

    if ($data->{configfile}){
        $xml .= "<configfile>$data->{configfile}</configfile>";}

    if ($data->{keyfile}){
        $xml .= "<keyfile>$data->{keyfile}</keyfile>";}

    if ($data->{host}){
        $xml .= "<host>$data->{host}</host>";}

    if ($data->{port}){
        $xml .= "<port>$data->{port}</port>";}

    if ($data->{appname}){
        $xml .= "<appname>$data->{appname}</appname>";}

    $xml .= "</merchantinfo>";


    ### PAYMENT NODE ###
    $xml .= "<payment>";

    if ($data->{chargetotal}){
        $xml .= "<chargetotal>$data->{chargetotal}</chargetotal>";}

    if ($data->{tax}){
        $xml .= "<tax>$data->{tax}</tax>";}

    if ($data->{vatax}){
        $xml .= "<vatax>$data->{vatax}</vatax>";}
    
    if ($data->{shipping}){
        $xml .= "<shipping>$data->{shipping}</shipping>";}

    if ($data->{subtotal}){
        $xml .= "<subtotal>$data->{subtotal}</subtotal>";}

    $xml .= "</payment>";


    ### CHECK NODE ### 
    if ($data->{voidcheck})
    {
        $xml .= "<telecheck><void>1</void></telecheck>";
    }
    elsif($data->{routing})
    {
        $xml .= "<telecheck>";
        $xml .= "<routing>$data->{routing}</routing>";

        if ($data->{account}){
            $xml .= "<account>$data->{account}</account>";}

        if ($data->{bankname}){
            $xml .= "<bankname>$data->{bankname}</bankname>";}

        if ($data->{bankstate}){
            $xml .= "<bankstate>$data->{bankstate}</bankstate>";}

        if ($data->{ssn}){
            $xml .= "<ssn>$data->{ssn}</ssn>";}

        if ($data->{dl}){
            $xml .= "<dl>$data->{dl}</dl>";}

        if ($data->{checknumber}){
            $xml .= "<checknumber>$data->{checknumber}</checknumber>";}

        if ($data->{dlstate}){
            $xml .= "<dlstate>$data->{dlstate}</dlstate>";}

        if ($data->{accounttype}){
            $xml .= "<accounttype>$data->{accounttype}</accounttype>";}

        $xml .= "</telecheck>";
    }


    ### PERIODIC NODE ###
    if ($data->{startdate})
    {
        $xml .= "<periodic>";
        $xml .= "<startdate>$data->{startdate}</startdate>";

        if ($data->{installments}){
            $xml .= "<installments>$data->{installments}</installments>";}

        if ($data->{threshold}){
            $xml .= "<threshold>$data->{threshold}</threshold>";}

        if ($data->{periodicity}){
            $xml .= "<periodicity>$data->{periodicity}</periodicity>";}

         if ($data->{comments}){
             $xml .= "<comments><![CDATA[$data->{comments}]]></comments>";}

         if ($data->{action}){
             $xml .= "<action>$data->{action}</action>";}

        $xml .= "</periodic>";
    }


    ### NOTES NODE ###
    if(($data->{comments})||($data->{referred}))
    {
        $xml .= "<notes>";

        if ($data->{comments}){
            $xml .= "<comments>$data-><![CDATA[{comments}]]></comments>";}

        if ($data->{referred}){
            $xml .= "<referred>$data-><![CDATA[{referred}]]></referred>";}

        $xml .= "</notes>";
    }


    ### ITEMS AND OPTIONS NODES ###
    my $items = $data->{'items'};
    my $item;
    my $ctag = 1;

    if ($data->{'items'})
    {
        $xml .= "<items>";

    foreach $item (@{$items})
        {
            if ($ctag == 1)
            {
                $xml .= "<item>";
                $ctag = 0;
            }

            if($item->{'id'}){
                $xml .= "<id>$item->{'id'}</id>";}

            if($item->{'description'}){
                $xml .= "<description>$item-> <![CDATA[{'description'}]]></description>";}

            if($item->{'quantity'}){
                $xml .= "<quantity>$item->{'quantity'}</quantity>";}

            if($item->{'price'}){
                $xml .= "<price>$item->{'price'}</price>";}

            if($item->{'softfile'}){
                $xml .= "<softfile>$item-><![CDATA[{'softfile'}]]></softfile>";}

            if($item->{'serial'}){
                $xml .= "<serial>$item-><![CDATA[{'serial'}]]></serial>";}

            if($item->{'esdtype'}){
                $xml .= "<esdtype>$item->{'esdtype'}</esdtype>";}


            my $options = $item->{'options'};
            my $option;

            if($item->{'options'})
            {
                $ctag = 0;
            }

            if($item->{'options'})
            {
                $xml .= "<options>";

                foreach $option (@{$options})
                {
                    $xml .= "<option>";
                    
                    if($option->{'name'}){
                        $xml .= "<name><![CDATA[$option->{'name'}]]></name>";}

                    if($option->{'value'}){
                        $xml .= "<value><![CDATA[$option->{'value'}]]></value>";}

                    $xml .= "</option>";
                }

                $xml .= "</options>";

                if ($ctag == 0)
                {
                    $xml .= "</item>";
                    $ctag = 1;
                }
            }
        }

        $xml .= "</items>";
    }
    $xml .= "</order>";


    return $xml;
}

sub parseCSV {
        my $text = $_[0] || $_;
        @new = ();
    push(@new, $+) while $text =~ m{
         "([^\"\\]*(?:\\.[^\"\\]*)*)"\s?  # groups the phrase inside the quotes
       | ([^ ]+)\s?
       | \s 
    }gx;
    push(@new, undef) if substr($text,-1,1) eq ' ';

        return @new;
}





1;
