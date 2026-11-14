#!/usr/bin/env bash
set -euo pipefail
base=http://localhost:8080/api
json() { local user=$1 method=$2 path=$3 body=$4; curl -fsS -u "$user:demo123" -X "$method" -H 'Content-Type: application/json' -d "$body" "$base$path" > /dev/null; }
json initiator POST /requests '{"subject":"Учебная закупка","description":"Демонстрация","amount":10000,"dueDate":"2030-01-01"}'
json initiator POST /requests/1/submit '{}'
json manager POST /requests/1/approve '{}'
json initiator PUT /requests/1 '{"subject":"Учебная закупка","description":"Исправлена","amount":12000,"dueDate":"2030-01-01"}'
curl -fsS -u initiator:demo123 "$base/requests" | python3 -c 'import json,sys; r=json.load(sys.stdin)[0]; assert r["status"] == "DRAFT" and float(r["amount"]) == 12000'
json initiator POST /requests/1/submit '{}'
json manager POST /requests/1/approve '{}' 
json buyer POST /procedures '{"requestId":1,"title":"Учебная процедура","conditions":"Условия","deadline":"2030-01-01"}'
json supplier1 POST /offers '{"procedureId":1,"price":9000,"terms":"Условия поставки"}'
json supplier1 PUT /offers/1 '{"price":8500,"terms":"Обновлённые условия"}'
json buyer POST /offers/1/clarify '{"comment":"Уточните срок"}'
json supplier1 POST /offers/1/respond '{"price":9000,"terms":"Срок — 10 дней"}'
json buyer POST /offers/1/submit '{}'
json manager POST /offers/1/approve '{}'
json supplier1 PUT /offers/1 '{"price":8000,"terms":"Пересчитанная цена"}'
curl -fsS -u buyer:demo123 "$base/offers" | python3 -c 'import json,sys; o=json.load(sys.stdin)[0]; assert o["status"] == "UNDER_REVIEW" and o["review_state"] is None and float(o["price"]) == 8000'
json buyer POST /offers/1/submit '{}'
json manager POST /offers/1/approve '{}'
json buyer PUT /procedures/1 '{"title":"Учебная процедура","conditions":"Условия","deadline":"2030-02-01"}'
curl -fsS -u buyer:demo123 "$base/offers" | python3 -c 'import json,sys; assert json.load(sys.stdin)[0]["status"] == "ACCEPTED"'
json buyer PUT /procedures/1 '{"title":"Учебная процедура","conditions":"Новые условия","deadline":"2030-02-01"}'
curl -fsS -u buyer:demo123 "$base/offers" | python3 -c 'import json,sys; o=json.load(sys.stdin)[0]; assert o["status"] == "UNDER_REVIEW" and o["review_state"] is None'
json buyer POST /offers/1/submit '{}'
json manager POST /offers/1/approve '{}'
json buyer POST /procedures/1/result '{"outcome":"WINNER","offerId":1}'
code=$(curl -s -o /dev/null -w '%{http_code}' -u supplier1:demo123 -X PUT -H 'Content-Type: application/json' -d '{"price":7000,"terms":"Поздно"}' "$base/offers/1")
test "$code" = 409
code=$(curl -s -o /dev/null -w '%{http_code}' -u initiator:demo123 -X PUT -H 'Content-Type: application/json' -d '{"subject":"X","description":"X","amount":1,"dueDate":"2030-01-01"}' "$base/requests/1")
test "$code" = 409
json contractor POST /contracts '{"resultId":1,"number":"DEMO-1","subject":"Учебный договор","amount":9000,"startDate":"2026-01-01","endDate":"2030-01-01"}'
curl -fsS -u contractor:demo123 -F 'file=@README.md;type=text/plain' "$base/contracts/1/documents" > /dev/null
json contractor POST /contracts/1/submit '{}'
json manager POST /contracts/1/approve '{}'
json contractor POST /contracts/1/edo '{}'
json contractor POST /contracts/1/conclude '{}'
json contractor POST /contracts/1/execution '{"notes":"Исполнен"}'
json contractor POST /contracts/1/close '{}'
curl -fsS -u contractor:demo123 "$base/contracts" | python3 -c 'import json,sys; assert json.load(sys.stdin)[0]["status"] == "CLOSED"'
code=$(curl -s -o /dev/null -w '%{http_code}' -u supplier1:demo123 -X POST -H 'Content-Type: application/json' -d '{}' "$base/requests/1/approve")
test "$code" = 403
printf '%s\n' 'Сквозной сценарий и проверка прав пройдены.'

# CORS for separately hosted clients: preflight must not require credentials.
headers=$(mktemp)
trap 'rm -f "$headers"' EXIT
code=$(curl -s -o /dev/null -D "$headers" -w '%{http_code}' -X OPTIONS "$base/me" -H 'Origin: http://localhost:5173' -H 'Access-Control-Request-Method: GET' -H 'Access-Control-Request-Headers: authorization')
test "$code" = 200
tr -d '\r' < "$headers" | grep -qi '^Access-Control-Allow-Origin: http://localhost:5173$'
tr -d '\r' < "$headers" | grep -qi '^Access-Control-Allow-Headers: .*authorization'
printf '%s\n' 'CORS preflight для разрешённого источника пройден.'
