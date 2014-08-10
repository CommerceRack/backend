#!/usr/bin/perl

use lib "/httpd/modules";

my $USERNAME = "heirloom";

my $ucUSERNAME = uc($USERNAME);

system("create database $ucUSERNAME");
system("mysql $ucUSERNAME < /backend/patches/schema.sql");




