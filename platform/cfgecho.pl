#!/usr/bin/perl

use lib "/backend/lib";
use CFG;

# /httpd/platform/cfgecho.pl type:user

CFG->print(@ARGV);

