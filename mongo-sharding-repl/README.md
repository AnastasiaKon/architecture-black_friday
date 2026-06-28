# mongo-sharding-repl — шардирование + репликация

## Запуск

```shell
docker compose up -d
chmod +x ./scripts/mongo-init.sh
./scripts/mongo-init.sh
```

## Проверка

<http://localhost:8080> → `Sharded`, всего документов 1000, по 3 реплики на шард. Состав реплик:

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' : ' + m.stateStr))"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' : ' + m.stateStr))"
```
