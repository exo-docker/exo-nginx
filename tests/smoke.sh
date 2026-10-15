#!/usr/bin/env bash
# Smoke test for a built image: tests/smoke.sh IMAGE [EXPECTED_NGINX_VERSION]
set -euo pipefail

IMAGE=${1:?usage: smoke.sh IMAGE [NGINX_VERSION]}
EXPECTED=${2:-}
NAME=exo-nginx-smoke-$$
fail() { echo "FAIL: $*" >&2; docker logs "$NAME" 2>&1 | tail -30 >&2 || true; exit 1; }
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== versions"
ver=$(docker run --rm --entrypoint nginx "$IMAGE" -v 2>&1)
echo "$ver"
[ -z "$EXPECTED" ] || grep -q "/$EXPECTED\b" <<<"$ver" || fail "expected nginx $EXPECTED"
docker run --rm --entrypoint nginx "$IMAGE" -V 2>&1 | grep -q 'built with OpenSSL' || fail "no OpenSSL in nginx -V"
docker run --rm --entrypoint supervisord "$IMAGE" --version >/dev/null || fail "supervisord missing"
docker run --rm --entrypoint dnsmasq "$IMAGE" --version >/dev/null || fail "dnsmasq missing"

echo "== every dynamic module loads"
docker run --rm --entrypoint sh "$IMAGE" -c '
  set -e
  conf=/tmp/modules.conf
  for m in /usr/lib/nginx/modules/*.so; do echo "load_module $m;"; done > "$conf"
  cat "$conf"
  { cat "$conf"; echo "events {} http { server { listen 8080; } }"; } > /tmp/nginx-all.conf
  nginx -t -c /tmp/nginx-all.conf
' || fail "a dynamic module failed to load"

echo "== serves HTTP under supervisord"
docker run -d --name "$NAME" -p 127.0.0.1:18080:80 "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/ || true)
  [ "$code" != 000 ] && break
  sleep 1
done
[ "$code" != 000 ] || fail "no HTTP response on port 80"
echo "GET / -> $code"
docker exec "$NAME" pgrep -x nginx >/dev/null || fail "nginx not running"
docker exec "$NAME" pgrep -x dnsmasq >/dev/null || fail "dnsmasq not running"
echo "OK"
