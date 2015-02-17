package PLUGIN::FRESHDESK;

use Digest::HMAC_MD5 qw(hmac_md5 hmac_md5_hex);

# https://support.freshdesk.com/support/articles/31166-single-sign-on-remote-authentication-in-freshdesk
# http://yourcompany.freshdesk.com/login/normal

sub create_sso_url {
	my ($LU) = @_;

	my $KEY = CFG->new()->get("freshdesk","ssokey");

	my $URL = '';
	if ($KEY ne '') {
		my $USERNAME = $LU->luser().'@'.$LU->username();
		my $EMAIL = $LU->email();
		my $PHONE = $LU->phone();
		my $COMPANY = $LU->username();

		my $TS = time();
		my $digest = hmac_md5_hex($USERNAME.$EMAIL.$TS, $KEY);

		$URL = 'https://elasticventures.freshdesk.com/login/sso?';
			$URL .= 'name=' . $USERNAME;
			$URL .= "&email=" . $EMAIL;
			$URL .= "&timestamp=" . $TS;
			$URL .= "&phone=" . $PHONE;
			$URL .= "&company=" . $COMPANY;
			$URL .= "&hash=" . $digest;
		}
	else {
		$URL = 'http://elasticventures.freshdesk.com/login/normal';
		}

	return($URL);
	}


1;