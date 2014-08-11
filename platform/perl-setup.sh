#!/bin/bash

#----------------------------------------
## MORE PERL
## just follow the prompts, yes to everything
cpanm UNIVERSAL::require;
cpanm Exporter::Easy;
cpanm File::Find::Rule;
cpanm common::sense;
cpanm JSON::XS;
cpanm Test::More;

cpanm Business::EDI;
cpanm Business::UPC;
cpanm --force Memcached::libmemcached;
## warnings are okay for Cache::libmemcached (there are no servers installed!)
cpanm Cache::Memcached::libmemcached;
cpanm CDB_File;

cpanm FCGI;
cpanm CGI;
cpanm CGI::Lite;
cpanm Class::Runtime;
cpanm Class::Std;
cpanm Class::Std::Fast::Storable;
cpanm Data::UUID;
cpanm Data::GUID;
cpanm Date::Calc;
cpanm version;
cpanm Perl::OSType;
cpanm Module::Metadata;
cpanm CPAN::Meta::YAML;
cpanm JSON::PP;
cpanm CPAN::Meta::Requirements;
cpanm Parse::CPAN::Meta;
cpanm CPAN::Meta;
cpanm Module::Build;

cpanm Date::Manip;
cpanm Date::Parse;

cpanm ExtUtils::MakeMaker;
cpanm Test::Requires;
cpanm Try::Tiny;
cpanm Test::Fatal;
cpanm Module::Runtime;
cpanm Dist::CheckConflicts;

cpanm Module::Runtime;
cpanm Module::Implementation;
cpanm Package::DeprecationManager;
cpanm Package::Stash::XS;
cpanm Package::Stash;
cpanm Class::Load;
cpanm DateTime::TimeZone;
cpanm DateTime;
cpanm --force DBI;
cpanm DBD::mysql;
cpanm Digest::HMAC_SHA1;
cpanm Digest::MD5;
cpanm Digest::SHA1;
##cpanm --force DIME::Message;

cpanm Data::Dump;
cpanm Any::URI::Escape;
cpanm HTTP::Tiny;
cpanm HTTP::Lite;

## NOTE: may require:
cpanm --force ElasticSearch::SearchBuilder
##cpanm ElasticSearch::SearchBuilder;

cpanm Log::Any;
cpanm Log::Any::Adapter;
cpanm Log::Any::Adapter::Callback;
cpanm Elasticsearch;


cpanm URI;
cpanm AnyEvent;
cpanm AnyEvent::TLS;
cpanm AnyEvent::HTTP;
cpanm AnyEvent::HTTP::LWP::UserAgent;
cpanm DateTime::Locale;
cpanm DateTime::Format::Strptime;
cpanm JSON;
cpanm Test::Trap;
cpanm Ouch;
cpanm Mouse;
cpanm Any::Moose;
cpanm MIME::Base64::URLSafe;
cpanm Facebook::Graph;
##cpanm File::Basename");';		## included w/ perl (should match ;
## cpanm File::Copy");';		## included w/ perl (should match ;


cpanm --force Net::Curl;
cpanm Test::HTTP::Server;
cpanm --force LWP::Protocol::Net::Curl;

cpanm Filesys::Virtual;
cpanm Filesys::Virtual::Plain;
cpanm File::Find::Rule::Filesys::Virtual;
cpanm --force File::Path;
cpanm File::Slurp;
cpanm File::Spec;
cpanm File::Temp;

cpanm Frontier::Client;
cpanm Frontier::RPC2;
cpanm Class::Measure;

cpanm ExtUtils::MakeMaker;
cpanm MRO::Compat;
cpanm List::MoreUtils;
cpanm Class::Load::XS;

