backend
=======

CommerceRack Backend Server
release 201408

installation:
=======

SERVER BUILD instructions in ./BUILD.md

cd /
# git clone git@github.com:CommerceRack/backend.git
or
git clone https://github.com/CommerceRack/backend.git
ln -s /backend /httpd
ln -s /backend/lib /backend/modules


cd /backend
git clone https://github.com/CommerceRack/backend-static.git
ln -s /backend/backend-static /backend/static


to provision a user:
=======
/mnt

