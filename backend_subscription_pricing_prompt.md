# Задача: управляемые тарифы подписки (SOLO/CLIENT/TRAINER) + скидка 50% на первый месяц

## Сервер
`http://144.31.189.154:8080` (NestJS + Prisma + PostgreSQL, тот же backend, что и в
`backend_nutrition_ai_prompt.md` / `backend_pose_calibration_prompt.md`)

## Контекст

Сейчас в проекте нет ни одной сущности для цены подписки — есть только
`TrainerSettings.plan` и `PLAN_TOKEN_LIMITS` (лимиты токенов AI по тарифу, см.
`backend_nutrition_ai_prompt.md`), но не сама денежная цена плана. Приём
оплаты (ЮKassa) — отдельная, ещё не начатая задача; **эта задача её не
включает**, но должна отдать готовую сумму в рублях, которую тот флоу потом
будет передавать в ЮKassa как `amount.value`.

Три роли, три разных тарифа (см. `Role` во Flutter-клиенте, `lib/core/models/models.dart`):
`SOLO`, `CLIENT`, `TRAINER` — плюс `TRAINER_CLIENT` (роль "оба режима сразу"),
для которой пока нет отдельной цены. **Стартовые цены** (нужно решить, куда
класть дефолты — миграция с seed-данными или просто дефолтные значения в
коде при первом обращении, если строки в таблице ещё нет):

| Роль | Цена, ₽/мес |
|---|---|
| `SOLO` | 250 |
| `CLIENT` | 200 |
| `TRAINER` | 2000 |
| `TRAINER_CLIENT` | 2000 (то же, что `TRAINER` — роль включает весь тренерский функционал) |

Цены должны быть **изменяемыми без деплоя** — через админский эндпоинт, не
хардкодом в коде. Плюс: у любого пользователя, который платит **первый раз**
(ещё не было ни одного успешного платежа за подписку), первый месяц должен
стоить **ровно половину** текущей цены тарифа его роли.

В проекте пока нет ни модели админа, ни `Role.admin` — их заводить не нужно
(не в скоуп этой задачи). Для защиты админских эндпоинтов использовать
простой секрет из окружения: заголовок `X-Admin-Secret`, сверяется с
`process.env.ADMIN_SECRET` (переменная, добавить в `.env.example`). Это
самое простое решение, не требующее новой модели/роли в схеме — если
позже понадобится полноценная админ-роль, это отдельная задача.

## Модель данных (Prisma)

Новая таблица тарифов — **одна текущая цена на роль**, без истории версий
(история не нужна: скидка считается от цены на момент оплаты, а не от того,
что было раньше):

```prisma
model SubscriptionTariff {
  role      String   @id // "SOLO" | "CLIENT" | "TRAINER" | "TRAINER_CLIENT"
  priceRub  Int      // рубли, целое число
  updatedAt DateTime @updatedAt
}
```

Новая таблица платежей за подписку — нужна **уже сейчас**, до появления
самого ЮKassa-флоу, потому что только по ней можно понять, был ли у
пользователя хоть один успешный платёж (критерий "первый месяц"):

```prisma
model SubscriptionPayment {
  id            String   @id @default(uuid())
  userId        String
  role          String   // роль пользователя на момент оплаты
  fullPriceRub  Int      // цена тарифа на момент оплаты, без скидки
  chargedRub    Int      // сколько реально списано (fullPriceRub или половина)
  isFirstMonth  Boolean
  status        String   // "pending" | "succeeded" | "failed" — эта задача создаёт только "pending" через расчёт цены, финализирует статус будущий ЮKassa-флоу
  createdAt     DateTime @default(now())

  @@index([userId, status])
}
```

`user_id` — обычный внешний ключ на существующую таблицу пользователей
(взять из JWT, как везде в проекте).

## 1. `GET /api/subscription/price`

Отдаёт текущему пользователю (по JWT) эффективную цену его роли с учётом
скидки на первый месяц. **Ничего не пишет в БД** — чистый расчёт для показа
цены на экране оплаты до того, как пользователь нажал "Оплатить".

### Ответ
```json
{
  "role": "SOLO",
  "fullPriceRub": 250,
  "isFirstMonth": true,
  "chargedRub": 125
}
```

### Логика
1. Взять роль пользователя из JWT/профиля. `TRAINER_CLIENT` — использовать
   тариф `TRAINER_CLIENT` (не путать с `TRAINER`, они разные строки в
   таблице, даже если цена сейчас одинаковая).
2. Найти `SubscriptionTariff` по роли. Если строки нет — создать её на лету
   с дефолтной ценой из таблицы выше (или гарантировать наличие сидом при
   старте — на усмотрение реализации, лишь бы 404 никогда не было).