cpanm Eval::Closure;
cpanm Sub::Name;
cpanm Data::OptList;
cpanm Carp;
cpanm Sub::Exporter::Progressive;
cpanm Devel::GlobalDestruction::XS;
cpanm Devel::GlobalDestruction;
cpanm Moose::Role;
cpanm Variable::Magic;
cpanm Class::MO;
cpanm Sub::Identify;
cpanm Sub::Name;
cpanm B::Hooks::EndOfScope;
cpanm namespace::clean;
cpanm namespace::autoclean;
cpanm Mouse;
cpanm Any::Moose;
cpanm GIS::Distance;

## perl -MCPAN -e 'CPAN::Shell->force("install","Google::Checkout::General::GCO");';
cpanm XML::Writer;
cpanm HTML::Entities;
## NO LONGER USED
##cpanm HTML::Mason;
##cpanm HTML::Mason::ApacheHandler;
cpanm HTML::Parser;
cpanm HTML::Tagset;
cpanm LWP::MediaTypes;
cpanm Encode::Locale;
cpanm IO::HTML;
cpanm HTTP::Date;
cpanm Compress::Raw::Bzip2;
cpanm Compress::Raw::Zlib;
cpanm IO::Compress::Bzip2;
cpanm IO::Uncompress::Bunzip2;

cpanm HTTP::Headers;
cpanm HTTP::Cookies;
cpanm HTTP::Date;
cpanm HTTP::Request;
cpanm HTTP::Request::Common;
cpanm HTTP::Response;
cpanm IO::File;
cpanm IO::Scalar;
cpanm IO::String;
cpanm JSON::Syck;
cpanm JSON::XS;

cpanm Lingua::EN::Infinitive;
cpanm HTTP::Negotiate;
cpanm File::Listing;
cpanm HTTP::Daemon;
cpanm Net::HTTP;
cpanm WWW::RobotRules;
cpanm LWP;
cpanm LWP::UserAgent;
cpanm LWP::Simple;
cpanm Mail::DKIM::PrivateKey;
cpanm Mail::DKIM::Signer;
cpanm MIME::Base64;
cpanm MIME::Entity;
cpanm MIME::Lite;
cpanm MIME::Parser;


cpanm Math::BigInt;
cpanm Math::BigInt::FastCalc;
cpanm Math::BigRat;
cpanm Net::DNS;
cpanm Net::FTP;
cpanm Net::POP3;

cpanm Test::use::ok;
cpanm Tie::ToObject;
cpanm Moose;
cpanm Sub::Identify;
cpanm Variable::Magic;
cpanm B::Hooks::EndOfScope;
cpanm namespace::clean;

cpanm Data::Visitor::Callback;
cpanm MooseX::Aliases;
cpanm MooseX::Role::Parameterized;
cpanm Net::OAuth;
cpanm DateTime::Locale;
cpanm DateTime::Format::Strptime;

cpanm TAP::Harness::Env;
cpanm ExtUtils::Helpers;
cpanm ExtUtils::Config;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm namespace::autoclean;
cpanm Net::Twitter;
cpanm Pod::Parser;
## cpanm POSIX");';	## included with;

cpanm Redis;
cpanm Scalar::Util;
cpanm Text::CSV;
cpanm Text::CSV_XS;
cpanm Text::Metaphone;
cpanm Text::Soundex;
cpanm Tie::Hash::Indexed;
cpanm Time::HiRes;


cpanm URI;
cpanm URI::Escape;
cpanm URI::Escape::XS;
cpanm URI::Split;
cpanm XML::LibXML;
cpanm XML::Parser;
cpanm XML::Parser::EasyTree;
cpanm XML::RSS;
cpanm XML::SAX::Base;

## NOTE: XML::SAX requires we press 'Y'
cpanm XML::SAX;

cpanm XML::Handler::Trees;
cpanm XML::SAX::Expat;
cpanm XML::Simple;
cpanm XML::SAX::Simple;
cpanm Object::MultiType;
cpanm XML::Smart;
cpanm XML::Writer;
cpanm YAML::Syck;
cpanm YAML::XS;

