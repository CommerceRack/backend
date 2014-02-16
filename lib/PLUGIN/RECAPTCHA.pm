package PLUGIN::RECAPTCHA;


use Captcha::reCAPTCHA;

sub get_captcha {
	my ($USERNAME) = @_;
	my $c = Captcha::reCAPTCHA->new();
	return($c->get_html($PLUGIN::RECAPTCHA::PUBLIC_KEY));	
	}

sub verify_captcha {
	my ($USERNAME) = @_;

	my $challenge = param 'recaptcha_challenge_field';
	my $response = param 'recaptcha_response_field';

	# Verify submission
	my $result = $c->check_answer(
		$PLUGIN::RECAPTCHA::PRIVATE_KEY, $ENV{'REMOTE_ADDR'},
		$challenge, $response
		);

    if ( $result->{is_valid} ) {
        print "Yes!";
    }
    else {
        # Error
        print "No";
    }




#Public Key: 	6Lez9s0SAAAAAMqp6blF1xnzH38Mkrbnq_VSd-zR
#Use this in the JavaScript code that is served to your users
#Private Key: 	6Lez9s0SAAAAAPJvBnonPCCWjf-3c7aytVDIcOq5
#Use this when communicating between your server and our server. Be sure to keep it a secret.



1;