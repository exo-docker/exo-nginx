FROM ubuntu:18.04

MAINTAINER eXo Platform <docker@exoplatform.com>

ENV NPS_VERSION=1.13.35.2
ENV NPS_FULL_VERSION=1.13.35.2-stable
ENV NPS_DIR_NAME=incubator-pagespeed-ngx-${NPS_FULL_VERSION}
ENV NGINX_VERSION=1.19.4
ENV MORE_HEADERS_VERSION=0.33
ENV BUILD_DIR=/usr/src
ENV STICKY_VERSION 1.2.6

RUN apt-get update && apt-get install -y build-essential gettext pax-utils zlib1g-dev libpcre3 libpcre3-dev uuid-dev unzip wget curl libssl-dev dnsmasq supervisor libldap2-dev && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${BUILD_DIR} \
    && cd ${BUILD_DIR} \
    && curl -sfSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && tar -xzf nginx.tar.gz \
    && ls nginx-1.19.4 \
    && curl -sfSL https://github.com/openresty/headers-more-nginx-module/archive/v${MORE_HEADERS_VERSION}.tar.gz -o headers-more-nginx-module.tar.gz \
    && tar -xzf headers-more-nginx-module.tar.gz \
    && curl -sfSL https://github.com/Refinitiv/nginx-sticky-module-ng/archive/b14e985ba1c71f77e155e33e9b8c558dc4e90c59.zip -o sticky.zip \
    && unzip -j sticky.zip -d ${BUILD_DIR}/nginx-sticky-module \
    && curl -sfSL https://github.com/kvspb/nginx-auth-ldap/archive/83c059b73566c2ee9cbda920d91b66657cf120b7.zip -o nginx-auth-ldap.zip \
    && unzip -j nginx-auth-ldap.zip -d ${BUILD_DIR}/nginx-auth-ldap \
    && cd ${BUILD_DIR} && wget -O nps.zip https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_FULL_VERSION}.zip \
    && unzip nps.zip \
    && cd ${BUILD_DIR}/${NPS_DIR_NAME} \
    && wget -O psol.tar.gz https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}-x64.tar.gz \
    && tar -xzvf psol.tar.gz

RUN CONFIG="--prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --with-http_ssl_module \
            --with-http_sub_module \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --user=nginx \
            --group=nginx \
            --with-threads \
            --with-http_addition_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_auth_request_module \
            --with-http_realip_module \
            --with-http_v2_module \
            --with-stream \
            --with-stream_ssl_module \
            --with-stream_realip_module \
            --with-http_stub_status_module \
            --with-compat \
            --add-module=${BUILD_DIR}/headers-more-nginx-module-${MORE_HEADERS_VERSION} \
            --add-module=${BUILD_DIR}/${NPS_DIR_NAME} \
            --add-module=${BUILD_DIR}/nginx-auth-ldap ${PS_NGX_EXTRA_FLAGS} \
            --add-module=${BUILD_DIR}/nginx-sticky-module" \
    && echo " ---- Building Nginx --- "

RUN useradd --create-home --user-group -u 999 --shell /bin/nologin nginx \
    && usermod -s /sbin/nologin nginx

RUN cd ${BUILD_DIR}/nginx-${NGINX_VERSION} \
    && ./configure $CONFIG --with-debug \
    && make -j 4 \
    && mv objs/nginx objs/nginx-debug \
    && ./configure $CONFIG \
    && make -j 4 \
    && make install

RUN mv /usr/bin/envsubst /usr/local/bin/ \
    && (rm -rf /var/lib/apt/lists/* 2> /dev/null || echo "OK") \
    && (rm -rf /tmp/* 2> /dev/null || echo "OK") \
    && (rm -rf /tmp/.* 2> /dev/null || echo "OK") \
    && (rm -rf /root/.* 2> /dev/null || echo "OK") \
    && (rm -rf /root/* 2> /dev/null || echo "OK") \
    && mkdir -p /var/log/nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY dnsmasq.conf /etc/dnsmasq.conf

CMD ["/usr/bin/supervisord"]