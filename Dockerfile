FROM alpine:3.20 AS build

ARG BUILD
ARG NGX_MAINLINE_VER=1.26.3
ARG MODSEC_VER=v3.0.13
ARG OPENSSL_VER=openssl-3.4.0
ARG NGX_BROTLI=master
ARG NGX_HEADERS_MORE=v0.38
ARG NGX_NJS=0.8.9
ARG NGX_MODSEC=v1.0.3
ARG NGX_GEOIP2=3.4
ARG NGX_SECURITY_HEADERS=0.1.1
ARG NGX_LDAP_AUTH=v1.7
ARG NGX_UPSTREAM_JVM_ROUTE=master

WORKDIR /src

# Install the required packages
RUN apk add --no-cache \
    ca-certificates \
    build-base \
    patch \
    cmake \
    git \
    libtool \
    autoconf \
    automake \
    libatomic_ops-dev \
    zlib-dev \
    pcre2-dev \
    linux-headers \
    yajl-dev \
    libxml2-dev \
    libxslt-dev \
    perl-dev \
    curl-dev \
    lmdb-dev \
    geoip-dev \
    libmaxminddb-dev \
    libfuzzy2-dev \
    gd-dev  \
    libldap \
    openldap-dev \
    patch 

RUN sed -i "s/999/99/" /etc/group
RUN \
    addgroup --gid 999 -S nginx \
    && adduser --uid 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

# Clone and build OpenSSL
RUN git clone --recursive --branch ${OPENSSL_VER} --depth 1 https://github.com/openssl/openssl /src/openssl

# ModSecurity
RUN (git clone --recursive --depth 1 --branch "$MODSEC_VER" https://github.com/SpiderLabs/ModSecurity /src/ModSecurity \
    && sed -i "s|SecRuleEngine.*|SecRuleEngine On|g" /src/ModSecurity/modsecurity.conf-recommended \
    && sed -i "s|unicode.mapping|/etc/nginx/modsec/unicode.mapping|g" /src/ModSecurity/modsecurity.conf-recommended \
    && cd /src/ModSecurity \
    && /src/ModSecurity/build.sh \
    && /src/ModSecurity/configure --with-pcre2 --with-lmdb \
    && make -j "$(nproc)" \
    && make -j "$(nproc)" install \
    && strip -s /usr/local/modsecurity/lib/libmodsecurity.so.3) 

