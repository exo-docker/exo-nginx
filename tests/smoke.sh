#!/usr/bin/env bash
# Smoke test for a built image: tests/smoke.sh IMAGE [EXPECTED_NGINX_VERSION]
set -euo pipefail

IMAGE=${1:?usage: smoke.sh IMAGE [NGINX_VERSION]}
EXPECTED=${2:-}
NAME=exo-nginx-smoke-$$
fail() { echo "FAIL: $*" >&2; docker logs "$NAME" 2>&1 | tail -30 >&2 || true; exit 1; }
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -f "${smoke_conf:-}"; }
trap cleanup EXIT

echo "== versions"
ver=$(docker run --rm --entrypoint nginx "$IMAGE" -v 2>&1)
echo "$ver"
[ -z "$EXPECTED" ] || grep -q "/$EXPECTED\b" <<<"$ver" || fail "expected nginx $EXPECTED"
docker run --rm --entrypoint nginx "$IMAGE" -V 2>&1 | grep -q 'built with OpenSSL' || fail "no OpenSSL in nginx -V"
docker run --rm --entrypoint supervisord "$IMAGE" --version >/dev/null || fail "supervisord missing"
docker run --rm --entrypoint dnsmasq "$IMAGE" --version >/dev/null || fail "dnsmasq missing"

echo "== no pip/setuptools or their vendored libraries (Trivy CVEs)"
left=$(docker run --rm --entrypoint sh "$IMAGE" -c \
  'find / -xdev \( -iname "urllib3*" -o -iname "msgpack*" -o -iname "setuptools*" -o -name pip -o -name "pip-*" \) -not -path "/proc/*" -not -path "*/ensurepip/*" 2>/dev/null')
[ -z "$left" ] || fail "unexpected Python tooling in the image: $left"

echo "== every dynamic module loads"
docker run --rm --entrypoint sh "$IMAGE" -c '
  set -e
  conf=/tmp/modules.conf
  # ngx_stream_module must load before the stream_* modules that depend on it
  d=/usr/lib/nginx/modules
  { echo "load_module $d/ngx_stream_module.so;"
    for m in $d/*.so; do [ "$m" = "$d/ngx_stream_module.so" ] || echo "load_module $m;"; done; } > "$conf"
  cat "$conf"
  { cat "$conf"; echo "events {} http { server { listen 8080; } }"; } > /tmp/nginx-all.conf
  nginx -t -c /tmp/nginx-all.conf
' || fail "a dynamic module failed to load"

echo "== serves HTTP under supervisord"
# The image ships no server block; give the test one without baking it into the image.
smoke_conf=$(mktemp)
echo 'server { listen 80 default_server; location / { return 204; } }' > "$smoke_conf"
chmod 644 "$smoke_conf"
docker run -d --name "$NAME" -p 127.0.0.1:18080:80 \
  -v "$smoke_conf":/etc/nginx/conf.d/smoke.conf:ro "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/ || true)
  [ "$code" != 000 ] && break
  sleep 1
done
[ "$code" != 000 ] || fail "no HTTP response on port 80"
echo "GET / -> $code"
# nginx rewrites its process title, so match the full command line
docker exec "$NAME" pgrep -f 'nginx: master process' >/dev/null || fail "nginx not running"
# dnsmasq is installed but disabled in supervisord.conf, so only its binary is checked (above)
echo "OK"