cpanm Text::WikiCreole;
cpanm JSON::XS;
cpanm Date::Calc;
cpanm Text::Wrap;
cpanm Digest::SHA1;
cpanm DIME::Payload;
cpanm Compress::Bzip2;
cpanm HTML::Tiny;
cpanm Captcha::reCAPTCHA;
cpanm HTML::Tiny;
cpanm Captcha::reCAPTCHA;
cpanm File::Type;
cpanm CGI::Lite::Request;
cpanm File::Type;
cpanm CGI::Lite::Request;
cpanm Regexp::Common;
cpanm Parse::RecDescent;
cpanm Capture::Tiny;
cpanm Email::Address;
cpanm Email::MessageID;
cpanm Email::Simple::Creator;
cpanm Email::MIME::Encodings;
cpanm Email::MIME::ContentType;
cpanm Email::MIME;
cpanm Email::MessageID;
cpanm Email::MIME::Encodings;
cpanm Email::MIME::ContentType;
cpanm Email::Simple;

cpanm AnyEvent;
cpanm Encode::IMAPUTF7;
cpanm Email::MIME::ContentType;
cpanm EV;
cpanm Guard;
cpanm Coro;

cpanm Net::Server;
cpanm Net::Server::Coro;

cpanm Net::Server;
# perl -MCPAN -e 'CPAN::Shell->force("install","Coro");';
# cpanm Net::Server::Coro;
cpanm Email::MIME;
# perl -MCPAN -e 'CPAN::Shell->notest("install","Net::IMAP::Simple");';		
cpanm Net::IMAP::Simple

cpanm App::ElasticSearch::Utilities;


##
## 201401
##
cpanm AnyEvent::Redis;
cpanm String::Urandom;
cpanm --force Net::AWS::SES;
cpanm Nginx;
cpanm Net::Domain::TLD;
cpanm Data::Validate::Domain;
cpanm Data::Validate::Email;
cpanm Email::Valid;
cpanm CSS::Minifier::XS;
cpanm MediaWiki::API;


## 201401b
#cd /usr/local/src/;
#wget ftp://megrez.math.u-bordeaux.fr/pub/pari/unix/pari-2.5.5.tar.gz
#tar -xzvf pari-2.5.5.tar.gz;
#cd pari-2.5.5
#./Configure

cpanm XML::Handler::Trees
cpanm XML::SAX::Expat
cpanm XML::Simple
cpanm Object::MultiType
cpanm XML::Smart

cpanm XML::Writer
cpanm YAML::Syck
cpanm YAML::XS

cpanm Text::WikiCreole
cpanm JSON::XS
cpanm Date::Calc
cpanm Text::Wrap
cpanm Digest::SHA1
cpanm DIME::Payload
cpanm Compress::Bzip2
cpanm HTML::Tiny
cpanm Captcha::reCAPTCHA
cpanm HTML::Tiny
cpanm Captcha::reCAPTCHA
cpanm File::Type
cpanm CGI::Lite::Request
cpanm File::Type
cpanm CGI::Lite::Request
cpanm Regexp::Common
cpanm Parse::RecDescent
cpanm Capture::Tiny
cpanm Email::Address
cpanm Email::MessageID
cpanm Email::Simple::Creator
cpanm Email::MIME::Encodings
cpanm Email::MIME::ContentType
cpanm Email::MIME
cpanm Email::MessageID
cpanm Email::MIME::Encodings
cpanm Email::MIME::ContentType
cpanm Email::Simple

cpanm AnyEvent
cpanm Encode::IMAPUTF7
cpanm Email::MIME::ContentType
cpanm EV
cpanm Guard

cpanm Coro
cpanm Net::Server
cpanm Net::Server::Coro

cpanm Net::Server
# perl -MCPAN -e 'CPAN::Shell->force("install","Coro
# cpanm Net::Server::Coro
cpanm Email::MIME
cpanm Net::IMAP::Simple
cpanm App::ElasticSearch::Utilities

