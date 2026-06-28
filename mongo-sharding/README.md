# mongo-sharding — шардирование MongoDB

Кластер MongoDB в режиме шардирования: 1 сервер конфигурации, 2 шарда, 1 роутер `mongos` и приложение `pymongo_api`.

| Сервис | Тип | Порт | Replica Set |
|---|---|---|---|
| `configSrv` | config server | 27017 | `config_server` |
| `shard1` | shard | 27018 | `shard1` |
| `shard2` | shard | 27019 | `shard2` |
| `mongos_router` | router (mongos) | 27020 | — |
| `pymongo_api` | приложение | 8080 | — |

## Требования

Docker и Docker Compose, минимум **2 CPU и 4 ГБ ОЗУ**.

## Как запустить

Из этой директории (`mongo-sharding`):

```shell
docker compose up -d
```

Дождитесь старта контейнеров и выполните инициализацию шардирования:

```shell
chmod +x ./scripts/mongo-init.sh   # один раз
./scripts/mongo-init.sh
```

Скрипт сам:
1. дождётся готовности `configSrv`, `shard1`, `shard2`;
2. инициализирует replica set сервера конфигурации и каждого шарда (`rs.initiate`);
3. добавит шарды в кластер (`sh.addShard`), включит шардирование БД `somedb` и коллекции `helloDoc` с хэш-ключом по полю `name`;
4. наполнит коллекцию 1000 документов **через роутер**, чтобы они распределились по шардам;
5. выведет количество документов на каждом шарде.

## Как проверить

Откройте в браузере <http://localhost:8080> — приложение вернёт JSON, где `mongo_topology_type` = `Sharded`, перечислены шарды и общее число документов (`collections.helloDoc.documents_count` = 1000).

Документация API (Swagger): <http://localhost:8080/docs>.

Общее количество документов в базе:

```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов на каждом шарде (в сумме должно дать 1000):

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Статус сервисов:

```shell
docker compose ps
```

## Остановить

```shell
docker compose down        # остановить
docker compose down -v     # остановить и удалить данные (тома)
```

> **Если образы не тянутся из Docker Hub** (актуально для РФ) — добавьте к обоим образам префикс зеркала, например `dh-mirror.gitverse.ru/mongo:latest` и `dh-mirror.gitverse.ru/kazhem/pymongo_api:1.0.0` в `compose.yaml`.
