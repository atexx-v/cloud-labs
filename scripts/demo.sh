#!/usr/bin/env bash
# Послідовна демонстрація API для скриншота: ./scripts/demo.sh http://localhost:8000
# Працює і локально, і з адресою балансувальника в AWS.
set -u
URL="${1:?Вкажіть адресу, напр. ./scripts/demo.sh http://localhost:8000}"
URL="${URL%/}"
J='Content-Type: application/json'
S=$(date +%s)
PASS="correct-horse"
ANN="ann$S@example.com"
BOB="bob$S@example.com"

# Тіла запитів збираємо наперед: вкладені лапки всередині $( ) ламають JSON
B_REG_ANN=$(printf '{"email":"%s","name":"Ann","password":"%s"}' "$ANN" "$PASS")
B_REG_BOB=$(printf '{"email":"%s","name":"Bob","password":"%s"}' "$BOB" "$PASS")
B_LOGIN_ANN=$(printf '{"email":"%s","password":"%s"}' "$ANN" "$PASS")
B_LOGIN_BOB=$(printf '{"email":"%s","password":"%s"}' "$BOB" "$PASS")
B_LOGIN_BAD=$(printf '{"email":"%s","password":"wrong-password"}' "$ANN")
B_POST='{"title":"Пост із демо","body":"Токен перевірено сервісом"}'

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
# HTTP-код відповіді: status METHOD PATH [тіло] [токен]
status() {
  local args=(-s -m 15 -o /dev/null -w '%{http_code}' -X "$1" "$URL$2")
  [ -n "${3:-}" ] && args+=(-H "$J" -d "$3")
  [ -n "${4:-}" ] && args+=(-H "Authorization: Bearer $4")
  curl "${args[@]}"
}
token() { curl -s -m 15 -X POST "$URL/auth/login" -H "$J" -d "$1" \
          | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])'; }

step "1. Health check (видно, який екземпляр відповів)"
curl -s -m 15 "$URL/health"; echo

step "2. Створення поста БЕЗ токена -> очікуємо 401"
echo "HTTP $(status POST /posts "$B_POST")"

step "3. Реєстрація двох користувачів -> очікуємо 201"
echo "ann: HTTP $(status POST /auth/register "$B_REG_ANN")"
echo "bob: HTTP $(status POST /auth/register "$B_REG_BOB")"

step "4. Повторна реєстрація того ж email -> очікуємо 409"
echo "HTTP $(status POST /auth/register "$B_REG_ANN")"

step "5. Вхід -> JWT-токен (показано лише початок)"
TA=$(token "$B_LOGIN_ANN"); TB=$(token "$B_LOGIN_BOB")
echo "token ann: ${TA:0:40}..."

step "6. Вхід з невірним паролем -> очікуємо 401"
echo "HTTP $(status POST /auth/login "$B_LOGIN_BAD")"

step "7. Створення поста З токеном -> очікуємо 201 (автор береться з токена)"
RESP=$(curl -s -m 15 -X POST "$URL/posts" -H "$J" -H "Authorization: Bearer $TA" -d "$B_POST")
echo "$RESP"
PID=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')

step "8. Читання списку постів (публічно, без токена) -> 200"
curl -s -m 15 "$URL/posts?limit=3"; echo

step "9. Bob намагається видалити пост Ann -> очікуємо 403"
echo "HTTP $(status DELETE "/posts/$PID" "" "$TB")"

step "10. Ann видаляє власний пост -> очікуємо 204"
echo "HTTP $(status DELETE "/posts/$PID" "" "$TA")"
echo
