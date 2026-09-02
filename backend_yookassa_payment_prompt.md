# Задача: приём оплаты подписки через ЮKassa

## Сервер
`http://144.31.189.154:8080` (NestJS + Prisma + PostgreSQL, тот же backend, что и в
остальных `backend_*_prompt.md`)

## Контекст

В `backend_subscription_pricing_prompt.md` уже реализовано (см. `src/subscription/`):
- `SubscriptionTariff` — цена за роль, `SubscriptionPayment` — платежи (`userId, role,
  fullPriceRub, chargedRub, isFirstMonth, status, createdAt`, индекс `[userId, status]`).
- `GET /api/subscription/price` — считает `chargedRub` для текущего пользователя
  (скидка 50% на первый месяц), **ничего не пишет в БД**.
- Сам приём оплаты через ЮKassa был сознательно исключён из той задачи — это она
  и есть.

Flutter-сторона уже реализована (в этой сессии) под контракт ниже — реализовать
нужно 1:1, не меняя. Общая идея — переиспользовать тот же паттерн, что уже
работает для OAuth-логина (`backend_oauth_login_prompt.md`): клиент открывает
системный браузер/webview на URL, который в итоге редиректит на `return_url`,
и по custom URL scheme `trainerapp` (уже зарегистрирован в Android/iOS) управление
возвращается в приложение. Но в отличие от OAuth, где результат берётся из
query-параметров редиректа, здесь редирект — только UX-удобство (закрыть окно
оплаты); источник истины всегда — поллинг статуса на бэкенде, который сам
подтверждается через вебхук ЮKassa, а не через то, что видит браузер.

Flutter-сторона (для справки, ничего здесь менять не нужно):
- `lib/core/services/api_service.dart`:
  - `createSubscriptionPayment(String platform)` → `POST /subscription/pay` с телом
    `{ "platform": "web" | "mobile" }` → ожидает `{ paymentId, confirmationUrl }`.
  - `getSubscriptionPaymentStatus(String paymentId)` → `GET
    /subscription/payment/:id/status` → ожидает `{ "status": "pending" | "succeeded"
    | "failed" | "canceled" }`.
- `lib/features/subscription/subscription_screen.dart`:
  - На мобильных — открывает `confirmationUrl` через `FlutterWebAuth2.authenticate(url:
    confirmationUrl, callbackUrlScheme: 'trainerapp')`, то есть `return_url` для
    `platform == 'mobile'` должен быть на схеме `trainerapp://...` (путь неважен,
    `flutter_web_auth_2` матчит только scheme).
  - На вебе — открывает `confirmationUrl` в новой вкладке (`url_launcher`), поэтому
    `return_url` для `platform == 'web'` должен быть обычным `https://`-адресом
    веб-приложения (например `https://trainer-app-2026.web.app`) — экран в новой
    вкладке пользователю уже не важен, т.к. поллинг идёт из исходной вкладки.
  - Сразу после открытия окна оплаты (независимо от того, как оно закрылось) —
    поллинг `GET /subscription/payment/:id/status` каждые 2 сек. до `succeeded`
    /`failed`/`canceled` или таймаута (~60 сек).

## ⚠️ Обязательное условие: HTTPS для вебхука

