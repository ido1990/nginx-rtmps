FROM buildpack-deps:stretch

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.18.0
ENV NGINX_RTMP_MODULE_VERSION 1.2.1

# Install dependencies Stunnel4
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev stunnel4 gettext nano ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx/nginx.conf.template /etc/nginx/nginx.conf.template
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Create folder for HTML and HLS
RUN mkdir -p /www
COPY nginx/index.html /www
# Config Stunnel
RUN mkdir -p  /etc/stunnel/conf.d
# Set up config file 
COPY stunnel/stunnel.conf /etc/stunnel/stunnel.conf
COPY stunnel/stunnel4 /etc/default/stunnel4

#Facebook Stunnel Port 19350
COPY stunnel/facebook.conf /etc/stunnel/conf.d/facebook.conf

#Instagram Stunnel Port 19351
COPY stunnel/instagram.conf /etc/stunnel/conf.d/instagram.conf

#Cloudflare Stunnel Port 19352
COPY stunnel/cloudflare.conf /etc/stunnel/conf.d/cloudflare.conf

#Telegram Stunnel Port 19353
COPY stunnel/telegram.conf /etc/stunnel/conf.d/telegram.conf

#Youtube
ENV YOUTUBE_URL rtmp://a.rtmp.youtube.com/live2/
ENV YOUTUBE_KEY ""

#Facebook
ENV FACEBOOK_URL rtmp://127.0.0.1:19350/rtmp/
ENV FACEBOOK_KEY ""

#Instagram
ENV INSTAGRAM_URL rtmp://127.0.0.1:19351/rtmp/
ENV INSTAGRAM_KEY ""

#Cloudflare
ENV CLOUDFLARE_URL rtmp://127.0.0.1:19352/live/
ENV CLOUDFLARE_KEY ""

#Telegram
ENV TELEGRAM_URL /usr/bin/ffmpeg -analyzeduration 0 -i rtmp://127.0.0.1/live/${STREAM_TOKEN} -c copy -pix_fmt yuv420p -f flv rtmp://127.0.0.1:19353/s/
ENV TELEGRAM_KEY ""

#Twitch
ENV TWITCH_URL ""
ENV TWITCH_KEY ""

ENV DEBUG ""

COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

EXPOSE 1935
EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
