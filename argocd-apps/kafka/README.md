# Kafka (ArgoCD Application)

Конфигурация для развертывания Apache Kafka через ArgoCD на k3s. Используется Helm chart Bitnami Kafka. Доступ по сети — через NodePort (порт 30092).

## Быстрый старт

1. **StorageClass** (если ещё нет): в кластере должен быть `local-path` или другой StorageClass по умолчанию.

2. **Применить Application:**
   ```bash
   kubectl apply -f argocd-apps/kafka/application.yaml
   ```

3. **Дождаться готовности (2–5 минут):**
   ```bash
   kubectl get pods -n kafka -w
   # Пода kafka-0 в состоянии Running
   ```

4. **Подключение по сети:**
   - **Внутри кластера (из подов):** `kafka.kafka.svc.cluster.local:9092`
   - **Снаружи (с хоста/сети):** `<IP-ноды-k3s>:30092`

   Учётные данные SASL (по умолчанию):
   - Пользователь: `kafka`
   - Пароль: `kafka-secret`

## Примеры подключения

### Внутри кластера (bootstrap)

```
bootstrap.servers=kafka.kafka.svc.cluster.local:9092
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka" password="kafka-secret";
```

### Снаружи (NodePort)

Замените `<NODE_IP>` на IP ноды k3s (или localhost, если подключаетесь с той же машины):

```
bootstrap.servers=<NODE_IP>:30092
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka" password="kafka-secret";
```

### kafka-console-producer / consumer (внутри кластера)

```bash
kubectl run -it --rm kafka-client --image=bitnami/kafka:latest -n kafka -- \
  kafka-console-producer.sh \
  --bootstrap-server kafka.kafka.svc.cluster.local:9092 \
  --topic test \
  --producer-property security.protocol=SASL_PLAINTEXT \
  --producer-property sasl.mechanism=PLAIN \
  --producer-property sasl.jaas.config='org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka" password="kafka-secret";'
```

## Конфигурация (application.yaml)

| Параметр | Значение | Описание |
|----------|----------|----------|
| Namespace | `kafka` | Создаётся автоматически |
| Controller | 1 реплика (controller+broker) | Один узел KRaft для dev/test |
| StorageClass | `local-path` | Том 8Gi для данных |
| NodePort (client) | 30092 | Доступ снаружи по `<node-ip>:30092` |
| SASL user | `kafka` | Логин для клиентов |
| SASL password | `kafka-secret` | Пароль (в production сменить) |

## Зависимости

- ArgoCD установлен в кластере
- StorageClass (например, `local-path`) для PVC
- Доступ к Helm-репозиторию: `https://charts.bitnami.com/bitnami`

## Устранение неполадок

- **Под в Pending:** проверьте `kubectl get pvc -n kafka` и наличие StorageClass.
- **Не подключается снаружи:** убедитесь, что фаервол разрешает порт 30092 на ноде; проверьте `kubectl get svc -n kafka` — у сервиса должен быть NodePort 30092.
- **SASL ошибка:** используйте логин `kafka` и пароль `kafka-secret` (как в values в application.yaml).

## Production

Для production рекомендуется:

- Увеличить реплики (controller/broker), использовать отдельные broker-узлы
- Сменить пароль SASL и вынести его в Secret
- Включить TLS (listeners SSL/SASL_SSL)
- Настроить retention, мониторинг и бэкапы
