
# git clone git@github.com:brianhorakh/apidoc.git

/backend/apidoc/bin/apidoc -v -i lib/ -o /httpd/static/apidocs/ -f ".*\.pm$";


cd /httpd/static/apidocs
git commit -a -m "doc release"
git push

#-t mytemplate/
