# Задача: включить Gemini на проде + сделать `POST /api/ai/parse-workout-audio` через Gemini

## Сервер
`http://95.81.72.98:8080` (NestJS + Prisma + PostgreSQL), репозиторий
`trainer-app/backend`, деплой — GitHub Actions (`.github/workflows/deploy.yml`)
→ `/var/www/trainer-app/backend`, `docker compose` с `env_file: .env`.

## Статус на 2026-10-02 (проверено по логам Flutter-приложения на телефоне)

| Запрос | Ответ прода |
|---|---|
| `POST /api/solo/generate-program` | `500 {message: "ИИ-провайдер не настроен: не задан ANTHROPIC_API_KEY"}` |
| `POST /api/ai/parse-meal` | `500 {message: "ИИ-провайдер не настроен: не задан ANTHROPIC_API_KEY"}` |
| `POST /api/ai/parse-workout-audio` | `404 {message: "Cannot POST /api/ai/parse-workout-audio"}` |

Flutter-сторона готова, контракты не меняются, менять в приложении ничего не нужно.

---

## Часть 1. Включить Gemini на проде (без изменений кода)

Коммит `9aff756 feat: add Gemini AI provider…` **уже задеплоен** — текст
ошибки «ИИ-провайдер не настроен: не задан …» появился именно в нём.
Но `AiGateway.provider()` берёт провайдера из env:

```ts
const value = (process.env.AI_PROVIDER || 'anthropic').trim().toLowerCase();
```

На сервере в `/var/www/trainer-app/backend/.env` нет `AI_PROVIDER`, поэтому
используется дефолтный `anthropic`, а ключа Anthropic там нет → 500 на всех
AI-эндпоинтах (генерация программы тренера и Solo, питание, разбор тренировки,
упражнения, вес — все они идут через `AiGateway`).

### Что сделать
1. На сервере дописать в `/var/www/trainer-app/backend/.env`:
   ```
   AI_PROVIDER=gemini
   GEMINI_API_KEY=<ключ из Google AI Studio>
   # GEMINI_MODEL=gemini-3.8-flash   # опционально, это и так дефолт
   ```
   Ключ не коммитить и не писать в этот файл/чаты.
2. Пересоздать контейнер, чтобы он перечитал `.env`:
   ```
   cd /var/www/trainer-app/backend && docker compose up -d --force-recreate
   ```
3. Проверить, что в контейнере переменные видны:
   `docker exec trainer-backend printenv AI_PROVIDER` → `gemini`
   (ключ целиком в логи/консоль не выводить).

### Как проверить
Под JWT тренера:
- `POST /api/ai/parse-meal` `{"text":"гречка 150г и куриная грудка 200г"}` → `201`, `items` с КБЖУ.
- `POST /api/ai/parse-workout` `{"text":"жим лёжа три подхода по десять на восьмидесяти"}` → `201`, `exercises`.
- `POST /api/ai/generate-program` (тренер → клиент) и `POST /api/solo/generate-program` (SOLO) → `201`.
- Ни один ответ не содержит «не задан ANTHROPIC_API_KEY».

---

## Часть 2. `POST /api/ai/parse-workout-audio` — новый эндпоинт

Сейчас в `src/ai/ai.controller.ts` есть только текстовый `parse-workout`.
Flutter перестал распознавать речь на устройстве (системный STT на MIUI
выдаёт мусор вместо русской речи) и отправляет аудиофайл целиком на бэкенд.

Старый `backend_voice_workout_audio_prompt.md` предлагал отдельный STT
(OpenAI Whisper), потому что у Claude нет приёма аудио. **С Gemini это не
нужно**: Gemini принимает аудио напрямую, поэтому транскрипция и разбор на
упражнения делаются **одним вызовом модели**, без второго провайдера и без
`OPENAI_API_KEY`.

### Что шлёт клиент (уже реализовано во Flutter)
- `lib/core/services/api_service.dart` → `aiParseWorkoutAudio(File)`.
- `multipart/form-data`, одно поле **`audio`**: файл `.m4a` (AAC-LC, 16 kHz,
  моно), обычно от нескольких секунд до пары минут.
- Таймауты клиента: отправка 60 с, ожидание ответа 60 с.
- Ожидает **тот же ответ, что у `parse-workout`**:
  `{ exercises: [{ exerciseId: string|null, name, sets, reps, weight: number|null }], ... }`.
  Клиент читает только `exercises`; сопоставление с каталогом и ошибки
  обрабатывает сам. На не-403 ошибку покажет `HTTP <код>: <message>`, на 403 —
  экран лимита.

### Контроллер (`src/ai/ai.controller.ts`)
```ts
@Post('parse-workout-audio')
@Roles(Role.TRAINER, Role.TRAINER_CLIENT, Role.SOLO)   // как у parse-workout
@UseInterceptors(FileInterceptor('audio', { limits: { fileSize: 20 * 1024 * 1024 } }))
@ApiConsumes('multipart/form-data')
parseWorkoutAudio(@UploadedFile() file: Express.Multer.File, @CurrentUser() user: any) {
  return this.aiService.parseWorkoutAudio(file, user.id);
}
```
- Загрузка файлов в проекте пока нигде не используется. Нужны `@nestjs/platform-express`
  (обычно уже есть) и `@types/multer` в devDependencies; файл держать в памяти
  (по умолчанию `memoryStorage`), на диск не писать.
