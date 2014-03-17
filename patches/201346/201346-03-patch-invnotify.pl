#!/usr/bin/perl

use strict;
use lib "/httpd/modules";
use CFG;
use DBINFO;

my ($CFG) = CFG->new();

foreach my $USERNAME (@{$CFG->users()}) {
	print "USERNAME:$USERNAME\n";
	my ($gref) = &ZWEBSITE::fetch_globalref($USERNAME);

	my ($webdb) = &ZWEBSITE::fetch_website_dbref($USERNAME,0);
	if (not defined $webdb->{'%NOTIFICATIONS'}) {
		$webdb->{'%NOTIFICATIONS'} = {};
		}
	
	my @EVENTS = ();
	push @EVENTS, 'ENQUIRY';
	push @EVENTS, 'ERROR';
	push @EVENTS, 'ALERT';
	push @EVENTS, 'APIERR';
	push @EVENTS, 'CUSTOMER.ORDER.CANCEL';
	push @EVENTS, 'INV.NAVCAT.FAIL';

	if ($gref->{'inv_notify'} & 1) {
		push @EVENTS, 'INV.NAVCAT.HIDE';
		}
	if ($gref->{'inv_notify'} & 7) {
		push @EVENTS, 'INV.NAVCAT.SHOW';
		}
	if ($gref->{'inv_notify'} & 55) {
		push @EVENTS, 'ALERT.INV.RESTOCK';
		}	

	push @EVENTS, 'INV.NAVCAT.SHOW';



	my $changes = 0;
	foreach my $EVENT (@EVENTS) {
		if (not defined $webdb->{'%NOTIFICATIONS'}->{$EVENT}) {
			$webdb->{'%NOTIFICATIONS'}->{$EVENT} = [ 'verb=task' ];
			$changes++;
			}
		print "EVENT: $EVENT [$changes]\n";
		}

	if ($changes) {
		&ZWEBSITE::save_website_dbref($USERNAME,$webdb,0);
		}

#	if ($EVENTID eq 'ENQUIRY') { $ROWS = [ 'verb=task'] };
#	if ($EVENTID eq 'ERROR') { $ROWS = [ 'verb=task'] };
#	if ($EVENTID eq 'ALERT') { $ROWS = [ 'verb=task'] };
#   if ($EVENTID eq 'APIERR') { $ROWS = [ 'verb=task'] };
#   if ($EVENTID eq 'CUSTOMER.ORDER.CANCEL') { $ROWS = [ 'verb=task'] };
#   if ($EVENTID eq 'INV.NAVCAT.SHOW') { $ROWS = [ 'verb=task'] };
#   if ($EVENTID eq 'INV.NAVCAT.HIDE') { $ROWS = [ 'verb=task'] };
#   if ($EVENTID eq 'INV.NAVCAT.FAIL') { $ROWS = [ 'verb=task'] };

#		<select name="inv_notify" data-bind="var:config(%INVENTORY.inv_notify); format:popVal;">
#			<option value="0">None</option>
#			<option value="1">Remove</option>
#			<option value="7">Remove/add</option>
#			<option value="55">Remove/add + restock</option>
#		</select>	

#	my ($udbh) = &DBINFO::db_user_connect($USERNAME);
#	foreach my $SQL (@LINES) {
#		print "SQL:$SQL\n";
#		if (not defined $udbh) {
#			warn "ERROR: NO DB\n";
#			}
#		else {
#			$udbh->do($SQL);
#			}	
#		}
#	&DBINFO::db_user_close();
	}

