# Настройка мониторинга за 15 минут с помощью Grafana и Prometheus

После настройки получим dashboard с визуализацией метрик системы.

<img width="1039" height="470" alt="image" src="https://github.com/user-attachments/assets/bf2a54d4-9bff-4324-92e6-3a518c0d9f9d" />

## Клонирование репозитория

Клонируем репозиторий c yaml файлами для Docker:

```bash
user@Ubuntu:~$ git clone https://git.digitalstudium.com/digitalstudium/grafana-docker-stack.git
```

После чего у нас появится директория `grafana-docker-stack`:

```bash
user@Ubuntu:~$ ls -lha grafana-docker-stack/
total 60K
drwxrwxr-x  3 user user 4.0K Nov  1 17:27 .
drwxr-x--- 15 user user 4.0K Nov  1 17:27 ..
-rw-rw-r--  1 user user  893 Nov  1 17:27 docker-compose.yml
drwxrwxr-x  8 user user 4.0K Nov  1 17:27 .git
-rw-rw-r--  1 user user  35K Nov  1 17:27 LICENSE
-rw-rw-r--  1 user user  490 Nov  1 17:27 node-exporter.yml
-rw-rw-r--  1 user user 1.5K Nov  1 17:27 README.md
```

## Установка Docker

```bash
user@Ubuntu:~$ sudo apt update && apt install docker.io
```

## Обзор архитектуры

Файл `grafana-docker-stack/docker-compose.yml` содержит описание 3 контейнеров:

1. **Grafana** — визуализатор метрик, то что мы видим в браузере
2. **Prometheus** — база данных, в которой хранятся метрики
3. **Node Exporter** — контейнер, который собирает метрики с сервера Linux и отдает их на порту 9100

### Схема работы

Prometheus забирает метрики с Node Exporter → Grafana забирает метрики с Prometheus и показывает в веб-браузере

## Развертывание стека

Инициализируем Docker Swarm:

```bash
user@Ubuntu:~$ docker swarm init
Swarm initialized: current node (cobxqmqw03094szllzs2b1n4u) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-0qx610as4yehz8hpii5kikpmoek2couseeedsspbp6465d24qq-1p7iy4qn1s54urjpke6sm0m7m 10.0.10.200:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

Развертываем стек мониторинга:

```bash
user@Ubuntu:~$ docker stack deploy -c grafana-docker-stack/docker-compose.yml monitoring
Since --detach=false was not specified, tasks will be created in the background.
In a future release, --detach=false will become the default.
Creating network monitoring_default
Creating service monitoring_grafana
Creating service monitoring_prometheus
Creating service monitoring_node-exporter
```

## Конфигурация docker-compose.yml

### Порты

У каждого контейнера есть раздел `ports`:
- Справа от двоеточия — порт самого контейнера
- Слева от двоеточия — порт, который будет слушать ваш хост

**Пример:** Чтобы зайти в Grafana по порту 80 вместо 3000, измените:
```yaml
ports:
  - "3000:3000"
```
на:
```yaml
ports:
  - "80:3000"
```

### Volumes (Хранилища)

При перезагрузке Docker контейнера все данные теряются, поэтому важные директории объявляются как volumes.

**Для Grafana:**
```yaml
volumes:
  - grafana-data:/var/lib/grafana
  - grafana-configs:/etc/grafana
```

**Для Prometheus:**
```yaml
volumes:
  - prom-data:/prometheus
  - prom-configs:/etc/prometheus
```

## Проверка запущенных контейнеров

```bash
user@Ubuntu:~/grafana-docker-stack$ docker ps
CONTAINER ID   IMAGE                          COMMAND                  CREATED          STATUS          PORTS      NAMES
6424100f7a34   prom/prometheus:v2.36.0        "/bin/prometheus --c…"   24 minutes ago   Up 24 minutes   9090/tcp   monitoring_prometheus.1.zoi2gbq0r5dvczmfqm6jjox2n
81cf31c7276d   prom/node-exporter:v1.3.1      "/bin/node_exporter …"   24 minutes ago   Up 24 minutes   9100/tcp   monitoring_node-exporter.1.jtn0gskpcujmhmx5gt90gbfzf
4c04af3ab032   grafana/grafana:8.5.3-ubuntu   "/run.sh"                24 minutes ago   Up 24 minutes   3000/tcp   monitoring_grafana.1.iiyzc52tcxms4y1bz9raamp1i
```

Должны быть запущены 3 контейнера:
- Grafana
- Prometheus
- Node Exporter

## Настройка Grafana

### Первый вход

1. Откройте в браузере: `http://10.0.10.200:3000/login`
2. Логин/пароль по умолчанию: **admin/admin**
3. При первом входе смените пароль

### Добавление источника данных

1. Перейдите: **Data Sources → Prometheus**
2. URL: `http://prometheus:9090`
3. Нажмите **Save and Test**
4. Должна появиться надпись: **Data source is working**

### Проверка работоспособности

- **Prometheus:** `http://10.0.10.200:9090/`
- **Node Exporter:** `http://10.0.10.200:9100/`

## Импорт Dashboard

1. Скачайте файл JSON для Node Exporter dashboard:  
   [https://grafana.com/api/dashboards/1860/revisions/37/download](https://grafana.com/api/dashboards/1860/revisions/37/download)

2. В Grafana: **4 квадратика → Browse (Manage) → Upload JSON → Load**

3. Выберите **Prometheus** в качестве источника данных

4. Нажмите **Import**

## Настройка Prometheus

На этом этапе dashboard будет пустым, так как нужно добавить Node Exporter в конфигурацию Prometheus.

Откройте файл конфигурации:

```bash
root@Ubuntu:/home/user/grafana-docker-stack# vim /var/lib/docker/volumes/monitoring_prom-configs/_data/prometheus.yml
```

Добавьте следующие строки:

```yaml
  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]
```

### Перезагрузка конфигурации Prometheus

Отправьте сигнал SIGHUP контейнеру Prometheus:

```bash
root@Ubuntu:/home/user/grafana-docker-stack# docker ps | grep prometheus
6424100f7a34   prom/prometheus:v2.36.0        "/bin/prometheus --c…"   54 minutes ago   Up 54 minutes   9090/tcp   monitoring_prometheus.1.zoi2gbq0r5dvczmfqm6jjox2n

root@Ubuntu:/home/user/grafana-docker-stack# docker kill -s SIGHUP 6424100f7a34
```

### Проверка

1. Откройте Prometheus: `http://10.0.10.200:9090/`
2. Перейдите: **Status → Targets**
3. Должен появиться **Node Exporter**

Теперь в Grafana должны отображаться данные!

## Удаление стека

Удаление контейнеров:

```bash
user@Ubuntu:~$ docker stack rm monitoring
```

Удаление volumes:

```bash
docker volume ls
docker volume rm monitoring_grafana-configs
docker volume rm monitoring_grafana-data
docker volume rm monitoring_prom-configs
docker volume rm monitoring_prom-data
```

## Обновление версий

Чтобы обновить версии компонентов:

1. Введите в поиске: **docker hub Grafana**
2. Перейдите по первой ссылке
3. Откройте раздел **Tags**
4. Выберите нужную версию (например, 11.03.0)
5. Измените версию в `docker-compose.yml`:

```yaml
image: grafana/grafana:11.03.0
```

вместо:

```yaml
image: grafana/grafana:8.5.3-ubuntu
```