ЮKassa **не отправляет уведомления (webhook) на `http://`-адрес** — в кабинете
магазина URL для HTTP-уведомлений принимается только с `https://` и валидным
сертификатом. Сейчас бэкенд слушает на голом `http://144.31.189.154:8080`, без
домена и TLS. Прежде чем вебхук заработает, нужен реверс-прокси с сертификатом
(nginx + Let's Encrypt/Certbot, либо Cloudflare Tunnel и т.п.) перед портом 8080,
и в кабинете ЮKassa должен быть указан `https://<домен>/api/subscription/yookassa-webhook`.
Сама реализация ниже не блокируется отсутствием домена (можно разрабатывать и
гонять сценарий 3 из раздела «Как проверить» вручную через curl), но **в проде
без HTTPS вебхук просто не будет вызываться**, и платежи будут зависать в
`pending` до тех пор, пока их не подтвердят вручную.

## 1. Переменные окружения

`.env.example`, добавить:
```
YOOKASSA_SHOP_ID="000000"
YOOKASSA_SECRET_KEY="test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
YOOKASSA_RETURN_URL_MOBILE="trainerapp://payment-callback"
YOOKASSA_RETURN_URL_WEB="https://trainer-app-2026.web.app"
```
На старте (тестовый режим магазина в ЮKassa) — `YOOKASSA_SHOP_ID`/`YOOKASSA_SECRET_KEY`
берутся из тестовых ключей кабинета, при переходе в прод — заменяются на боевые
(см. раздел «Что сделать в кабинете ЮKassa» в чате с пользователем, сюда не относится).

## 2. Prisma — расширить `SubscriptionPayment`

Нужно поле для ID платежа в самой ЮKassa (чтобы находить нашу запись по
уведомлению от них):

```prisma
model SubscriptionPayment {
  id               String   @id @default(uuid())
  userId           String
  role             String
  fullPriceRub     Int
  chargedRub       Int
  isFirstMonth     Boolean
  status           String   // "pending" | "succeeded" | "failed" | "canceled"
  yookassaPaymentId String? @unique
  createdAt        DateTime @default(now())

  @@index([userId, status])
}
```

Миграция — только добавление колонки `yookassaPaymentId`, остальное без
изменений.

## 3. `POST /api/subscription/pay`

JWT-защищён (как `GET /subscription/price`). Тело: `{ "platform": "web" | "mobile" }`.

### Логика
1. Посчитать `fullPriceRub` / `chargedRub` / `isFirstMonth` для роли пользователя —
   переиспользовать существующую логику `SubscriptionService.getPriceForUser`
   (тот же расчёт, что и в `GET /price`, не дублировать).
2. Создать `SubscriptionPayment` со `status: "pending"` (без `yookassaPaymentId`
   пока).
3. Вызвать ЮKassa API:
   ```
   POST https://api.yookassa.ru/v3/payments
   Idempotence-Key: <новый uuid v4 на каждый вызов>
   Authorization: Basic base64(YOOKASSA_SHOP_ID:YOOKASSA_SECRET_KEY)
   Content-Type: application/json

   {
     "amount": { "value": "<chargedRub>.00", "currency": "RUB" },
     "capture": true,
     "confirmation": {
       "type": "redirect",
       "return_url": "<YOOKASSA_RETURN_URL_MOBILE или _WEB, по platform>"
     },
     "description": "Подписка <role>",
     "metadata": { "subscriptionPaymentId": "<id из шага 2>" }
   }
   ```
4. Записать `yookassaPaymentId = <id из ответа ЮKassa>` в созданную строку.
5. Если вызов ЮKassa упал — пометить строку `status: "failed"` и вернуть 502 с
   понятным сообщением, платёж не считается созданным для клиента.
6. Ответ клиенту: `{ "paymentId": "<id из шага 2>", "confirmationUrl":
   "<response.confirmation.confirmation_url>" }`.

`platform`, отличный от `"web"`/`"mobile"` — `400`.

## 4. `GET /api/subscription/payment/:id/status`

JWT-защищён. Найти `SubscriptionPayment` по `id`; если не найден или
`userId` не совпадает с текущим пользователем — `404`. Ответ: `{ "status":
"<status строки>" }`.

## 5. `POST /api/subscription/yookassa-webhook`

**Публичный эндпоинт, без JWT** (его дёргает сама ЮKassa). Формат уведомления:
```json
{ "event": "payment.succeeded", "object": { "id": "2d3...", "status": "succeeded", ... } }
```

### Логика
1. **Не доверять статусу из тела запроса напрямую** — ЮKassa v3 API не подписывает
   вебхуки по умолчанию, поэтому по `object.id` нужно перезапросить платёж у самой
   ЮKassa: `GET https://api.yookassa.ru/v3/payments/{object.id}` (тот же Basic auth),
   и использовать `status` из этого ответа как источник истины.
2. Найти `SubscriptionPayment` по `yookassaPaymentId == object.id`. Не найдено —
   вернуть `200` и ничего не делать (может быть уведомление не по нашей записи).
3. Смапить статус ЮKassa → наш: `succeeded` → `succeeded`, `canceled` → `canceled`,
   иначе — не менять (`pending`).
4. Обновление должно быть идемпотентным — ЮKassa может прислать одно и то же
   уведомление повторно.
5. Всегда отвечать `200` быстро, кроме реальных временных сбоев (БД недоступна) —
   на них можно вернуть `5xx`, тогда ЮKassa повторит доставку позже.
6. (Опционально, но желательно) — ограничить приём вебхука IP-диапазонами ЮKassa
   из их документации («Уведомления» → «IP-адреса»), доп. слой защиты поверх
   перезапроса в п.1.

## Важно — что НЕ входит в эту задачу

`succeeded`-платёж сейчас **не выдаёт пользователю никакого доступа** — он просто
меняет статус строки `SubscriptionPayment` (и тем самым влияет на будущий расчёт
`isFirstMonth` в `GET /price`). Реальная активация/продление доступа (что именно
должно произойти — продлить `TrainerSettings.plan`, завести отдельное поле
`subscriptionActiveUntil` на пользователе, или что-то ещё) — сознательно отдельная
задача: `TrainerSettings.plan` (`FREE/BASIC/PRO/UNLIMITED`) сейчас — это лимит AI-
токенов, отдельная от роли ось, и решение, как оплаченная подписка должна на неё
влиять для каждой из ролей SOLO/CLIENT/TRAINER/TRAINER_CLIENT, требует отдельного
продуктового решения, не техническое расширение по аналогии.

## Как проверить

1. `POST /api/subscription/pay` с `{"platform": "web"}` под JWT — `200`,
   `confirmationUrl` открывается и ведёт на страницу оплаты ЮKassa (тестовый
   магазин), `paymentId` — валидный uuid.
2. Оплатить тестовой картой ЮKassa (см. тестовые карты в кабинете, режим
   тестирования магазина) → дождаться вебхука (или подёргать
   `GET /api/subscription/payment/:id/status` вручную, пока `succeeded`).
3. Без реального вебхука (нет HTTPS/домена ещё) — эмулировать вручную:
   `curl -X POST http://144.31.189.154:8080/api/subscription/yookassa-webhook
   -d '{"event":"payment.succeeded","object":{"id":"<yookassaPaymentId из шага 1>"}}'`
   — сервис должен сходить в ЮKassa API за реальным статусом (тестовый платёж уже
   оплачен) и проставить `succeeded`.
4. Повторный вызов `GET /api/subscription/price` для того же пользователя после
   `succeeded` — `isFirstMonth: false`.
5. `POST /pay` с некорректным `platform` — `400`. Запрос без JWT — `401`.
6. Повторная доставка одного и того же вебхука (тот же `object.id`) дважды подряд
   не должна ронять запрос и не должна менять что-то кроме статуса на тот же
   `succeeded`.

## Затронутые файлы (предположительно)

- `prisma/schema.prisma`, новая миграция — добавить `yookassaPaymentId`.
- `src/subscription/subscription.controller.ts` — добавить `POST /pay`,
  `GET /payment/:id/status`, `POST /yookassa-webhook` (без `JwtAuthGuard`).
- `src/subscription/subscription.service.ts` — методы создания платежа, поллинга
  статуса, обработки вебхука; HTTP-клиент к ЮKassa — использовать `axios` напрямую
  (уже в зависимостях, см. паттерн в `src/auth/oauth.service.ts` и
  `src/gyms/gyms.service.ts`), без `@nestjs/axios`.
- `.env.example` — 4 новые переменные (см. раздел 1).
