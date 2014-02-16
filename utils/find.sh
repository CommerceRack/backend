#!/bin/sh
/bin/grep -n -v -P '^[\s\t]*\#' \
	`/usr/bin/find /httpd/static/htdocs/ | grep "cgi$"`  \
	`/usr/bin/find /httpd/static/htdocs/ | grep "pl$"` \
	`/usr/bin/find /httpd/lib | grep "pm$"` \
	`/usr/bin/find /httpd/servers/ | grep "pl$"` \
	`/usr/bin/find /httpd/uwsgi/ | grep "pl$"` \
	`/usr/bin/find /httpd/static/zmvc/latest/ | grep "\.js$"` \
	`/usr/bin/find /httpd/static/zmvc/latest/ | grep "\.html$"`
