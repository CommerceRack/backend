#!/usr/bin/perl

use lib "/httpd/modules";
use CFG;

# /httpd/platform/cfgecho.pl type:user

CFG->print(@ARGV);

