# Задача: добавить data-payload в push-уведомления о новых сообщениях чата

## Сервер
`http://144.31.189.154:8080` (NestJS + TypeORM + PostgreSQL, тот же backend что и в `backend_nutrition_fix_prompt.md`)

## Контекст

Android-приложение (Flutter) теперь умеет обрабатывать тап по push-уведомлению и
переходить на нужный экран:
- если уведомление получил **тренер** — открывается дашборд клиента, который
  написал сообщение;
- если уведомление получил **клиент** — открывается его дашборд занятий.

Для этого клиенту нужно, чтобы push-уведомление о новом сообщении чата содержало
**data-payload** с `senderId` — id пользователя, который отправил сообщение.
Сейчас (предположительно) отправляется только `notification.title/body`, без `data`.

## Что нужно сделать

Найти место в коде backend, где отправляется FCM push при создании нового сообщения
(вероятно рядом с обработчиком `POST /conversations/:id/messages`, использует
`firebase-admin` — `admin.messaging().send(...)` или `sendMulticast`/`sendEachForMulticast`).

Добавить в payload push-уведомления объект `data` с полем `senderId`:

```json
{
  "token": "<fcm_token_получателя>",
  "notification": {
    "title": "Иван Иванов",
    "body": "Текст сообщения"
  },
  "data": {
    "senderId": "1933b8e4-284f-45bf-848b-fc4ce70cab36"
  }
}
```

### Важно

- `senderId` — это **id автора сообщения** (того, кто написал), а не id получателя.
- Все значения внутри `data` у FCM обязаны быть **строками** (`string`), даже если
  в БД id хранится как UUID/number — привести через `.toString()` / `String(...)`.
- `data`-only поля не должны конфликтовать с зарезервированными ключами FCM
  (`from`, `message_type`, `collapse_key` и т.п.) — `senderId` безопасен.
- Поле `notification` менять не нужно — оно уже работает и используется для
  отображения текста уведомления.

### Пример (NestJS + firebase-admin)

```typescript
// где-то в chat/notifications сервисе, при создании сообщения
await this.firebaseAdmin.messaging().send({
  token: recipientFcmToken,
  notification: {
    title: senderFullName,
    body: message.text,
  },
  data: {
    senderId: message.senderId.toString(),
  },
});
```

Если рассылка идёт через `sendEachForMulticast` / `sendMulticast` на несколько
токенов — поле `data` добавляется на уровне всего запроса точно так же (оно общее
для всех токенов в батче).

## Как проверить

1. Отправить сообщение от клиента тренеру (или наоборот) через `/conversations/:id/messages`.
2. В логах/через Firebase Console → Cloud Messaging убедиться, что в отправленном
   payload есть `data.senderId`.
3. На Android-стороне: получить push, тапнуть по нему — должен открыться дашборд
   отправителя (для тренера) или дашборд занятий (для клиента). Если переход не
   происходит — значит `data.senderId` не пришёл или пустой.

## Затронутые эндпоинты/файлы (предположительно, нужно найти в коде backend)

- Обработчик `POST /conversations/:id/messages` (создание сообщения)
- Сервис отправки push-уведомлений (использует `firebase-admin`)
- Возможно отдельный `NotificationsService` / `PushService`, куда стоит добавить
  параметр `senderId` при вызове метода отправки push из чат-модуля
