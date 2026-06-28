#!/usr/bin/env bash
#
# Инициализация шардированного кластера MongoDB.
# Запускать ПОСЛЕ `docker compose up -d` из корня директории mongo-sharding:
#   ./scripts/mongo-init.sh
#
set -euo pipefail

# Перейти в корень проекта (директорию с compose.yaml), где бы ни запустили скрипт
cd "$(dirname "$0")/.."

# Ждём, пока mongod/mongos начнут отвечать на ping
wait_ping() {
  local svc=$1 port=$2
  echo "    ждём $svc:$port ..."
  until docker compose exec -T "$svc" mongosh --port "$port" --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
    sleep 2
  done
}

# Ждём, пока узел станет primary своего replica set
wait_primary() {
  local svc=$1 port=$2
  echo "    ждём primary в $svc:$port ..."
  until [ "$(docker compose exec -T "$svc" mongosh --port "$port" --quiet --eval "db.hello().isWritablePrimary" 2>/dev/null | tr -d '\r')" = "true" ]; do
    sleep 2
  done
}

echo "==> 1/5 Ожидаем запуск инстансов MongoDB"
wait_ping configSrv 27017
wait_ping shard1 27018
wait_ping shard2 27019

echo "==> 2/5 Инициализируем config server replica set"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "config_server", configsvr: true, members: [ { _id: 0, host: "configSrv:27017" } ] })
}
EOF

echo "==> 3/5 Инициализируем replica set каждого шарда"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "shard1", members: [ { _id: 0, host: "shard1:27018" } ] })
}
EOF
docker compose exec -T shard2 mongosh --port 27019 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "shard2", members: [ { _id: 0, host: "shard2:27019" } ] })
}
EOF

# Перед добавлением шардов дожидаемся primary, иначе addShard может упасть
wait_primary configSrv 27017
wait_primary shard1 27018
wait_primary shard2 27019
wait_ping mongos_router 27020

echo "==> 4/5 Добавляем шарды и включаем шардирование коллекции somedb.helloDoc"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
try { sh.addShard("shard1/shard1:27018") } catch (e) { print("addShard shard1: " + e) }
try { sh.addShard("shard2/shard2:27019") } catch (e) { print("addShard shard2: " + e) }
try { sh.enableSharding("somedb") } catch (e) { print("enableSharding: " + e) }
try { sh.shardCollection("somedb.helloDoc", { "name": "hashed" }) } catch (e) { print("shardCollection: " + e) }
EOF

echo "==> 5/5 Наполняем коллекцию 1000 документов (через роутер)"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
use somedb
if (db.helloDoc.countDocuments() < 1000) {
  const docs = []
  for (let i = 0; i < 1000; i++) docs.push({ age: i, name: "ly" + i })
  db.helloDoc.insertMany(docs)
}
print("Всего документов в somedb.helloDoc: " + db.helloDoc.countDocuments())
EOF

echo ""
echo "==> Проверка распределения по шардам:"
echo -n "shard1: "; docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo -n "shard2: "; docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo ""
echo "Готово. Приложение: http://localhost:8080 (JSON), документация: http://localhost:8080/docs"
