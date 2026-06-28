# sharding-repl-cache — шардирование + репликация + кеш

## Запуск

```shell
docker compose up -d
chmod +x ./scripts/mongo-init.sh
./scripts/mongo-init.sh
```

## Проверка

<http://localhost:8080> → `Sharded`, по 3 реплики на шард, `cache_enabled: true`, всего 1000 документов.

Кеш (второй вызов < 100 мс):

```shell
curl -s -o /dev/null -w "%{time_total}s\n" http://localhost:8080/helloDoc/users
curl -s -o /dev/null -w "%{time_total}s\n" http://localhost:8080/helloDoc/users
```