cpanm AnyEvent::Redis
cpanm String::Urandom
cpanm Net::AWS::SES
cpanm Nginx
cpanm Net::Domain::TLD
cpanm Data::Validate::Domain
cpanm Data::Validate::Email
cpanm Email::Valid
cpanm CSS::Minifier::XS
cpanm MediaWiki::API

cpanm Math::Pari

cpanm Data::Buffer;
cpanm Sort::Versions;
cpanm Class::Loader;
cpanm Math::Pari;
cpanm Crypt::Random;
cpanm Crypt::Primes;
cpanm Crypt::Blowfish;
cpanm Tie::EncryptedHash;
cpanm Digest::MD5;
cpanm Convert::ASCII::Armour;
cpanm Crypt::RSA;

## these tests lock up
cpanm Path::Tiny;
cpanm Exporter::Tiny;
cpanm Type::Tiny;
cpanm Types::Standard;
cpanm Sub::Infix;
cpanm match::simple;

cpanm Test::Synopsis;
cpanm Test::Poe;
cpanm Test::Strict;
cpanm PPI;
cpanm PPIx::Regex;
cpanm Perl::MinimumVersion;
cpanm Term::ANSIColor;

cpanm Term::ANSIColo4;
cpanm Text::Aligned;
cpanm Text::Table;

cpanm Test::Without::Module;
cpanm JSON::Any;
cpanm Test::JSON;
cpanm Test::MockModule;
cpanm DBIx::Connector;
cpanm MooseX::ArrayRef;
cpanm Module::Load;
cpanm Module::CoreList;
cpanm Module::Load::Conditional;
cpanm XML::Namespace;
cpanm XML::NamespaceFactory;
cpanm XML::CommonNS;
cpanm Algorithm::Combinatorics;

cpanm ExtUtils::Depends;
cpanm B::Hooks::OP::Check;
cpanm B::Hooks::OP::PPAddr;
cpanm Module::Build::Tiny;
cpanm MooseX::Traits;
cpanm MooseX::Types::Moose;

cpanm Class::Tiny;
cpanm Devel::PartialDump;

cpanm MooseX::Types::DateTime;
cpanm MooseX::Types::Structured;
cpanm MooseX::Types;

cpanm aliases;
cpanm Parse::Method::Signatures;


cpanm Scope::Upper;
cpanm Devel::Declare;
cpanm TryCatch;


cpanm Set::Scalar;
cpanm RDF::TriN3;
cpanm RDF::Query;
cpanm Crypt::X509;
cpanm namespace::sweet;
cpanm Web::ID;


cpanm Net::FTPSSL;
cpanm SOAP::WSDL;
cpanm Crypt::CBC;
cpanm Crypt::Twofish;
cpanm Crypt::DES;
cpanm Data::Dumper::Concise;
cpanm Config::General;
cpanm Config::Any;
cpanm Class::XSAccessor;
cpanm Test::Exception;
cpanm Class::Accessor::Grouped;
cpanm Hash::Merge;
cpanm Params::Validate;
cpanm Test::Tester;
cpanm Test::Warnings;
cpanm Getopt::Long::Descriptive;
cpanm SQL::Abstract;
cpanm Data::Dumper::Concise;


cpanm ok;
cpanm Config::Any;
cpanm SQL::Abstract;
cpanm Context::Preserve;
cpanm Test::Exception;
cpanm Data::Compare;
cpanm Path::Class;
cpanm Scope::Guard;
cpanm DBD::SQLite;
cpanm Hash::Merge;
cpanm Class::Accessor::Chained::Fast;

cpanm Module::Find;
cpanm Data::Page;
cpanm Algorithm::C3;
cpanm Class::C3;
cpanm Class::C3::Componentised;

cpanm strictures;
cpanm Role::Tiny;
cpanm Class::Method::Modifiers;
cpanm Devel::GlobalDestruction;

cpanm Moo;
	
