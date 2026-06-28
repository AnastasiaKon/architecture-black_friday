# Проектная работа 4 спринта — масштабирование «Мобильный мир»

Шардирование, репликация и кеширование MongoDB для интернет-магазина. Приложение — образ `kazhem/pymongo_api:1.0.0`, БД `somedb`, коллекция `helloDoc`. Финальная реализация — в директории `sharding-repl-cache`.

## Запуск

Нужен Docker (2 CPU / 4 ГБ).

```shell
cd sharding-repl-cache
docker compose up -d
chmod +x ./scripts/mongo-init.sh
./scripts/mongo-init.sh
```

## Проверка

<http://localhost:8080> → JSON: `mongo_topology_type: "Sharded"`, список шардов с репликами (по 3 на шард), `cache_enabled: true`, всего документов 1000. Статус сервисов: `docker compose ps`.