3. `isFirstMonth` — `true`, если у пользователя **нет ни одной**
   `SubscriptionPayment` со `status: "succeeded"`.
4. `chargedRub` — `Math.round(fullPriceRub / 2)` если `isFirstMonth`, иначе
   `fullPriceRub`. Округление обязательно (сейчас все цены чётные и делятся
   ровно, но админ может выставить нечётную цену).

## 2. `GET /api/admin/subscription-tariffs`

Список всех тарифов. Защищено `X-Admin-Secret`.

### Ответ
```json
[
  { "role": "SOLO", "priceRub": 250, "updatedAt": "2026-08-25T10:00:00.000Z" },
  { "role": "CLIENT", "priceRub": 200, "updatedAt": "2026-08-25T10:00:00.000Z" },
  { "role": "TRAINER", "priceRub": 2000, "updatedAt": "2026-08-25T10:00:00.000Z" },
  { "role": "TRAINER_CLIENT", "priceRub": 2000, "updatedAt": "2026-08-25T10:00:00.000Z" }
]
```

## 3. `PUT /api/admin/subscription-tariffs/:role`

Меняет цену одной роли. Защищено `X-Admin-Secret`.

### Тело запроса
```json
{ "priceRub": 300 }
```

### Что делает
1. Проверить `X-Admin-Secret` — если не совпадает с `ADMIN_SECRET`, `401`.
2. `:role` — валидировать, что это одно из `SOLO`/`CLIENT`/`TRAINER`/`TRAINER_CLIENT`,
   иначе `400`.
3. `priceRub` — целое положительное число, иначе `400`.
4. `upsert` строки `SubscriptionTariff` по `role`.
5. Изменение цены **не затрагивает** уже созданные `SubscriptionPayment` —
   это просто новая цена для будущих расчётов `GET /api/subscription/price`.

### Ответ
`{ "role": "TRAINER", "priceRub": 300, "updatedAt": "..." }`

## Важно

- Определение "первый месяц" — **по пользователю целиком**, не по роли. Если
  пользователь сменил роль (например, был `SOLO`, стал `TRAINER_CLIENT`),
  скидка всё равно даётся только один раз в жизни аккаунта, а не заново при
  каждой смене роли — иначе это дыра для многократного получения скидки.
- Гонка на создании `SubscriptionPayment`: если пользователь дважды быстро
  дёрнет флоу оплаты (двойной тап), обе попытки могут увидеть
  `isFirstMonth: true` до того, как первая станет `succeeded`. Это забота
  будущего ЮKassa-флоу (создавать `SubscriptionPayment` в статусе `pending`
  атомарно и не создавать вторую `pending`-запись, пока есть незакрытая), не
  этой задачи — но саму таблицу и `status` уже стоит спроектировать с этим в
  голове (см. индекс `[userId, status]` выше).
- `GET /api/subscription/price` не создаёт `SubscriptionPayment` — она
  появляется только когда реально стартует оплата (в будущем ЮKassa-флоу).
  Эта задача только даёт цифру для UI и модель данных, куда будущий платёжный
  флоу запишет результат.
- `ADMIN_SECRET` — простой статический секрет, не JWT и не роль в БД.
  Осознанное упрощение: полноценная админка — отдельная задача, если
  понадобится.

## Как проверить

1. `GET /api/subscription/price` под новым пользователем без единого платежа
   — `isFirstMonth: true`, `chargedRub` вдвое меньше `fullPriceRub` (с
   округлением).
2. Вручную вставить `SubscriptionPayment` со `status: "succeeded"` для этого
   пользователя, повторить запрос — `isFirstMonth: false`, `chargedRub ==
   fullPriceRub`.
3. `PUT /api/admin/subscription-tariffs/SOLO` с `{"priceRub": 300}` без
   заголовка `X-Admin-Secret` — `401`. С правильным секретом — `200`,
   `GET /api/admin/subscription-tariffs` показывает новую цену.
4. После смены цены — `GET /api/subscription/price` для той же роли отдаёт
   уже новую цену, старые `SubscriptionPayment` в БД не изменились.

## Затронутые эндпоинты/файлы (предположительно, нужно найти в коде backend)

- `prisma/schema.prisma` — добавить `SubscriptionTariff` и
  `SubscriptionPayment`, миграция.
- Новый модуль `subscription` (`src/subscription/subscription.controller.ts`,
  `subscription.service.ts`) — по аналогии с `src/ai/` из
  `backend_nutrition_ai_prompt.md`.
- Guard для `X-Admin-Secret` — простой NestJS guard, читает
  `process.env.ADMIN_SECRET`, без записи в БД.
- `.env.example` — добавить `ADMIN_SECRET`.