cpanm Math::Symbolic;
cpanm Sub::Identify;
cpanm Variable::Magic;
cpanm B::Hooks::EndOfScope;
cpanm namespace::clean;
cpanm DBIx::Class;
cpanm Proc::PID::File;
cpanm Acme::Damn;
cpanm Sys::SigAction;
cpanm forks;
cpanm XML::SimpleObject;
cpanm Net::Netmask;
cpanm DBD::SQLite;

cpanm File::Pid;
cpanm Log::Log4perl;
cpanm Sysadm::Install;
cpanm App::Daemon;

## Needed for Webdoc parsing.
cpanm HTML::Entities::Numbered;
cpanm HTML::TreeBuilder;
## cpanm HTML::Tidy");';	 <<- doesn't ;
echo "" | cpanm XML::Twig;


## 201316
cpanm ExtUtils::Config;
cpanm File::ShareDir::Install;
cpanm Apache::LogFormat::Compiler;
cpanm Stream::Buffered;
cpanm Test::SharedFork;
cpanm Test::TCP;
cpanm File::ShareDir;
cpanm ExtUtils::Helpers;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm Hash::MultiValue;
cpanm Devel::StackTrace;
cpanm HTTP::Body;
cpanm Filesys::Notify::Simple;
cpanm Devel::StackTrace::AsHTML;
cpanm Plack;
cpanm HTTP::Message::PSGI;
cpanm Test::UseAllModules;
cpanm Plack::Request;

cpanm Test::Fake::HTTPD;
cpanm Class::Accessor::Lite;
cpanm Test::Flatten;
cpanm WWW::Google::Cloud::Messaging;
cpanm Text::WikiCreole;
cpanm Test::Class;

cpanm Data::OptList;
cpanm CPAN::Meta::Check;
cpanm Test::CheckDeps;
cpanm Test::Mouse;
cpanm Any::Moose;
cpanm Test::Moose;
cpanm Net::APNS;

cpanm Amazon::SQS::Simple;
## cpanm Amazon::SQS::ProducerConsum;

cpanm Data::Buffer
cpanm Sort::Versions
cpanm Class::Loader
cpanm Math::Pari
cpanm Crypt::Random
cpanm Crypt::Primes
cpanm Crypt::Blowfish
cpanm Tie::EncryptedHash
cpanm Digest::MD2
cpanm Convert::ASCII::Armour
cpanm Crypt::RSA

## these tests lock up
cpanm Path::Tiny
cpanm Exporter::Tiny
cpanm Type::Tiny
cpanm Types::Standard
cpanm Sub::Infix
cpanm match::simple

cpanm Test::Synopsis
cpanm Test::Pod
cpanm Test::Strict
cpanm PPI
cpanm PPIx::Regexp
cpanm Perl::MinimumVersion
cpanm Term::ANSIColor
cpanm --force Term::ANSIColor

cpanm Term::ANSIColor
cpanm Text::Aligner
cpanm Text::Table

cpanm Test::Without::Module
cpanm JSON::Any
cpanm Test::JSON
cpanm Test::MockModule
cpanm DBIx::Connector
cpanm MooseX::ArrayRef
cpanm Module::Load
cpanm Module::CoreList
cpanm Module::Load::Conditional
cpanm XML::Namespace
cpanm XML::NamespaceFactory
cpanm XML::CommonNS
cpanm Algorithm::Combinatorics

cpanm ExtUtils::Depends
cpanm B::Hooks::OP::Check
cpanm B::Hooks::OP::PPAddr
cpanm Module::Build::Tiny
cpanm MooseX::Traits
cpanm MooseX::Types::Moose

cpanm Class::Tiny
cpanm Devel::PartialDump

cpanm MooseX::Types::DateTime
cpanm MooseX::Types::Structured
cpanm MooseX::Types

cpanm aliased
cpanm Parse::Method::Signatures


cpanm Scope::Upper
cpanm Devel::Declare
cpanm TryCatch

cpanm Set::Scalar
cpanm RDF::Trine
cpanm RDF::Query
cpanm Crypt::X509
cpanm namespace::sweep
cpanm Web::ID






