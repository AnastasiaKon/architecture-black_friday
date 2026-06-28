#!/usr/bin/env bash
#
# Инициализация шардированного кластера MongoDB с репликацией.
# Каждый шард — replica set из 3 узлов.
# Запускать ПОСЛЕ `docker compose up -d` из директории mongo-sharding-repl:
#   ./scripts/mongo-init.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Ждём готовности mongod/mongos (ответ на ping)
wait_ping() {
  local svc=$1 port=$2
  echo "    ждём $svc:$port ..."
  until docker compose exec -T "$svc" mongosh --port "$port" --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; do
    sleep 2
  done
}

# Ждём, пока в replica set будет выбран primary (любой узел)
wait_rs_primary() {
  local svc=$1 port=$2
  echo "    ждём выбор primary в наборе $svc:$port ..."
  until [ -n "$(docker compose exec -T "$svc" mongosh --port "$port" --quiet --eval "print(db.hello().primary || '')" 2>/dev/null | tr -d '\r\n ')" ]; do
    sleep 2
  done
}

echo "==> 1/5 Ожидаем запуск всех инстансов MongoDB"
wait_ping configSrv 27017
for n in shard1-1 shard1-2 shard1-3; do wait_ping "$n" 27018; done
for n in shard2-1 shard2-2 shard2-3; do wait_ping "$n" 27019; done

echo "==> 2/5 Инициализируем config server replica set"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "config_server", configsvr: true, members: [ { _id: 0, host: "configSrv:27017" } ] })
}
EOF

echo "==> 3/5 Инициализируем replica set каждого шарда (по 3 узла)"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "shard1", members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]})
}
EOF
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<'EOF'
try { rs.status() } catch (e) {
  rs.initiate({ _id: "shard2", members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]})
}
EOF

wait_rs_primary configSrv 27017
wait_rs_primary shard1-1 27018
wait_rs_primary shard2-1 27019
wait_ping mongos_router 27020

echo "==> 4/5 Добавляем шарды (replica set'ы) и включаем шардирование somedb.helloDoc"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'EOF'
try { sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018") } catch (e) { print("addShard shard1: " + e) }
try { sh.addShard("shard2/shard2-1:27019,shard2-2:27019,shard2-3:27019") } catch (e) { print("addShard shard2: " + e) }
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
echo "==> Документы по шардам:"
echo -n "shard1 (primary shard1-1): "; docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
echo -n "shard2 (primary shard2-1): "; docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

echo ""
echo "==> Состав replica set'ов (реплики):"
echo "shard1:"; docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.forEach(m => print('  - ' + m.name + ' : ' + m.stateStr))"
echo "shard2:"; docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.forEach(m => print('  - ' + m.name + ' : ' + m.stateStr))"

echo ""
echo "Готово. Приложение: http://localhost:8080 (JSON), документация: http://localhost:8080/docs"
