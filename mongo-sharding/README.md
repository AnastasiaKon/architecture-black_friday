# mongo-sharding — шардирование MongoDB

## Запуск

```shell
docker compose up -d
chmod +x ./scripts/mongo-init.sh
./scripts/mongo-init.sh
```

## Проверка

<http://localhost:8080> → `mongo_topology_type: "Sharded"`, всего документов 1000. По шардам:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
docker compose exec -T shard2 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
```
