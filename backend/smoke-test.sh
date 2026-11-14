#!/usr/bin/env bash
set -euo pipefail
base=http://localhost:8080/api
json() { local user=$1 method=$2 path=$3 body=$4; curl -fsS -u "$user:demo123" -X "$method" -H 'Content-Type: application/json' -d "$body" "$base$path" > /dev/null; }
json initiator POST /requests '{"subject":"Учебная закупка","description":"Демонстрация","amount":10000,"dueDate":"2030-01-01"}'
json initiator POST /requests/1/submit '{}'
json manager POST /requests/1/approve '{}'
json buyer POST /procedures '{"requestId":1,"title":"Учебная процедура","conditions":"Условия","deadline":"2030-01-01"}'
json supplier1 POST /offers '{"procedureId":1,"price":9000,"terms":"Условия поставки"}'
json buyer POST /offers/1/clarify '{"comment":"Уточните срок"}'
json supplier1 POST /offers/1/respond '{"price":9000,"terms":"Срок — 10 дней"}'
json buyer POST /offers/1/submit '{}'
json manager POST /offers/1/approve '{}'
json buyer POST /procedures/1/result '{"outcome":"WINNER","offerId":1}'
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
