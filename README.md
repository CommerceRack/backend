backend
=======

CommerceRack Backend Server
release 201402

installation
=======

cd /
git clone git@github.com:CommerceRack/backend.git
ln -s /backend /httpd
ln -s /backend/lib /backend/modules


cd /backend
git clone git@github.com:CommerceRack/backend-static.git
ln -s /backend/backend-static /backend/static

