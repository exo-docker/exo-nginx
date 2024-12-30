# eXo Nginx Container

This repository contains a custom build of Nginx with additional modules, including support for ModSecurity, Google PageSpeed, and various other enhancements. This image is designed for use in environments requiring advanced HTTP and security functionalities.

## Usage

This image can be used similarly to the official [nginx image](https://hub.docker.com/_/nginx/), with additional features and modules. Configuration and management follow standard Nginx conventions.

### Example Usage

```bash
docker run --name exo-nginx -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro -p 80:80 exoplatform/nginx
```

## List of Activated Modules

The following modules are included and activated in this build:

### Core Modules

- `http_ssl_module`: Enables HTTPS support.
- `http_v2_module`: Adds support for HTTP/2.
- `http_auth_request_module`: Allows for authorization requests.
- `http_stub_status_module`: Provides basic status information.
- `http_realip_module`: Adjusts client IP address to a trusted upstream.
- `http_addition_module`: Appends additional content to responses.
- `http_gunzip_module`: Decompresses responses for clients that don't support gzip.
- `http_gzip_static_module`: Serves pre-compressed `.gz` files.
- `http_secure_link_module`: Secures links with tokens.
- `http_slice_module`: Enables partial content delivery.
- `http_flv_module`: Enables streaming of FLV files.
- `http_mp4_module`: Enables streaming of MP4 files.

### Dynamic Modules

- `ngx_headers_more`: Allows modification of HTTP headers.
- `ngx_brotli`: Provides Brotli compression.
- `ModSecurity-nginx`: Integrates ModSecurity for enhanced security.
- `ngx_http_geoip2_module`: Adds GeoIP2-based client location.
- `ngx_security_headers`: Enforces security-related headers.
- `nginx-auth-ldap`: Adds LDAP-based authentication.

### Stream Modules

- `stream`: Enables TCP/UDP proxying.
- `stream_ssl_module`: Adds SSL/TLS support for streams.
- `stream_ssl_preread_module`: Allows inspection of SSL/TLS handshakes.
- `stream_geoip_module`: Adds GeoIP support for streams.

### Additional Features

- [nginx-sticky-module-ng](https://github.com/Refinitiv/nginx-sticky-module-ng): Adds session persistence.
- [nginx-upstream-jvm-route](https://github.com/nulab/nginx-upstream-jvm-route): Balances JVM-based upstreams.

## Configuration

The image uses a custom `nginx.conf` file by default, which can be overridden by mounting your own configuration file:

```bash
docker run -v $(pwd)/custom-nginx.conf:/etc/nginx/nginx.conf:ro exoplatform/nginx
```

### Supervisord

This image includes `supervisord` for process management. The configuration is located at `/etc/supervisor/conf.d/supervisord.conf`.

### ModSecurity

ModSecurity is included for advanced security. Configuration can be found at `/etc/nginx/modsec/modsecurity.conf.example`. A Unicode mapping file is also provided at `/etc/nginx/modsec/unicode.mapping`.


## Exposed Ports

- `80`: HTTP
- `81`: Additional HTTP (if required by configuration)
- `443`: HTTPS

## Maintainer

Maintained by eXo Platform – [docker@exoplatform.com](mailto\:docker@exoplatform.com).

---

For further details, refer to the [Nginx documentation](https://nginx.org/en/docs/) and the linked module repositories.