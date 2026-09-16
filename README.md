# eXo Nginx Container (HTTP/3)

This repository contains a custom build of Nginx with additional modules, including support for ModSecurity, HTTP/3 (QUIC) via quictls, and various other enhancements. This image is designed for use in environments requiring advanced HTTP and security functionalities.

Current versions: Nginx `1.30.5`, quictls `openssl-3.3.2`, njs `1.0.1`, ModSecurity `3.0.16`.

## Usage

This image can be used similarly to the official [nginx image](https://hub.docker.com/_/nginx/), with additional features and modules. Configuration and management follow standard Nginx conventions.

### Example Usage

```bash
docker run --name exo-nginx -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro -p 80:80 -p 443:443 -p 443:443/udp exoplatform/nginx:http3
```

## List of Activated Modules

The following modules are included and activated in this build:

### Core Modules

- `http_ssl_module`: Enables HTTPS support.
- `http_v2_module`: Adds support for HTTP/2.
- `http_v3_module`: Adds support for HTTP/3 (QUIC), backed by quictls.
- `http_auth_request_module`: Allows for authorization requests.
- `http_stub_status_module`: Provides basic status information.
- `http_realip_module`: Adjusts client IP address to a trusted upstream.
- `http_addition_module`: Appends additional content to responses.
- `http_gunzip_module`: Decompresses responses for clients that don't support gzip.
- `http_gzip_static_module`: Serves pre-compressed `.gz` files.

### Dynamic Modules

- `ngx_headers_more`: Allows modification of HTTP headers.
- `ngx_brotli`: Provides Brotli compression.
- `njs`: Adds scripting support in nginx with a JavaScript-like language.
- `ModSecurity-nginx`: Integrates ModSecurity for enhanced security.
- `ngx_http_geoip2_module`: Adds GeoIP2-based client location.
- `http_image_filter_module`: Transforms images in GIF, JPEG, and PNG formats.
- `http_perl_module`: Enables embedded Perl.
- `http_geoip_module`: Adds GeoIP-based client location.

### Static Third-Party modules

- `ngx_security_headers`: Enforces security-related headers.
- `nginx-auth-ldap`: Adds LDAP-based authentication.

### Stream Modules

- `stream`: Enables TCP/UDP proxying.
- `stream_ssl_module`: Adds SSL/TLS support for streams.
- `stream_ssl_preread_module`: Allows inspection of SSL/TLS handshakes.
- `stream_realip_module`: Adjusts client IP address for streams.
- `stream_geoip_module`: Adds GeoIP support for streams.

### Mail Modules

- `mail`: Enables mail (SMTP/POP3/IMAP) proxying.
- `mail_ssl_module`: Adds SSL/TLS support for mail.

### Additional Features

- [nginx-upstream-jvm-route](https://github.com/hbenali/nginx-upstream-jvm-route): Balances JVM-based upstreams with session persistence.
- [Dynamic TLS records](https://github.com/nginx-modules/ngx_http_tls_dyn_size): Dynamically sizes TLS records to improve latency (DTLS patch).

## Configuration

The image uses a custom `nginx.conf` file by default, which can be overridden by mounting your own configuration file:

```bash
docker run -v $(pwd)/custom-nginx.conf:/etc/nginx/nginx.conf:ro exoplatform/nginx:http3
```

A shared SSL/TLS configuration (Mozilla intermediate profile, OCSP stapling) is provided at `/etc/nginx/conf.d/ssl_common.conf` and can be included in your server blocks.

To serve HTTP/3, enable QUIC listening in your server blocks:

```nginx
listen 443 quic;
listen 443 ssl;
add_header Alt-Svc 'h3=":443"; ma=86400';
```

### Supervisord

This image includes `supervisord` for process management. The configuration is located at `/etc/supervisor/conf.d/supervisord.conf`.

### ModSecurity

ModSecurity is included for advanced security. Configuration can be found at `/etc/nginx/modsec/modsecurity.conf.example`. A Unicode mapping file is also provided at `/etc/nginx/modsec/unicode.mapping`.

## Exposed Ports

- `80`: HTTP
- `81`: Additional HTTP (if required by configuration)
- `443`: HTTPS
- `443/udp`: HTTP/3 (QUIC)

## Maintainer

Maintained by eXo Platform – [docker@exoplatform.com](mailto:docker@exoplatform.com).

---

For further details, refer to the [Nginx documentation](https://nginx.org/en/docs/) and the linked module repositories.
