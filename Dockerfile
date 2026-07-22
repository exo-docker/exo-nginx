# syntax=docker/dockerfile:1
FROM alpine:3.23 AS build

ARG NGX_MAINLINE_VER=1.30.4
ARG MODSEC_VER=v3.0.16
ARG OPENSSL_VER=openssl-4.0.1
ARG NGX_BROTLI=master
ARG NGX_HEADERS_MORE=v0.40
ARG NGX_NJS=1.0.0
ARG NGX_MODSEC=v1.0.4
ARG NGX_GEOIP2=3.4
ARG NGX_SECURITY_HEADERS=0.3.0
ARG NGX_LDAP=v1.8
ARG NGX_UPSTREAM_JVM_ROUTE=master
ARG OQS_VER=main
ARG OQS_PROVIDER_VER=main

WORKDIR /src

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
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
    gd-dev \
    libldap \
    openldap-dev

RUN sed -i "s/999/99/" /etc/group \
    && addgroup --gid 999 -S nginx \
    && adduser --uid 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

RUN git clone --recursive --branch ${OPENSSL_VER} --depth 1 https://github.com/openssl/openssl /src/openssl

# ModSecurity
RUN git clone --recursive --depth 1 --branch "$MODSEC_VER" https://github.com/SpiderLabs/ModSecurity /src/ModSecurity \
    && sed -i "s|SecRuleEngine.*|SecRuleEngine On|g" /src/ModSecurity/modsecurity.conf-recommended \
    && sed -i "s|unicode.mapping|/etc/nginx/modsec/unicode.mapping|g" /src/ModSecurity/modsecurity.conf-recommended \
    && cd /src/ModSecurity \
    && /src/ModSecurity/build.sh \
    && /src/ModSecurity/configure --with-pcre2 --with-lmdb \
    && make -j "$(nproc)" \
    && make -j "$(nproc)" install \
    && strip -s /usr/local/modsecurity/lib/libmodsecurity.so.3

# Clone all modules in parallel
RUN git clone --recursive --depth 1 --branch "$NGX_BROTLI"             https://github.com/google/ngx_brotli                    /src/ngx_brotli & \
    git clone --recursive --depth 1 --branch "$NGX_HEADERS_MORE"       https://github.com/openresty/headers-more-nginx-module  /src/headers-more-nginx-module & \
    git clone --recursive --depth 1 --branch "$NGX_NJS"                https://github.com/nginx/njs                             /src/njs & \
    git clone --recursive --depth 1 --branch "$NGX_MODSEC"             https://github.com/SpiderLabs/ModSecurity-nginx          /src/ModSecurity-nginx & \
    git clone --recursive --depth 1 --branch "$NGX_GEOIP2"             https://github.com/leev/ngx_http_geoip2_module           /src/ngx_http_geoip2_module & \
    git clone --recursive --depth 1 --branch "$NGX_SECURITY_HEADERS"   https://github.com/GetPageSpeed/ngx_security_headers     /src/ngx_security_headers & \
    git clone --recursive --depth 1 --branch "$NGX_UPSTREAM_JVM_ROUTE" https://github.com/hbenali/nginx-upstream-jvm-route      /src/nginx-upstream-jvm-route & \
    git clone --recursive --depth 1 --branch "$NGX_LDAP"               https://github.com/Ericbla/nginx-auth-ldap               /src/nginx-auth-ldap & \
    wait

# Download and prepare nginx source
RUN wget https://nginx.org/download/nginx-"$NGX_MAINLINE_VER".tar.gz -O - | tar xzC /src \
    && mv /src/nginx-"$NGX_MAINLINE_VER" /src/nginx \
    && wget https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_1.29.2%2B.patch -O /src/nginx/dynamic_tls_records.patch \
    && sed -i "s|nginx/|NGINX-OpenSSL with ModSec/|g" /src/nginx/src/core/nginx.h \
    && sed -i "s|Server: nginx|Server: NGINX-OpenSSL with ModSec|g" /src/nginx/src/http/ngx_http_header_filter_module.c \
    && sed -i "s|<hr><center>nginx</center>|<hr><center>NGINX-OpenSSL with ModSec</center>|g" /src/nginx/src/http/ngx_http_special_response.c \
    && cd /src/nginx \
    && patch -p1 < dynamic_tls_records.patch \
    && patch -p1 < /src/nginx-upstream-jvm-route/jvm_route.patch