cpanm Net::FTPSSL
cpanm SOAP::WSDL
cpanm Crypt::CBC
cpanm Crypt::Twofish
cpanm Crypt::DES
cpanm Data::Dumper::Concise
cpanm Config::General
cpanm Config::Any
cpanm Class::XSAccessor
cpanm Test::Exception
cpanm Class::Accessor::Grouped
cpanm Hash::Merge
cpanm Params::Validate
cpanm Test::Tester
cpanm Test::Warnings
cpanm Getopt::Long::Descriptive
cpanm SQL::Abstract
cpanm Data::Dumper::Concise


cpanm ok
cpanm Config::Any
cpanm SQL::Abstract
cpanm Context::Preserve
cpanm Test::Exception
cpanm Data::Compare
cpanm Path::Class
cpanm Scope::Guard
cpanm DBD::SQLite
cpanm Hash::Merge
cpanm Class::Accessor::Chained::Fast

cpanm Module::Find
cpanm Data::Page
cpanm Algorithm::C3
cpanm Class::C3
cpanm Class::C3::Componentised

cpanm strictures
cpanm Role::Tiny
cpanm Class::Method::Modifiers
cpanm Devel::GlobalDestruction

cpanm Moo
	
cpanm Math::Symbolic
cpanm Sub::Identify
cpanm Variable::Magic
cpanm B::Hooks::EndOfScope
cpanm namespace::clean
cpanm DBIx::Class
cpanm Proc::PID::File
cpanm Acme::Damn
cpanm Sys::SigAction
cpanm forks
cpanm XML::SimpleObject
cpanm Net::Netmask
cpanm DBD::SQLite

cpanm File::Pid
cpanm Log::Log4perl
cpanm Sysadm::Install
cpanm App::Daemon

## Needed for Webdoc parsing.
cpanm HTML::Entities::Numbered
cpanm HTML::TreeBuilder
## cpanm HTML::Tidy	 <<- doesn't work!
echo "" | cpanm XML::Twig


## 201316
cpanm ExtUtils::Config
cpanm File::ShareDir::Install
cpanm Apache::LogFormat::Compiler
cpanm Stream::Buffered
cpanm Test::SharedFork
cpanm Test::TCP
cpanm File::ShareDir
cpanm ExtUtils::Helpers
cpanm ExtUtils::InstallPaths
cpanm Module::Build::Tiny
cpanm Hash::MultiValue
cpanm Devel::StackTrace
cpanm HTTP::Body
cpanm Filesys::Notify::Simple
cpanm Devel::StackTrace::AsHTML
cpanm Plack
cpanm HTTP::Message::PSGI
cpanm Test::UseAllModules
cpanm Plack::Request

cpanm Test::Fake::HTTPD
cpanm Class::Accessor::Lite
cpanm Test::Flatten
cpanm WWW::Google::Cloud::Messaging
cpanm Text::WikiCreole
cpanm Test::Class

cpanm Data::OptList
cpanm CPAN::Meta::Check
cpanm Test::CheckDeps
cpanm Test::Mouse
cpanm Any::Moose
cpanm Test::Moose
cpanm Test::Class
cpanm Net::APNS

cpanm Amazon::SQS::Simple
cpanm Proc::Wait3;
cpanm Server::Starter;
cpanm Parallel::Prefork;
cpanm Starlet;

## STARMAN:
cpanm ExtUtils::Helpers;
cpanm ExtUtils::Config;
cpanm ExtUtils::InstallPaths;
cpanm Module::Build::Tiny;
cpanm HTTP::Parser::XS;

cpanm Net::OAuth2;

## http://search.cpan.org/CPAN/authors/id/X/XA/XAICRON/JSON-WebToken-0.07.tar.gz
cpanm Test::Mock::Guard";
cpanm JSON::WebToken";

## http://search.cpan.org/CPAN/authors/id/R/RI/RIZEN/Facebook-Graph-1.0600.tar.gz
cpanm Facebook::Graph";

