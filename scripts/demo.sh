#!/usr/bin/env bash
set -u
URL="${1:?Вкажіть адресу, напр. ./scripts/demo.sh http://localhost:8000}"
URL="${URL%/}"
J='Content-Type: application/json'
S=$(date +%s)
EMAIL="user$S@example.com"
B_USER=$(printf '{"email":"%s","name":"Demo"}' "$EMAIL")

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
status() {
  local args=(-s -m 15 -o /dev/null -w '%{http_code}' -X "$1" "$URL$2")
  [ -n "${3:-}" ] && args+=(-H "$J" -d "$3")
  curl "${args[@]}"
}

step "1. Health check (видно, який екземпляр відповів)"
curl -s -m 15 "$URL/health"; echo

step "2. Створення користувача -> очікуємо 201"
USER=$(curl -s -m 15 -X POST "$URL/users" -H "$J" -d "$B_USER")
echo "$USER"
UID_=$(echo "$USER" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')

step "3. Той самий email ще раз -> очікуємо 409"
echo "HTTP $(status POST /users "$B_USER")"

step "4. Некоректний запит без email -> очікуємо 422"
echo "HTTP $(status POST /users '{"name":"No email"}')"

step "5. Створення поста для існуючого автора -> очікуємо 201"
B_POST=$(printf '{"title":"Пост із демо","body":"Записано в базу","author_id":%s}' "$UID_")
POST=$(curl -s -m 15 -X POST "$URL/posts" -H "$J" -d "$B_POST")
echo "$POST"
PID=$(echo "$POST" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')

step "6. Пост для неіснуючого автора -> очікуємо 404"
echo "HTTP $(status POST /posts '{"title":"x","body":"y","author_id":999999}')"

step "7. Список постів і пост за id -> 200"
curl -s -m 15 "$URL/posts?limit=2"; echo
echo "HTTP $(status GET "/posts/$PID")"

step "8. Видалення поста -> очікуємо 204, потім 404"
echo "HTTP $(status DELETE "/posts/$PID")"
echo "HTTP $(status GET "/posts/$PID")"
echo
