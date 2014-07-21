#!/bin/bash

if [ ! -f phantomjs-1.9.7-linux-x86_64.tar.bz2 ] ; then
	cd /usr/local
	wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
	tar -xjvf phantomjs-1.9.7-linux-x86_64.tar.bz2*
	## cd phantomjs-1.9.7-linux-x86_64
	ln -s /usr/local/phantomjs-1.9.7-linux-x86_64 /usr/local/phantomjs
	cd /usr/local/bin
	ln -s /usr/local/phantomjs/bin/phantomjs /usr/local/bin/phantomjs
fi;

cpanm WWW::Mechanize::PhantomJS

                          