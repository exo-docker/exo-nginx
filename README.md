# eXo Nginx container

The repository is a build of Nginx with Google Page Speed module activated and Nginx sticky module.

## Usage

This image can be use in the same way the official [nginx image](https://hub.docker.com/_/nginx/)

## List of activated modules :

* [nginx-sticky-module-ng](https://github.com/Refinitiv/nginx-sticky-module-ng.git)
* http_ssl_module
* ngx_headers_more
* http_addition_module
* http_auth_request_module
* http_gunzip_module
* http_gzip_static_module
* http_realip_module
* http_stub_status_module
* http_v2_module
* [nginx-auth-ldap](https://github.com/kvspb/nginx-auth-ldap.git)
* stream 
* stream_ssl_module