# Configure and build nginx
ARG BUILD
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
    --with-openssl-opt="shared no-ssl3 no-ssl3-method no-weak-ssl-ciphers" \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-http_image_filter_module=dynamic \
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

# Install OpenSSL shared libraries from the nginx-built OpenSSL
RUN mkdir -p /usr/local/lib /usr/local/include/openssl \
    && cp -r /src/openssl/include/openssl/*.h /usr/local/include/openssl/ \
    && find /src/openssl -name 'libcrypto.so*' -exec cp -f {} /usr/local/lib/ \; \
    && find /src/openssl -name 'libssl.so*' -exec cp -f {} /usr/local/lib/ \; \
    && ls -la /usr/local/lib/libcrypto.so*

# Build and install liboqs (post-quantum crypto library)
ARG OQS_VER
RUN git clone --recursive --depth 1 --branch ${OQS_VER} https://github.com/open-quantum-safe/liboqs.git /src/liboqs \
    && cmake -S /src/liboqs -B /src/liboqs/build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_SHARED_LIBS=ON \
        -DOPENSSL_ROOT_DIR=/usr/local \
    && cmake --build /src/liboqs/build --parallel "$(nproc)" \
    && cmake --install /src/liboqs/build

# Build and install oqs-provider (OpenSSL 3.x provider for PQC algorithms)
ARG OQS_PROVIDER_VER
RUN git clone --recursive --depth 1 --branch ${OQS_PROVIDER_VER} https://github.com/open-quantum-safe/oqs-provider.git /src/oqs-provider \
    && cmake -S /src/oqs-provider -B /src/oqs-provider/build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DOPENSSL_ROOT_DIR=/usr/local \
        -Dliboqs_DIR=/usr/local/lib/cmake/liboqs \
    && cmake --build /src/oqs-provider/build --parallel "$(nproc)" \
    && cmake --install /src/oqs-provider/build \
    && mkdir -p /usr/local/lib/ossl-modules \
    && cp -f /src/oqs-provider/build/lib/oqsprovider.so /usr/local/lib/ossl-modules/oqsprovider.so \
    && strip -s /usr/local/lib/ossl-modules/oqsprovider.so

FROM python:alpine3.23

COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /usr/lib/nginx /usr/lib/nginx
COPY --from=build /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=build /usr/lib/perl5/core_perl/perllocal.pod /usr/lib/perl5/core_perl/perllocal.pod
COPY --from=build /usr/local/modsecurity/lib/libmodsecurity.so.3 /usr/local/modsecurity/lib/libmodsecurity.so.3

RUN sed -i "s/999/99/" /etc/group \
    && addgroup -g 999 -S nginx \
    && adduser -u 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache \
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
    gd-dev \
    dnsmasq \
    curl

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir \
    "setuptools<81" \
    "supervisor==4.3.0"

ENV PYTHONWARNINGS="ignore::UserWarning"

RUN mkdir -p /var/log/nginx/ \
    && mkdir -p /etc/nginx/modsec \
    && touch /var/log/nginx/access.log \
    && touch /var/log/nginx/error.log \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
    && chown --verbose nginx:nginx -R /var/log/nginx

COPY --from=build /src/ModSecurity/unicode.mapping /etc/nginx/modsec/unicode.mapping
COPY --from=build /src/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf.example

COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY openssl.cnf /etc/ssl/openssl.cnf

ENV OPENSSL_CONF=/etc/ssl/openssl.cnf

COPY --from=build /usr/local/lib/libcrypto.so* /usr/local/lib/
COPY --from=build /usr/local/lib/libssl.so* /usr/local/lib/
COPY --from=build /usr/local/lib/liboqs.so* /usr/local/lib/
COPY --from=build /usr/local/lib/ossl-modules/oqsprovider.so /usr/local/lib/ossl-modules/oqsprovider.so

LABEL maintainer="eXo Platform <docker@exoplatform.com>"

RUN nginx -V; nginx -t

EXPOSE 80 81 443

STOPSIGNAL SIGTERM

RUN chown --verbose nginx:nginx /var/run/nginx.pid

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
