# https://hg.nginx.org/nginx-quic/fie/tip/src/core/nginx.h
ARG NGINX_VERSION=1.24.0

# https://hg.nginx.org/nginx-quic/shortlog/quic
ARG NGINX_COMMIT=91ad1abfb285

# https://github.com/google/ngx_brotli
ARG NGX_BROTLI_COMMIT=6e975bcb015f62e1f303054897783355e2a877dc

# https://github.com/google/boringssl
ARG BORINGSSL_COMMIT=8ce0e1c14e48109773f1e94e5f8b020aa1e24dc5

# https://github.com/kvspb/nginx-auth-ldap/releases
ARG LDAP_AUTH_COMMIT=42d195d7a7575ebab1c369ad3fc5d78dc2c2669c

# http://hg.nginx.org/njs
ARG NJS_COMMIT=b33aae5e8dc6

# https://github.com/nulab/nginx-upstream-jvm-route
ARG NGINX_UPSTREAM_JVM_ROUTE_COMMIT=c4c92e797c0a06840017bf5c881378dabf6490a5

# https://github.com/openresty/headers-more-nginx-module#installation
# we want to have https://github.com/openresty/headers-more-nginx-module/commit/e536bc595d8b490dbc9cf5999ec48fca3f488632
ARG HEADERS_MORE_VERSION=0.34

#https://github.com/GetPageSpeed/ngx_security_headers
ARG SECURITY_HEADERS_VERSION=0.0.11

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4

# https://hg.nginx.org/nginx-quic/file/quic/README#l72
ARG CONFIG="\
		--build=quic-$NGINX_COMMIT-boringssl-$BORINGSSL_COMMIT \
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
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
		--with-http_v3_module \
		--add-module=/usr/src/ngx_brotli \
		--add-module=/usr/src/headers-more-nginx-module-$HEADERS_MORE_VERSION \
		--add-module=/usr/src/ngx_security_headers-${SECURITY_HEADERS_VERSION} \
		--add-module=/usr/src/njs/nginx \
		--add-module=/usr/src/nginx-auth-ldap \
		--add-dynamic-module=/usr/src/ngx_http_geoip2_module \
	"

FROM alpine:3.17 AS base

ARG NGINX_VERSION
ARG NGINX_COMMIT
ARG NGX_BROTLI_COMMIT
ARG LDAP_AUTH_COMMIT
ARG NGINX_UPSTREAM_JVM_ROUTE_COMMIT
ARG HEADERS_MORE_VERSION
ARG SECURITY_HEADERS_VERSION
ARG NJS_COMMIT
ARG GEOIP2_VERSION
ARG CONFIG

RUN \
	apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		musl-dev \
		go \
		ninja \
		mercurial \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		perl-dev \
		ldb-dev \
		libldap \
		openldap-dev \
		patch \
	&& apk add --no-cache --virtual .brotli-build-deps \
		autoconf \
		libtool \
		automake \
		git \
		g++ \
		cmake \
	&& apk add --no-cache --virtual .geoip2-build-deps \
		libmaxminddb-dev \
	&& apk add --no-cache --virtual .njs-build-deps \
		readline-dev

WORKDIR /usr/src/

RUN sed -i "s/999/99/" /etc/group
RUN \
	addgroup --gid 999 -S nginx \
	&& adduser --uid 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

RUN \
	echo "Cloning nginx $NGINX_VERSION (rev $NGINX_COMMIT from 'quic' branch) ..." \
	&& hg clone -b quic --rev $NGINX_COMMIT https://hg.nginx.org/nginx-quic /usr/src/nginx-$NGINX_VERSION

RUN \
	echo "Cloning brotli $NGX_BROTLI_COMMIT ..." \
	&& mkdir /usr/src/ngx_brotli \
	&& cd /usr/src/ngx_brotli \
	&& git init \
	&& git remote add origin https://github.com/google/ngx_brotli.git \
	&& git fetch --depth 1 origin $NGX_BROTLI_COMMIT \
	&& git checkout --recurse-submodules -q FETCH_HEAD \
	&& git submodule update --init --depth 1

# hadolint ignore=SC2086
RUN \
  echo "Cloning boringssl ..." \
  && cd /usr/src \
  && git clone https://github.com/google/boringssl \
  && cd boringssl \
  && git checkout $BORINGSSL_COMMIT

RUN \
  echo "Building boringssl ..." \
  && cd /usr/src/boringssl \
  && mkdir build \
  && cd build \
  && cmake -GNinja .. \
  && ninja

