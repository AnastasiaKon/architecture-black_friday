# Проектная работа 4 спринта — масштабирование «Мобильный мир»

Повышение отказоустойчивости и пропускной способности интернет-магазина: **шардирование**, **репликация** и **кеширование** MongoDB, плюс план горизонтального масштабирования приложения (API Gateway + Service Discovery) и CDN.

Приложение — `kazhem/pymongo_api:1.0.0`. База — `somedb`, коллекция — `helloDoc` (1000+ документов).

## Структура репозитория

| Путь | Что внутри |
|---|---|
| [`mongo-sharding/`](./mongo-sharding) | Задание 2 — шардирование (configSrv + 2 шарда + mongos + приложение) |
| [`mongo-sharding-repl/`](./mongo-sharding-repl) | Задание 3 — то же + репликация (каждый шард = replica set из 3 узлов) |
| [`sharding-repl-cache/`](./sharding-repl-cache) | **Задания 2 + 3 + 4 — финальная реализация (её проверяет ревьюер): шардирование + репликация + кеш Redis** |
| [`architecture.drawio`](./architecture.drawio) | Итоговая схема (5 страниц: шардирование → репликация → кеш → API Gateway/Consul → CDN) |

## Требования

Docker и Docker Compose, минимум **2 CPU и 4 ГБ ОЗУ**.

## Запуск финальной реализации

Ревьюеру достаточно директории `sharding-repl-cache`:

```shell
cd sharding-repl-cache
docker compose up -d
chmod +x ./scripts/mongo-init.sh
./scripts/mongo-init.sh
```

Скрипт инициализирует config server, поднимет replica set каждого шарда (по 3 узла), добавит шарды в кластер, включит шардирование `somedb.helloDoc` (хэш по `name`), наполнит коллекцию 1000 документов и выведет раскладку по шардам и состав реплик.

## Что проверить

Откройте <http://localhost:8080> — приложение вернёт JSON с информацией о MongoDB: `mongo_topology_type: "Sharded"`, список `shards` (с репликами каждого набора), `collections.helloDoc.documents_count` и `cache_enabled: true`. Документация API: <http://localhost:8080/docs>.

- Общее число документов ≥ 1000, распределены по двум шардам.
- У каждого шарда 3 реплики (1 PRIMARY + 2 SECONDARY).
- Повторные вызовы `/<collection_name>/users` (например `/helloDoc/users`) выполняются < 100 мс (кеш Redis).
- Статус сервисов: `docker compose ps`.

Подробные команды проверки — в README соответствующих директорий.

## Схема архитектуры

Файл `architecture.drawio` (открывается на <https://app.diagrams.net> или расширением Draw.io Integration в VS Code). Пять страниц показывают эволюцию решения; **итоговая — последняя страница** «5. Итоговая (+ CDN)».

> **Если образы не тянутся из Docker Hub** (актуально для РФ) — добавьте к образам префикс зеркала `dh-mirror.gitverse.ru/` (например `dh-mirror.gitverse.ru/mongo:latest`, `dh-mirror.gitverse.ru/redis:latest`, `dh-mirror.gitverse.ru/kazhem/pymongo_api:1.0.0`).
