package BLAST::RECIPIENT::EBAY;

use strict;
use parent 'BLAST::RECIPIENT';
use Data::Dumper;

## delivers a message to a persons ebay account
## QuestionType: Shipping
## RecipientID: ??

sub itemid { return($_[0]->{'%call'}->{'ItemID'}); }
sub siteid { return($_[0]->{'%call'}->{'#Site'}); }
sub recipientid { return($_[0]->{'%call'}->{'MemberMessage.RecipientID'}); }

sub new {
	my ($class, $BLASTER, $EBAY2, $METAREF) = @_;

	my $self = {};
	$self->{'%META'} = $METAREF || {};
	$self->{'*BLASTER'} = $BLASTER;
	$self->{'*eb2'} = $EBAY2;
	$self->{'%call'} = $METAREF->{'%call'};
	#$self->{'%call'}->{'#Site'} = $EBAYSite;
	#$self->{'%call'}->{'ItemID'} = $EBAYItemID;
	#$self->{'%call'}->{'MemberMessage.QuestionType'} = $EBAYQuestionType;
	#$self->{'%call'}->{'MemberMessage.RecipientID'} = $EBAYRecipientID;
	bless $self, 'BLAST::RECIPIENT::EBAY';
	return($self);
	}

##
##
##
sub send {
	my ($self, $msg) = @_;

	open F, ">/tmp/ebay-send"; print F Dumper($self,$msg); close F;

#	my $RECIPIENT = $self->email();
#	my $BCC = $self->bcc();
#	my $BODY = $msg->body();

	my $call = $self->{'%call'};
	# http://developer.ebay.com/DevZone/XML/docs/Reference/eBay/AddMemberMessageAAQToPartner.html
	# $hash{'MessageID'} =  # internal message
	$call->{'MemberMessage.Subject'} = $msg->subject();
	$call->{'MemberMessage.Subject'} =~ s/<.*?>//gs;

	$call->{'MemberMessage.Body'} = $msg->body();

	use HTML::FormatText::Html2text;
	$call->{'MemberMessage.Body'} = HTML::FormatText::Html2text->format_string ($call->{'MemberMessage.Body'});

#	$call->{'MemberMessage.Body'} = $f->parse($call->{'MemberMessage.Body'});
#	print Dumper($text);
#	$call->{'MemberMessage.Body'} =~ s/<.*?>//gs;

#	print Dumper($call);
#	die();
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
