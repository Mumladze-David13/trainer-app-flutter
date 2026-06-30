# Баг: Nutrition API возвращает 500 на все запросы

## Сервер
`http://144.31.189.154:8080` (NestJS + TypeORM + PostgreSQL)

## Симптомы

Проверено через прямые HTTP-запросы с валидным JWT-токеном:

```
GET  /api/nutrition/profile/{clientId}   → 500 Internal Server Error
POST /api/nutrition/profile              → 500 Internal Server Error
GET  /api/nutrition/summary/{clientId}   → не проверялось, вероятно 500
GET  /api/nutrition/meal-plan/{clientId} → не проверялось, вероятно 500
```

Тело ответа при 500 — пустое либо `{ "statusCode": 500, "message": "Internal server error" }`.

## Пример запроса который должен работать

```bash
curl -X POST http://144.31.189.154:8080/api/nutrition/profile \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "1933b8e4-284f-45bf-848b-fc4ce70cab36",
    "gender": "male",
    "age": 25,
    "weightKg": 80.0,
    "heightCm": 180.0,
    "activityLevel": "moderate",
    "goal": "maintain"
  }'
```

Все поля соответствуют `CreateNutritionProfileDto` из `/api/docs-json`. Enum-значения правильные (`male/female`, `sedentary/light/moderate/active/very_active`, `lose_fat/maintain/gain_muscle`). Токен валиден (другие API-модули работают: `/api/clients`, `/api/seasons` и т.д.).

## Вероятные причины

### 1. Миграции БД не применены (наиболее вероятно)

Таблицы `nutrition_profiles`, `meal_plans`, `meal_items`, `food_items` не созданы в базе данных. TypeORM пытается сделать SELECT/INSERT в несуществующую таблицу → 500.

```bash
# Проверить какие миграции применены
npm run migration:show

# Применить все pending миграции
npm run migration:run
```

### 2. synchronize: false + отсутствие таблиц

Если в `TypeOrmModule` стоит `synchronize: false` (правильно для prod), но migration для nutrition-таблиц не была создана/применена.

```bash
# Сгенерировать миграцию из entities
npm run migration:generate -- --name=AddNutritionTables

# Применить
npm run migration:run
```

### 3. NutritionModule не зарегистрирован в AppModule

```typescript
// app.module.ts — убедиться что модуль подключён
@Module({
  imports: [
    // ...
    NutritionModule, // ← должен быть здесь
  ],
})
export class AppModule {}
```

### 4. Entity не добавлены в TypeOrmModule.forFeature

```typescript
// nutrition.module.ts
@Module({
  imports: [
    TypeOrmModule.forFeature([
      NutritionProfile,
      MealPlan,
      Meal,
      MealItem,
      FoodItem,
    ]),
  ],
  // ...
})
export class NutritionModule {}
```

## Как диагностировать

### Шаг 1 — проверить логи сервера

```bash
# PM2
pm2 logs --lines 50

# Docker
docker logs <container_id> --tail 50

# Systemd
journalctl -u trainer-backend -n 50
```

Сделать запрос к `/api/nutrition/profile/{любой_id}` и посмотреть stack trace в логах.

### Шаг 2 — проверить таблицы в PostgreSQL

```sql
-- Подключиться к БД и проверить наличие таблиц
\dt

-- Или конкретно:
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'nutrition_profiles',
  'meal_plans',
  'meals',
  'meal_items',
  'food_items'
);
```

Если таблицы отсутствуют — применить миграции (Шаг 1 из раздела выше).

## Эндпоинты которые должны работать после фикса

| Метод | URL | Описание |
|-------|-----|----------|
| `POST` | `/api/nutrition/profile` | Создать/обновить профиль питания клиента |
| `GET` | `/api/nutrition/profile/:clientId` | Получить профиль + расчёты TDEE/КБЖУ |
| `GET` | `/api/nutrition/summary/:clientId?date=YYYY-MM-DD` | Дневное КБЖУ + список приёмов пищи |
| `GET` | `/api/nutrition/meal-plan/:clientId?date=YYYY-MM-DD` | План питания на дату |
| `POST` | `/api/nutrition/meal-plan/:mealPlanId/meals` | Добавить приём пищи в план |
| `POST` | `/api/nutrition/meals/:mealId/items` | Добавить продукт в приём пищи |
| `DELETE` | `/api/nutrition/meal-items/:itemId` | Удалить продукт из приёма |
| `GET` | `/api/nutrition/food?query=...` | Поиск продуктов |
| `POST` | `/api/nutrition/food` | Создать кастомный продукт |

## Ожидаемый ответ GET /api/nutrition/profile/:clientId

```json
{
  "profile": {
    "clientId": "uuid",
    "gender": "male",
    "age": 25,
    "weightKg": 80.0,
    "heightCm": 180.0,
    "activityLevel": "moderate",
    "goal": "maintain",
    "targetWeeklyChange": null
  },
  "calculations": {
    "bmr": 1894.0,
    "tdee": 2931.7,
    "targetCalories": 2931.7,
    "macros": {
      "protein": 160.0,
      "fat": 97.7,
      "carbs": 366.5
    }
  }
}
```
