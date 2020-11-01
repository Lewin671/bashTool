#!/bin/bash

git clone https://github.com/wulabing/3DCEList.git /usr/local/3DCEList

cat << 'EOF' > /etc/nginx/conf/conf.d/demo.conf
server {
  listen 80;
  server_name test;
  root /usr/local/3DCEList;
  location / {
    index  index.html;
  }
}
EOF


systemctl restart nginx
echo "finished"