- Нет файла или пустой `file.buffer` → `400 BadRequestException('Файл записи не передан')`.
- Больше 20 МБ → `413` (multer `LIMIT_FILE_SIZE`; проверить, что Nest
  отдаёт 413, а не 500, при необходимости поймать и пробросить `PayloadTooLargeException`).
- MIME строго не проверять: Dio может прислать `application/octet-stream`.
  Для Gemini передавать `audio/mp4`, если пришёл не `audio/*`.

### `AiGateway` — метод для запроса с аудио
Добавить в `src/ai/ai.gateway.ts` метод, например:
```ts
async completeJsonWithAudio(
  systemPrompt: string,
  audio: Buffer,
  mimeType: string,
  userText?: string,
): Promise<AiResponse>
```
- Для `gemini`: `contents` из одного user-сообщения с `inlineData`
  `{ mimeType, data: audio.toString('base64') }` (+ необязательная текстовая
  часть), тот же `config`, что в `geminiRequest(..., json=true)`
  (`responseMimeType: 'application/json'`, `systemInstruction`,
  `thinkingLevel: MINIMAL`). Inline-данные подходят до ~20 МБ на запрос,
  Files API не нужен. Ответ обработать как в `completeJson`: `stripJsonFence`,
  usage через `geminiUsage`.
- Для `anthropic`: аудио Claude не принимает →
  `throw new BadRequestException('Распознавание аудио доступно только при AI_PROVIDER=gemini')`
  (`400`, не `500`, чтобы клиент показал понятное сообщение).

### Сервис (`src/ai/ai.service.ts`)
**Не копировать** `parseWorkout`, а вынести общее в приватные методы, чтобы
текстовый и аудио-путь не расходились:
1. Проверка лимита токенов (`getOrCreateSettings`, `planTokenLimit`,
   `getMonthlyTokensUsed`, `ForbiddenException`) — общая.
2. Загрузка каталога (`trainerExercise.findMany`), `exerciseList`,
   `validExerciseIds` и системный промт — общий построитель промта.
3. Валидация и нормализация ответа модели (JSON.parse, `exercises`,
   `exerciseId` только из `validExerciseIds`, иначе `null`) и запись
   `aiUsageLog` — общие.

В `parseWorkoutAudio(file, trainerId)` — тот же системный промт плюс абзац:
```
Тебе передана аудиозапись: тренер на русском надиктовывает состав тренировки.
Сначала распознай речь, затем разбери её по правилам ниже.
Дополнительно верни поле "transcript" — распознанный текст целиком.
Если в записи нет речи или в ней нет упражнений — верни {"transcript": "...", "exercises": []}.
```
- Вызов `this.gateway.completeJsonWithAudio(systemPrompt, file.buffer, mime)`.
- Если `exercises` пустой и `transcript` пустой →
  `400 BadRequestException('Не удалось распознать речь в записи. Попробуйте ещё раз.')`.
- `aiUsageLog` с `operation: 'parse_workout_audio'`, чтобы в `GET /ai/usage`
  было видно голосовые запросы отдельно.
- Ответ: `{ exercises, transcript, usage: { totalTokens, costUsd } }`, то есть
  форма `parse-workout` плюс `transcript` для отладки. Клиенту лишнее поле не мешает.
- Стоимость: аудио-токены Gemini приходят в `usageMetadata.promptTokenCount`,
  отдельный тариф для них в первой версии не нужен.

### Тесты
- `ai.gateway.spec.ts`: при `gemini` в `generateContent` уходит `inlineData`
  с base64 и правильным `mimeType`, включён `responseMimeType: application/json`;
  при `anthropic` — `BadRequestException`.
- `ai.service.spec.ts`: `parseWorkoutAudio` — неизвестный `exerciseId`
  обнуляется; пустой результат даёт 400; лимит даёт 403; пишется лог `parse_workout_audio`.
- Существующие тесты `parseWorkout` проходят без изменений.

### Как проверить на проде
1. `curl -H "Authorization: Bearer <JWT тренера>" -F "audio=@workout.m4a" http://95.81.72.98:8080/api/ai/parse-workout-audio`
   (запись на русском: «жим лёжа три подхода по десять на восьмидесяти, присед четыре по восемь»)
   → `201`, в `exercises` две позиции, `transcript` похож на сказанное.
2. Запись тишины → `400` с понятным `message`, не `500`.
3. Без файла → `400`; без JWT → `401`; роль `CLIENT` → `403`; файл > 20 МБ → `413`.
4. `POST /api/ai/parse-workout` (текст) работает как раньше.
5. В приложении: тренер → редактор тренировки → микрофон → запись → упражнения
   появляются в списке для проверки.

## Затронутые файлы
- `/var/www/trainer-app/backend/.env` на сервере: `AI_PROVIDER`, `GEMINI_API_KEY` (часть 1).
- `src/ai/ai.gateway.ts`: `completeJsonWithAudio`.
- `src/ai/ai.service.ts`: `parseWorkoutAudio` и общие приватные методы, вынесенные из `parseWorkout`.
- `src/ai/ai.controller.ts`: `@Post('parse-workout-audio')`.
- `package.json`: `@types/multer` (dev).
- `.env.example`: комментарий, что аудио-распознавание работает только с `AI_PROVIDER=gemini`.
- Spec-файлы из раздела «Тесты».

`backend_voice_workout_audio_prompt.md` (вариант с Whisper) этим файлом заменён.
