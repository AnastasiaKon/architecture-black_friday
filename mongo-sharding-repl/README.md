# mongo-sharding-repl — шардирование + репликация MongoDB

Шардированный кластер MongoDB, где **каждый шард — это replica set из трёх узлов** (повышение отказоустойчивости). Поверх решения из `mongo-sharding`.

| Сервис | Тип | Порт | Replica Set |
|---|---|---|---|
| `configSrv` | config server | 27017 | `config_server` |
| `shard1-1`, `shard1-2`, `shard1-3` | shard | 27018 | `shard1` |
| `shard2-1`, `shard2-2`, `shard2-3` | shard | 27019 | `shard2` |
| `mongos_router` | router (mongos) | 27020 | — |
| `pymongo_api` | приложение | 8080 | — |

Итого 6 узлов-шардов (2 шарда × 3 реплики), сервер конфигурации, роутер и приложение.

## Требования

Docker и Docker Compose, минимум **2 CPU и 4 ГБ ОЗУ**. Для каждого mongod ограничен кеш WiredTiger (`--wiredTigerCacheSizeGB 0.25`), чтобы 9 контейнеров уместились в 4 ГБ.

## Как запустить

Из этой директории (`mongo-sharding-repl`):

```shell
docker compose up -d
```

Дождитесь старта контейнеров и выполните инициализацию:

```shell
chmod +x ./scripts/mongo-init.sh   # один раз
./scripts/mongo-init.sh
```

Скрипт:
1. дождётся готовности сервера конфигурации и всех шести узлов шардов;
2. инициализирует replica set сервера конфигурации;
3. инициализирует replica set каждого шарда из **трёх узлов** (`rs.initiate` с тремя members);
4. дождётся выбора primary, добавит оба шарда в кластер (`sh.addShard` со списком всех реплик), включит шардирование `somedb.helloDoc` по хэшу поля `name`;
5. наполнит коллекцию 1000 документов через роутер;
6. выведет количество документов по шардам и **состав replica set'ов** (список реплик и их роли PRIMARY/SECONDARY).

## Как проверить

Откройте <http://localhost:8080> — приложение вернёт JSON. В поле `shards` хост-строки шардов будут содержать все три реплики каждого набора, например `shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018`. Документация API: <http://localhost:8080/docs>.

Общее количество документов:

```shell
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Количество документов на каждом шарде (сумма = 1000):

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Состав реплик каждого шарда (должно быть по 3 узла: 1 PRIMARY + 2 SECONDARY):

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " : " + m.stateStr))
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.status().members.forEach(m => print(m.name + " : " + m.stateStr))
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

> **Если образы не тянутся из Docker Hub** (актуально для РФ) — добавьте к образам префикс зеркала, например `dh-mirror.gitverse.ru/mongo:latest` и `dh-mirror.gitverse.ru/kazhem/pymongo_api:1.0.0`.
