#!/usr/bin/perl

my ($DBNAME,$DBUSER,$DBPASS) = (@ARGV);

## ADD THE USER WITH A HARMLESS PRIVILEGE, THEN REMOVE THEM (TO RECOVER)
push @SQL, qq~GRANT USAGE ON *.* TO '$DBUSER'\@'localhost';~;
push @SQL, qq~drop user '$DBUSER'\@'localhost';~;
push @SQL, qq~GRANT USAGE ON *.* TO '$DBUSER'\@'%';~;
push @SQL, qq~drop user '$DBUSER'\@'%';~;

push @SQL, qq~create user '$DBUSER'\@'localhost' identified by '$DBPASS';~;
push @SQL, qq~create user '$DBUSER'\@'%' identified by '$DBPASS';~;
##		mysql  create user 'brian'@'localhost' identified by password 'k2j54lkjasdf0932';
## push @SQL, qq~GRANT ALL ON $DBNAME.* TO '$USERNAME'@'*' identified by password('$DBPASS');~;
## 	## set password for 'brian'@'localhost' = password('asdf');
push @SQL, qq~GRANT ALL ON $DBNAME.* TO '$DBUSER'\@'localhost';~;
push @SQL, qq~GRANT CREATE ROUTINE ON $DBNAME.* TO '$DBUSER'\@'localhost';~;
push @SQL, qq~GRANT SELECT,INSERT,UPDATE,DELETE ON $DBNAME.* TO '$DBUSER'\@'%';~;
##		mysqladmin reload
push @SQL, qq~flush privileges;~;
push @SQL, qq~use $DBNAME;~;

print join("\n",@SQL);