## http://search.cpan.org/CPAN/authors/id/I/IA/IAMCAL/CSS-1.09.tar.gz
cpanm CSS";
## http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/CSS-Tiny-1.19.tar.gz
cpanm CSS::Tiny;


cpanm Test::HexString;
cpanm CPAN::Meta::Prereqs;
cpanm CPAN::Meta::Check;
cpanm Test::CheckDep;
## cpanm Protocol::UWSGI;

## 201352
cpanm String::Urando;
cpanm Net::AWS::SES;
cpanm Nginx;
cpanm Net::Domain::TL;
cpanm Data::Validate::Domai;
cpanm Data::Validate::Emai;
cpanm Email::Vali;
cpanm CSS::Minifier::X;
cpanm MediaWiki::AP;

cpanm Proc::Wait3
cpanm Server::Starter
cpanm Parallel::Prefork
cpanm Starlet

## STARMAN:
cpanm ExtUtils::Helpers
cpanm ExtUtils::Config
cpanm ExtUtils::InstallPaths
cpanm Module::Build::Tiny
cpanm HTTP::Parser::XS

cpanm Net::OAuth2

## http://search.cpan.org/CPAN/authors/id/X/XA/XAICRON/JSON-WebToken-0.07.tar.gz
cpanm Test::Mock::Guard 
cpanm JSON::WebToken 

## http://search.cpan.org/CPAN/authors/id/R/RI/RIZEN/Facebook-Graph-1.0600.tar.gz
cpanm Facebook::Graph 

## http://search.cpan.org/CPAN/authors/id/I/IA/IAMCAL/CSS-1.09.tar.gz
cpanm CSS 
## http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/CSS-Tiny-1.19.tar.gz
cpanm CSS::Tiny


cpanm Test::HexString
cpanm CPAN::Meta::Prereqs
cpanm CPAN::Meta::Check
cpanm Test::CheckDeps
## cpanm Protocol::UWSGI

## 201352
cpanm String::Urandom
cpanm Net::AWS::SES
cpanm Nginx

cpanm Net::Domain::TLD
cpanm Data::Validate::Domain
cpanm Data::Validate::Email
cpanm Email::Valid

cpanm CSS::Minifier::XS
cpanm MediaWiki::API

cpanm IO::CaptureOutput
cpanm Devel::CheckLib

## CANT GET ZEROMQ TO COMPILE UNPATCHED, Alien::ZMQ fixes it.
## ./configure --with-pgm --enable-static --enable-shared --with-gnu-ld
cpanm ExtUtils::CBuilder
cpanm String::ShellQuote
cpanm Alien::ZMQ
cpanm ZMQ::Constants
cpanm ZMQ::LibZMQ3

##
## SOME MORE PERL LIBRARIES
##
cpanm DBIx::ContextualFetch;
cpanm Ima::DBI;
cpanm UNIVERSAL::moniker;
cpanm Class::DBI;
cpanm DBD::mysql;

cpanm Stream::Buffered;
cpanm Test::SharedFork;
cpanm Test::TCP;
cpanm File::ShareDir;
cpanm Hash::MultiValue;
cpanm Devel::StackTrace;
cpanm HTTP::Body;
cpanm Filesys::Notify::Simple;
cpanm Devel::StackTrace::AsHTML;
cpanm Mojolicious;
cpanm AnyEvent;
cpanm WWW::Twilio::API;
cpanm Text::Wrap;
cpanm Plack;

cpanm Digest::SHA1;
cpanm DIME::Payload;
cpanm IPC::Lock::Memcached;
cpanm IPC::ConcurrencyLimit::Lock;

cpanm Data::JavaScript::LiteObject
cpanm JavaScript::Minifier

cpanm ExtUtils::Constant
cpanm Socket
cpanm Net::Ping
cpanm Hijk
cpanm HTTP::Tiny
cpanm Elasticsearch
cpanm Pegex::Parser
cpanm Mo::builder
cpanm Net::AWS::SES