# Modules
RUN (git clone --recursive --depth 1 --branch "$NGX_BROTLI" https://github.com/google/ngx_brotli /src/ngx_brotli \
    && git clone --recursive --depth 1 --branch "$NGX_HEADERS_MORE" https://github.com/openresty/headers-more-nginx-module /src/headers-more-nginx-module \
    && git clone --recursive --depth 1 --branch "$NGX_NJS" https://github.com/nginx/njs /src/njs \
    && git clone --recursive --depth 1 --branch "$NGX_MODSEC" https://github.com/SpiderLabs/ModSecurity-nginx /src/ModSecurity-nginx \
    && git clone --recursive --depth 1 --branch "$NGX_GEOIP2" https://github.com/leev/ngx_http_geoip2_module /src/ngx_http_geoip2_module \
    && git clone --recursive --depth 1 --branch "$NGX_SECURITY_HEADERS" https://github.com/GetPageSpeed/ngx_security_headers /src/ngx_security_headers \
    && git clone --recursive --depth 1 --branch "$NGX_UPSTREAM_JVM_ROUTE" https://github.com/nulab/nginx-upstream-jvm-route /src/nginx-upstream-jvm-route \
    && git clone --recursive --depth 1 --branch "$NGX_LDAP_AUTH" https://github.com/Ericbla/nginx-auth-ldap /src/nginx-auth-ldap )

# Nginx
RUN (wget https://nginx.org/download/nginx-"$NGX_MAINLINE_VER".tar.gz -O - | tar xzC /src \
    && mv /src/nginx-"$NGX_MAINLINE_VER" /src/nginx \
    && wget https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_1.25.1%2B.patch -O /src/nginx/dynamic_tls_records.patch \
    && sed -i "s|nginx/|NGINX-OpenSSL with ModSec/|g" /src/nginx/src/core/nginx.h \
    && sed -i "s|Server: nginx|Server: NGINX-OpenSSL with ModSec|g" /src/nginx/src/http/ngx_http_header_filter_module.c \
    && sed -i "s|<hr><center>nginx</center>|<hr><center>NGINX-OpenSSL with ModSec</center>|g" /src/nginx/src/http/ngx_http_special_response.c \
    && cd /src/nginx \
    && patch -p1 < dynamic_tls_records.patch \
    && patch -p0 < /src/nginx-upstream-jvm-route/jvm_route.patch)

RUN cd /src/nginx \
    && ./configure \
    --build=${BUILD} \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-threads \
    --with-file-aio \
    --with-libatomic \
    --with-pcre \
    --without-poll_module \
    --without-select_module \
    --with-openssl="/src/openssl" \
    --with-openssl-opt="no-ssl3 no-ssl3-method no-weak-ssl-ciphers" \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-http_image_filter_module=dynamic  \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_ssl_module \
    --with-http_perl_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_realip_module \
    --with-http_random_index_module \
    --with-http_mp4_module \
    --with-http_flv_module \
    --with-http_dav_module \
    --with-http_gunzip_module \
    --with-http_addition_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_slice_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --add-dynamic-module=/src/ngx_brotli \
    --add-dynamic-module=/src/headers-more-nginx-module \
    --add-dynamic-module=/src/njs/nginx \
    --add-dynamic-module=/src/ModSecurity-nginx \
    --add-dynamic-module=/src/ngx_http_geoip2_module \
    --add-module=/src/nginx-auth-ldap \
    --add-module=/src/ngx_security_headers \
    && make -j "$(nproc)" \
    && make -j "$(nproc)" install \
    && rm /src/nginx/*.patch \
    && strip -s /usr/sbin/nginx \
    && strip -s /usr/lib/nginx/modules/*.so

FROM python:alpine3.20

COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx   /usr/sbin/nginx
COPY --from=build /usr/lib/nginx /usr/lib/nginx
COPY --from=build /usr/local/lib/perl5  /usr/local/lib/perl5
COPY --from=build /usr/lib/perl5/core_perl/perllocal.pod    /usr/lib/perl5/core_perl/perllocal.pod
COPY --from=build /usr/local/modsecurity/lib/libmodsecurity.so.3    /usr/local/modsecurity/lib/libmodsecurity.so.3

COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY dnsmasq.conf /etc/dnsmasq.conf

RUN sed -i "s/999/99/" /etc/group
RUN addgroup -g 999 -S nginx \
    && adduser -u 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    tini \
    zlib \
    pcre2 \
    lmdb \
    libstdc++ \
    yajl \
    libxml2 \
    libxslt \
    libfuzzy2 \
    perl \
    libcurl \
    geoip \
    libmaxminddb-libs \
    libldap \
    gd-dev  \
    supervisor \
    dnsmasq \
    curl

RUN mkdir -p /var/log/nginx/ \
    && mkdir -p /etc/nginx/modsec \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
    && chown --verbose nginx:nginx -R /var/log/nginx

COPY --from=build /src/ModSecurity/unicode.mapping  /etc/nginx/modsec/unicode.mapping
COPY --from=build /src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf.example

LABEL maintainer="eXo Platform <docker@exoplatform.com>"

# show env
RUN env | sort

# test the configuration
RUN nginx -V; nginx -t

EXPOSE 80 81 443

STOPSIGNAL SIGTERM

# prepare to switch to non-root - update file permissions
RUN chown --verbose nginx:nginx \
    /var/run/nginx.pid

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]