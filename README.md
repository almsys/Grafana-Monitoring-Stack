# Grafana Monitoring Stack - Автоматическая установка


Bash-скрипт для автоматического развертывания стека мониторинга на базе Grafana, Prometheus и Node Exporter с использованием Docker Swarm.

Итоговое окно после работы скрипта:

<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/5e322922-315a-467c-9d6a-672d83808cbf" />

Если вы хотите в ручную установить стек мониторинга, используйте инструкцию  grafana-prometheus-guide.md

## Описание

Скрипт автоматизирует полный процесс установки и настройки системы мониторинга:
- Разворачивает Grafana, Prometheus и Node Exporter в Docker Swarm
- Настраивает источники данных
- Загружает готовый дашборд для визуализации метрик
- Изменяет дефолтный пароль администратора

## Требования

- Ubuntu/Debian-based система
- Права root или sudo доступ
- Свободные порты: 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter)

## Что делает скрипт

1. **Очистка предыдущих установок**
   - Удаляет существующую директорию `grafana-docker-stack`
   - Останавливает и удаляет стек `monitoring`
   - Удаляет связанные Docker volumes

2. **Установка зависимостей**
   - Устанавливает git (если отсутствует)
   - Устанавливает Docker (если отсутствует)
   - Инициализирует Docker Swarm

3. **Развертывание стека**
   - Клонирует репозиторий с конфигурациями
   - Разворачивает Docker stack `monitoring`
   - Ожидает запуска всех сервисов

4. **Настройка Grafana**
   - Изменяет пароль администратора (admin:admin → admin:MyPassword1)
   - Добавляет Prometheus как источник данных
   - Импортирует дашборд Node Exporter Full (ID: 1860)

5. **Настройка Prometheus**
   - Добавляет Node Exporter в конфигурацию
   - Перезагружает Prometheus для применения изменений

## Использование

```bash
# Скачайте скрипт
wget https://raw.githubusercontent.com/almsys/grafana-monitoring-stack/main/install_monitoring.sh

# Сделайте его исполняемым
chmod +x install_monitoring.sh

# Запустите установку
sudo ./install_monitoring.sh
```

## После установки

После успешного выполнения скрипта:

**Grafana Web UI:**
- URL: `http://YOUR_IP:3000`
- Логин: `admin`
- Пароль: `MyPassword1`

**Prometheus:**
- URL: `http://YOUR_IP:9090`

**Node Exporter:**
- Метрики: `http://YOUR_IP:9100/metrics`

## Компоненты стека

- **Grafana** - платформа визуализации и аналитики
- **Prometheus** - система мониторинга и база данных временных рядов
- **Node Exporter** - экспортер метрик системы (CPU, память, диск, сеть)

## Дашборды

Автоматически устанавливается дашборд **Node Exporter Full** (ID: 1860), который включает:
- Использование CPU, памяти, диска
- Сетевой трафик
- Системная информация
- И многое другое

## Безопасность

⚠️ **Важно:** После первого входа рекомендуется:
1. Изменить пароль администратора на более сложный
2. Настроить firewall для ограничения доступа к портам
3. Рассмотреть использование HTTPS для Grafana

## Удаление

Для полного удаления стека мониторинга:

```bash
# Остановить и удалить стек
docker stack rm monitoring

# Дождаться завершения удаления (15-30 секунд)
sleep 30

# Удалить volumes
docker volume rm monitoring_grafana-configs
docker volume rm monitoring_grafana-data
docker volume rm monitoring_prom-configs
docker volume rm monitoring_prom-data

# Удалить директорию
rm -rf grafana-docker-stack
```

## Troubleshooting

**Проблема:** Порты уже используются
```bash
# Проверьте, какие процессы используют порты
sudo netstat -tulpn | grep -E '3000|9090|9100'
```

**Проблема:** Docker Swarm не инициализируется
```bash
# Принудительная инициализация
docker swarm init --force-new-cluster
```

**Проблема:** Grafana не открывается
```bash
# Проверьте статус контейнеров
docker stack ps monitoring

# Проверьте логи
docker service logs monitoring_grafana
```

## Источник репозитория

Скрипт использует официальный репозиторий:
- https://git.digitalstudium.com/digitalstudium/grafana-docker-stack.git


## Автор

Адаптировано для автоматической установки системы мониторинга

---

**Примечание:** Скрипт предназначен для быстрого развертывания тестовых и development окружений. Для production использования рекомендуется дополнительная настройка безопасности и резервного копирования.
