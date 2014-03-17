package BLAST::RECIPIENT::EBAY;

use strict;

## delivers a message to a persons ebay account
## QuestionType: Shipping
## RecipientID: ??

sub new {
	my ($class, $BLASTER, $EBAY2, $EBAYSite, $EBAYItemID, $EBAYQuestionType, $EBAYRecipientID, $METAREF) = @_;

	my $self = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	$self->{'*eb2'} = $EBAY2;
	$self->{'%call'} = {};
	$self->{'%call'}->{'#Site'} = $EBAYSite;
	$self->{'%call'}->{'ItemID'} = $EBAYItemID;
	$self->{'%call'}->{'MemberMessage.QuestionType'} = $EBAYQuestionType;
	$self->{'%call'}->{'MemberMessage.RecipientID'} = $EBAYRecipientID;
	bless $self, 'BLAST::RECIPIENT::EBAY';
	return($self);
	}

sub send {
	my ($self, $msg) = @_;

	my $RECIPIENT = $self->email();
	my $BCC = $self->bcc();
	my $BODY = $msg->body();

	my $call = $self->{'%call'};
	# http://developer.ebay.com/DevZone/XML/docs/Reference/eBay/AddMemberMessageAAQToPartner.html
	# $hash{'MessageID'} =  # internal message
	$call->{'MemberMessage.Subject'} = $msg->subject();
	$call->{'MemberMessage.Body'} = $msg->body();
#			$hash{'MemberMessage.Body'} = qq~
#Your order has been shipped.
#Please visit our website at
#http://www.toynk.com/customer/order/status?orderid=$ORDERID&cart=$CARTID
#~;
#			$hash{'MemberMessage.Subject'} = 'Thank you for your order.';

	my ($eb2) = $self->{'*eb2'};
	my ($r) = $eb2->api('AddMemberMessageAAQToPartner',$call,'xml'=>3);
	#use Data::Dumper;
	#print Dumper($r);
	if ($r->{'.'}->{'Ack'}->[0] eq 'Success') {
		}
	return();
	}

1;
