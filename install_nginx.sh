# 手动编译nginx for Ubuntu,debain
#!/bin/bash

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"


nginx_conf_dir="/etc/nginx/conf/conf.d"
nginx_conf="${nginx_conf_dir}/v2ray.conf"
nginx_dir="/etc/nginx"
nginx_openssl_src="/usr/local/src"
nginx_systemd_file="/etc/systemd/system/nginx.service"
nginx_version="1.18.0"
nginx_bin_path="/usr/sbin/nginx"
openssl_version="1.1.1g"
jemalloc_version="5.2.1"
pcre_version="8.44"
nginx_log_folder="/var/log/nginx/"
THREAD=2

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

# 安装依赖
apt-get update
apt-get install git gcc make build-essential wget lsof  -y
judge "依赖安装完成"

rm -rf ${nginx_openssl_src}

# 开始下载安装
wget -nc --no-check-certificate http://nginx.org/download/nginx-${nginx_version}.tar.gz -P ${nginx_openssl_src}
judge "Nginx 下载"

wget -nc --no-check-certificate https://www.openssl.org/source/openssl-${openssl_version}.tar.gz -P ${nginx_openssl_src}
judge "openssl 下载"

wget -nc --no-check-certificate https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_version}/jemalloc-${jemalloc_version}.tar.bz2 -P ${nginx_openssl_src}
judge "jemalloc 下载"

wget https://ftp.pcre.org/pub/pcre/pcre-"${pcre_version}".tar.gz  -P ${nginx_openssl_src}
judge "pcre 下载"

cd ${nginx_openssl_src} || exit

git clone --recursive https://github.com/google/ngx_brotli.git
judge "brotli 下载"

git clone https://github.com/cloudflare/zlib.git zlib
cd zlib
make -f Makefile.in distclean
judge "zlib下载编译"

cd ${nginx_openssl_src}
[[ -d nginx-"$nginx_version" ]] && rm -rf nginx-"$nginx_version"
tar -zxvf nginx-"$nginx_version".tar.gz

[[ -d openssl-"$openssl_version" ]] && rm -rf openssl-"$openssl_version"
tar -zxvf openssl-"$openssl_version".tar.gz

[[ -d jemalloc-"${jemalloc_version}" ]] && rm -rf jemalloc-"${jemalloc_version}"
tar -xvf jemalloc-"${jemalloc_version}".tar.bz2

[[ -d pcre"{pcre_version}".tar.gz ]] && rm -rf pcre"{pcre_version}"
tar -zxvf pcre-"${pcre_version}".tar.gz

[[ -d "$nginx_dir" ]] && rm -rf ${nginx_dir}

echo -e "${OK} ${GreenBG} 即将开始编译安装 jemalloc ${Font}"
sleep 2

cd jemalloc-${jemalloc_version} || exit
./configure
judge "编译检查"
make -j "${THREAD}" && make install
judge "jemalloc 编译安装"
echo '/usr/local/lib' >/etc/ld.so.conf.d/local.conf
ldconfig

echo -e "${OK} ${GreenBG} 即将开始编译安装 Nginx, 过程稍久，请耐心等待 ${Font}"
sleep 4


cd "${nginx_openssl_src}"/nginx-"${nginx_version}" || exit

./configure --prefix="${nginx_dir}" \
    --sbin-path="${nginx_bin_path}" \
    --with-http_ssl_module \
    --with-zlib=../zlib --with-http_gzip_static_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-compat --with-file-aio --with-threads\
    --with-http_realip_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_secure_link_module \
    --with-http_v2_module\
    --with-cc-opt='-O3' \
    --with-ld-opt="-ljemalloc" \
    --with-openssl=../openssl-"${openssl_version}" \
    --add-module=../ngx_brotli \
    --with-pcre=../pcre-"${pcre_version}" --with-pcre-jit 
    

judge "编译检查"
make -j "${THREAD}" && make install
judge "Nginx 编译安装"

# 修改基本配置
#sed -i 's/#user  nobody;/user  root;/' ${nginx_dir}/conf/nginx.conf
#sed -i 's/worker_processes  1;/worker_processes  3;/' ${nginx_dir}/conf/nginx.conf
#sed -i 's/    worker_connections  1024;/    worker_connections  4096;/' ${nginx_dir}/conf/nginx.conf
#sed -i '$i include conf.d/*.conf;' ${nginx_dir}/conf/nginx.conf

cat << 'EOF' > ${nginx_dir}/conf/nginx.conf
user root;
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    use epoll;
    multi_accept on;
    worker_connections 65535;
}

http {
    charset utf-8;
    sendfile on;
    aio threads;
    directio 512k;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    # MIME
    include mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png text/xml;   #指定允许进行压缩类型
    gzip_disable "MSIE [1-6]\.(?!.*SV1)";

    # Brotli
    brotli on;
    brotli_comp_level 6;
    brotli_static on;
    # brotli_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
    brotli_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png text/xml;   #指定允许进行压缩类型


    include conf.d/*.conf;
}
EOF

mkdir ${nginx_log_folder}
# 添加配置文件夹，适配旧版脚本
mkdir ${nginx_dir}/conf/conf.d


cat << 'EOF' > ${nginx_systemd_file}

# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload #重载
systemctl enable nginx #开机启动
systemctl start nginx #运行