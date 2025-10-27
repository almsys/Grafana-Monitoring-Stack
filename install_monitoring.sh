#!/bin/bash
CURRENT_IP=`hostname -I | awk '{print $1}'`
GRAFANA_DATA_SOURCE=https://grafana.com/api/dashboards/1860/revisions/37/download

# Проверка на существование директории grafana-docker-stack, если есть удалить
if [ -d "grafana-docker-stack" ]; then
    echo "Удаление директории grafana-docker-stack..."
    rm -rf grafana-docker-stack
    echo "Директория удалена."
else
    echo "Директория grafana-docker-stack не найдена."
fi

# Установка Docker
if ! command -v docker &> /dev/null; then
    echo "Docker не установлен. Устанавливаем..."
    sudo apt update && sudo apt install -y docker.io
else
    echo "Docker уже установлен."
fi

# Инициализация Docker Swarm
if ! docker info | grep -q "Swarm: active"; then
    echo "Инициализация Docker Swarm..."
    docker swarm init || { echo "Ошибка при инициализации Docker Swarm."; exit 1; }
else
    echo "Docker Swarm уже инициализирован."
fi

# Название стека и список томов
STACK_NAME="monitoring"
VOLUMES=("monitoring_grafana-configs" "monitoring_grafana-data" "monitoring_prom-configs" "monitoring_prom-data")

# Проверка наличия стека
if docker stack ls | grep -q "$STACK_NAME"; then
    echo "Стек '$STACK_NAME' найден. Удаляем..."
    docker stack rm "$STACK_NAME"

    # Ждем, пока стек удалится
    echo "Ожидание удаления стека '$STACK_NAME'..."
    while docker stack ls | grep -q "$STACK_NAME"; do
        sleep 2
    done
    echo "Стек '$STACK_NAME' успешно удален."
else
    echo "Стек '$STACK_NAME' не найден."
fi

# Проверка и удаление томов
sleep 10
for volume in "${VOLUMES[@]}"; do
    if docker volume ls | grep -q "$volume"; then
        echo "Том '$volume' найден. Удаляем..."
        docker volume rm "$volume"
        echo "Том '$volume' успешно удален."
    else
        echo "Том '$volume' не найден."
    fi
done

# Проверка наличия git
if ! command -v git &> /dev/null; then
    echo "git не установлен. Устанавливаем..."
    sudo apt update && sudo apt install -y git
fi

# Клонирование репозитория
REPO_URL="https://git.digitalstudium.com/digitalstudium/grafana-docker-stack.git"
if [ ! -d "grafana-docker-stack" ]; then
    echo "Клонирование репозитория из $REPO_URL..."
    git clone "$REPO_URL" || { echo "Ошибка при клонировании репозитория."; exit 1; }
else
    echo "Репозиторий уже клонирован."
fi

# Развертывание стека
if [ -f "grafana-docker-stack/docker-compose.yml" ]; then
    echo "Разворачиваем стек 'monitoring'..."
    docker stack deploy -c grafana-docker-stack/docker-compose.yml monitoring || { echo "Ошибка при развертывании стека."; exit 1; }
else
    echo "Файл docker-compose.yml не найден."
    exit 1
fi

echo "Стек 'monitoring' успешно развернут."
sleep 20
#Change password for Grafana
# Замените <current_ip> на IP-адрес вашей машины
export GRAFANA_URL="http://$CURRENT_IP:3000"
export GRAFANA_USER="admin"
export GRAFANA_OLD_PASSWORD="admin"
export GRAFANA_NEW_PASSWORD="MyPassword1"

while `timeout 1 bash -c "cat < /dev/null > /dev/tcp/localhost/3000"`; do
        sleep 15
done

echo # 1. Получаем cookie для текущей сессии с начальными данными (admin:admin)
sleep 2
ping -c 5 $CURRENT_IP
curl -X POST "$GRAFANA_URL/login" \
     -H "Content-Type: application/json" \
     -d "{\"user\":\"$GRAFANA_USER\", \"password\":\"$GRAFANA_OLD_PASSWORD\"}" \
     -c grafana_cookies.txt

echo # 2. Отправляем запрос на смену пароля
sleep 2
curl -X PUT "$GRAFANA_URL/api/user/password" \
     -H "Content-Type: application/json" \
     -b grafana_cookies.txt \
     -d "{\"oldPassword\":\"$GRAFANA_OLD_PASSWORD\", \"newPassword\":\"$GRAFANA_NEW_PASSWORD\", \"confirmNew\":\"$GRAFANA_NEW_PASSWORD\"}"

echo # 3. Отправляем POST-запрос для создания источника данных
sleep 2
curl -X POST "$GRAFANA_URL/api/datasources" \
     -H "Content-Type: application/json" \
     -u "$GRAFANA_USER:$GRAFANA_NEW_PASSWORD" \
     -d '{
           "name": "Prometheus",
           "type": "prometheus",
           "url": "http://prometheus:9090",
           "access": "proxy",
           "basicAuth": false
         }'

echo # 4. Download and load Grafana Data Source for Prometeus
sleep 2
curl https://grafana.com/api/dashboards/1860 | jq '.json' > dashboard-1860.json
( echo '{ "overwrite": true, "dashboard" :'; \
    cat dashboard-1860.json; \
    echo '}' ) \
    | jq \
    > dashboard-1860-modified.json

curl -X POST "$GRAFANA_URL/api/dashboards/db" \
     -H "Content-Type: application/json" \
     -u "$GRAFANA_USER:$GRAFANA_NEW_PASSWORD" \
     -d @dashboard-1860-modified.json

echo # Добавление Node Exporter в конфигурацию Prometheus
echo "Добавление Node Exporter в конфигурацию Prometheus..."
PROMETHEUS_CONFIG="/var/lib/docker/volumes/monitoring_prom-configs/_data/prometheus.yml"
echo "
  - job_name: \"node-exporter\"
    static_configs:
      - targets: [\"node-exporter:9100\"]
" >> $PROMETHEUS_CONFIG

echo # Перезагрузка конфигурации Prometheus
echo "Перезагрузка конфигурации Prometheus..."
PROMETHEUS_CONTAINER=$(docker ps -q -f "name=monitoring_prometheus")
docker kill -s SIGHUP $PROMETHEUS_CONTAINER

echo "Установка завершена! Доступ к Grafana: http://$CURRENT_IP:3000/login"
echo "Логин: admin, Пароль: MyPassword1"
echo "Не забудьте изменить пароль при первом входе."
