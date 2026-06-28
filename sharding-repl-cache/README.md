# sharding-repl-cache — шардирование + репликация + кеширование

Финальная реализация: шардированный кластер MongoDB, где каждый шард — replica set из трёх узлов, плюс кеш **Redis** для эндпоинта приложения. Это директория, которую проверяет ревьюер (решения заданий 2, 3 и 4).

| Сервис | Тип | Порт | Replica Set |
|---|---|---|---|
| `configSrv` | config server | 27017 | `config_server` |
| `shard1-1`, `shard1-2`, `shard1-3` | shard | 27018 | `shard1` |
| `shard2-1`, `shard2-2`, `shard2-3` | shard | 27019 | `shard2` |
| `mongos_router` | router (mongos) | 27020 | — |
| `redis` | кеш | 6379 | — |
| `pymongo_api` | приложение | 8080 | — |

Кеширование включается переменной окружения приложения `REDIS_URL: "redis://redis:6379"`.

## Требования

Docker и Docker Compose, минимум **2 CPU и 4 ГБ ОЗУ**.

## Как запустить

Из этой директории (`sharding-repl-cache`):

```shell
docker compose up -d
```

Дождитесь старта контейнеров и выполните инициализацию:

```shell
chmod +x ./scripts/mongo-init.sh   # один раз
./scripts/mongo-init.sh
```

Скрипт инициализирует config server, replica set каждого шарда (по 3 узла), добавит шарды в кластер, включит шардирование `somedb.helloDoc` по хэшу `name`, наполнит коллекцию 1000 документов и выведет раскладку по шардам и состав реплик. Redis отдельной инициализации не требует.

## Как проверить

Откройте <http://localhost:8080> — приложение вернёт JSON с информацией о MongoDB. Поле `cache_enabled` будет `true` (кеш Redis подключён). Документация API: <http://localhost:8080/docs>.

Общее количество документов и раскладка по шардам/репликам — командами из раздела ниже (как в `mongo-sharding-repl`).

### Проверка кеша

Кеширование включено для эндпоинта `/<collection_name>/users`. Первый вызов выполняется ~1 сек (в приложении заложена задержка), а повторные берутся из кеша и выполняются **<100 мс**:

```shell
# первый вызов — медленный (заполняет кеш)
curl -s -o /dev/null -w "1-й запрос: %{time_total}s\n" http://localhost:8080/helloDoc/users
# повторные — из кеша, <0.1s
curl -s -o /dev/null -w "2-й запрос: %{time_total}s\n" http://localhost:8080/helloDoc/users
curl -s -o /dev/null -w "3-й запрос: %{time_total}s\n" http://localhost:8080/helloDoc/users
```

### Документы и реплики

```shell
# всего документов (через роутер)
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# по шардам
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "db.getSiblingDB('somedb').helloDoc.countDocuments()"

# реплики каждого шарда (1 PRIMARY + 2 SECONDARY)
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' : ' + m.stateStr))"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.forEach(m => print(m.name + ' : ' + m.stateStr))"
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

> **Если образы не тянутся из Docker Hub** (актуально для РФ) — добавьте к образам префикс зеркала, например `dh-mirror.gitverse.ru/mongo:latest`, `dh-mirror.gitverse.ru/redis:latest`, `dh-mirror.gitverse.ru/kazhem/pymongo_api:1.0.0`.