RUN \
  echo "Downloading headers-more-nginx-module ..." \
  && cd /usr/src \
  && wget -q https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_VERSION}.tar.gz -O headers-more-nginx-module.tar.gz \
  && tar -xf headers-more-nginx-module.tar.gz

RUN \
  echo "Downloading ngx_security_headers-module ..." \
  && cd /usr/src \
  && wget -q https://github.com/GetPageSpeed/ngx_security_headers/archive/refs/tags/${SECURITY_HEADERS_VERSION}.tar.gz -O ngx_security_headers.tar.gz \
  && tar -xf ngx_security_headers.tar.gz

RUN \
  echo "Downloading ngx_http_geoip2_module ..." \
  && git clone --depth 1 --branch ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /usr/src/ngx_http_geoip2_module

RUN \
  echo "Cloning nginx-auth-ldap ..." \
  && cd /usr/src \
  && git clone https://github.com/kvspb/nginx-auth-ldap.git \
  && cd nginx-auth-ldap \
  && git checkout $LDAP_AUTH_COMMIT

RUN \
  echo "Cloning and configuring njs ..." \
  && cd /usr/src \
  && hg clone --rev ${NJS_COMMIT} http://hg.nginx.org/njs \
  && cd /usr/src/njs \
  && ./configure \
  && make njs \
  && mv /usr/src/njs/build/njs /usr/sbin/njs \
  && echo "njs v$(njs -v)"

RUN \
  echo "Cloning nginx-upstream-jvm-route ..." \
  && cd /usr/src \
  && git clone https://github.com/nulab/nginx-upstream-jvm-route.git \
  && cd nginx-upstream-jvm-route \
  && git checkout $NGINX_UPSTREAM_JVM_ROUTE_COMMIT

RUN \
  echo "Building nginx ..." \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& patch -p0 < ../nginx-upstream-jvm-route/jvm_route.patch \
	&& ./auto/configure $CONFIG \
      --with-cc-opt="-I../boringssl/include"   \
      --with-ld-opt="-L../boringssl/build/ssl  \
                     -L../boringssl/build/crypto" \
	&& make -j"$(getconf _NPROCESSORS_ONLN)"

RUN \
	cd /usr/src/nginx-$NGINX_VERSION \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	\
	# https://tools.ietf.org/html/rfc7919
	# https://github.com/mozilla/ssl-config-generator/blob/master/docs/ffdhe4096.txt
	&& wget -q https://ssl-config.mozilla.org/ffdhe4096.txt -O /etc/ssl/dhparam.pem \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	\
	&& scanelf --needed --nobanner /usr/sbin/nginx /usr/sbin/njs /usr/lib/nginx/modules/*.so /usr/bin/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u > /tmp/runDeps.txt

FROM alpine:3.17
ARG NGINX_VERSION
ARG NGINX_COMMIT

ENV NGINX_VERSION $NGINX_VERSION
ENV NGINX_COMMIT $NGINX_COMMIT

COPY --from=base /tmp/runDeps.txt /tmp/runDeps.txt
COPY --from=base /etc/nginx /etc/nginx
COPY --from=base /usr/lib/nginx/modules/*.so /usr/lib/nginx/modules/
COPY --from=base /usr/sbin/nginx /usr/sbin/
COPY --from=base /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
COPY --from=base /usr/bin/envsubst /usr/local/bin/envsubst
COPY --from=base /etc/ssl/dhparam.pem /etc/ssl/dhparam.pem

COPY --from=base /usr/sbin/njs /usr/sbin/njs

RUN sed -i "s/999/99/" /etc/group
# hadolint ignore=SC2046
RUN \
	addgroup --gid 999 -S nginx \
	&& adduser --uid 999 -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .nginx-rundeps tzdata supervisor dnsmasq curl $(cat /tmp/runDeps.txt) \
	&& rm /tmp/runDeps.txt \
	&& ln -s /usr/lib/nginx/modules /etc/nginx/modules \
	# forward request and error logs to docker log collector
	&& mkdir /var/log/nginx \
	&& touch /var/log/nginx/access.log /var/log/nginx/error.log \
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
    && chown --verbose nginx:nginx -R /var/log/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY ssl_common.conf /etc/nginx/conf.d/ssl_common.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY dnsmasq.conf /etc/dnsmasq.conf

# show env
RUN env | sort

# njs version
RUN njs -v

# test the configuration
RUN nginx -V; nginx -t

EXPOSE 443 80 81

STOPSIGNAL SIGTERM

# prepare to switching to non-root - update file permissions
RUN chown --verbose nginx:nginx \
	/var/run/nginx.pid

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
