# Backend: питание в режиме SOLO

Во Flutter-клиенте раздел «Питание» переделан так, что SOLO-пользователь сам
создаёт свой профиль питания и сам составляет меню. Нужно проверить/доработать
бэкенд, чтобы это работало.

## 1. SOLO может создавать и редактировать СВОЙ профиль питания

`POST /api/nutrition/profile` с телом `{ "clientId": "<id текущего пользователя>", ... }`

- Роль `SOLO` должна иметь право на этот запрос, если `clientId == userId` из токена
  (SOLO — сам себе тренер, self-relation).
- Чужой `clientId` для SOLO → `403`.
- Для `TRAINER`/`TRAINER_CLIENT` поведение не менять.

Сейчас клиент при `403` показывает «Сервер не разрешает изменять этот профиль (403)».

## 2. Приёмы пищи и продукты — для своего дневника

SOLO должен иметь доступ (только к своим данным) к:

- `GET  /api/nutrition/meal-plan/:clientId?date=...`
- `POST /api/nutrition/meal-plan/:mealPlanId/meals`
- `POST /api/nutrition/meals/:mealId/items`, `PATCH/DELETE` meals и meal-items
- `GET/POST /api/nutrition/food`
- `POST /api/ai/parse-meal`, `/api/ai/log-meal`, `/api/ai/generate-meal-plan`, `/api/ai/save-meal-plan`

## 3. `POST /api/nutrition/meal-plan/:mealPlanId/meals` — вернуть созданный приём

Ответ должен содержать созданный объект, минимум `{ "id": "<mealId>", "type": "...", ... }`.
Клиент сразу открывает поиск продуктов для этого приёма. (Если `id` нет — клиент
перезагружает сводку и ищет приём по типу, но это лишний запрос.)

## 4. Будущие даты

Клиент разрешает выбирать дату до **7 дней вперёд** (планирование меню).
`GET /api/nutrition/meal-plan/:clientId?date=<будущая дата>` и
`GET /api/nutrition/summary/:clientId?date=<будущая дата>` должны создавать/возвращать
план так же, как для сегодняшней даты, а `/api/ai/save-meal-plan` — сохранять меню на эту дату.
