# Задача: эндпоинты для сбора данных калибровки AI-анализа техники

## Сервер
`http://144.31.189.154:8080` (NestJS + TypeORM + PostgreSQL, тот же backend что и в
`backend_fcm_payload_prompt.md`)

## Контекст

Flutter-приложение анализирует технику упражнений на устройстве через Google ML Kit
Pose Detection (33 точки скелета) и считает по ним оценку техники (`formScore`),
углы суставов и т.п. Часть метрик (заваливание колен, отрыв пятки, положение колена
относительно носка) пока не откалибрована — нет проверенных пороговых значений,
поэтому сырые данные с реальных тренировок собираются и должны уезжать на сервер,
чтобы позже на них подобрать правильные пороги.

Нужны **два новых эндпоинта**, оба защищены обычной авторизацией приложения
(`Authorization: Bearer <token>`, тот же механизм, что и у всех остальных
`/api/*` роутов — пользователь достаётся из JWT).

Раньше это писалось в локальный файл на телефоне — теперь только на сервер,
локальной копии у клиента больше нет. Ретраев на клиенте тоже нет: если запрос не
прошёл, данные один раз молча теряются (это не критично, это just calibration
data, а не пользовательские данные).

## 1. `POST /api/pose-analysis/calibration-frames`

Собирается **автоматически в фоне** во время обычного анализа техники (не
отдельный экран) — по одному кадру раз в ~300мс, батчами по 30 штук.

### Тело запроса

```json
{
  "frames": [
    {
      "ts": "2026-07-24T10:15:32.123Z",
      "exercise": "squat",
      "view": "front",
      "phase": "down",
      "formScore": 82.5,
      "imageWidth": 1280,
      "imageHeight": 720,
      "angles": { "knee": 97.3, "hip": 101.2, "kneeRight": 95.8 },
      "calibrationMetrics": {
        "kneeSpreadPx": 143.2,
        "ankleSpreadPx": 168.9,
        "kneeAnkleRatio": 0.848,
        "kneeAnkleBaselineRatio": 0.91,
        "heelLiftPx": -3.1,
        "kneeOverToePx": 12.4
      }
    }
  ]
}
```

- `exercise` — одно из: `squat`, `pushUp`, `deadlift`, `bicepCurl`, `shoulderPress`.
- `view` — `side` или `front`.
- `angles` и `calibrationMetrics` — плоские объекты `string -> number`, набор
  ключей **не фиксирован** и может меняться между версиями приложения (новые
  метрики будут добавляться). Хранить как есть, например `jsonb`.
- Запрос может прийти с массивом от 1 до ~30 объектов.

### Ответ
`201 Created` (или `202 Accepted`), тело не важно клиенту — он его не читает.

### Что сделать в БД
Таблица (условно `pose_calibration_frames`): `id`, `user_id` (из JWT),
`created_at` (`ts` из запроса или `now()`), `exercise`, `view`, `phase`,
`form_score`, `image_width`, `image_height`, `angles jsonb`,
`calibration_metrics jsonb`. Индекс по `(exercise, view)` — по нему потом будут
выгружать данные для анализа порогов.

## 2. `POST /api/pose-analysis/dataset-cases`

Отправляется **не автоматически**, а из отдельного инструмента (вручную,
пользователь жмёт "Начать/Остановить запись", описывает, что не так с техникой) —
целиком одним запросом при остановке записи одного повторения/подхода.

### Тело запроса

```json
{
  "caseId": "squat_correct_1721816132123",
  "exercise": "Приседания со штангой",
  "viewMode": "side",
  "label": "incorrect",
  "comment": "колени уходят внутрь на подъёме",
  "frames": [
    {
      "frameIndex": 0,
      "ts": "2026-07-24T10:15:32.123Z",
      "imageWidth": 1280,
      "imageHeight": 720,
      "landmarks": {
        "leftShoulder": { "x": 412.5, "y": 210.3, "z": -30.1, "likelihood": 0.98 },
        "leftHip": { "x": 420.1, "y": 480.7, "z": -12.4, "likelihood": 0.97 },
        "leftKnee": { "x": 415.0, "y": 620.2, "z": -8.1, "likelihood": 0.95 }
      }
    }
  ]
}
```

- `caseId` — сгенерирован клиентом, **уникален**, можно использовать как ключ
  идемпотентности (если один и тот же `caseId` прилетит второй раз — обновить
  запись, а не создавать дубликат; на будущее, если появятся ретраи).
- `label` — `correct` или `incorrect`.
- `comment` — обязателен только когда `label == "incorrect"` (на клиенте это уже
  провалидировано, но со стороны бека проверять не нужно — просто сохранить как
  есть, может быть пустой строкой при `correct`).
- `exercise` — свободный текст (название упражнения из каталога `/exercises` или
  введённое вручную), не enum.
- `landmarks` — объект `landmarkName -> {x, y, z, likelihood}`. `landmarkName` —
  имя точки из набора Google ML Kit BlazePose (33 точки: `nose`,
  `leftEyeInner`, `leftEye`, `leftEyeOuter`, `rightEyeInner`, `rightEye`,
  `rightEyeOuter`, `leftEar`, `rightEar`, `leftMouth`, `rightMouth`,
  `leftShoulder`, `rightShoulder`, `leftElbow`, `rightElbow`, `leftWrist`,
  `rightWrist`, `leftPinky`, `rightPinky`, `leftIndex`, `rightIndex`,
  `leftThumb`, `rightThumb`, `leftHip`, `rightHip`, `leftKnee`, `rightKnee`,
  `leftAnkle`, `rightAnkle`, `leftHeel`, `rightHeel`, `leftFootIndex`,
  `rightFootIndex`). Не все точки обязательно присутствуют в каждом кадре —
  сколько ML Kit нашло, столько и придёт. Хранить как `jsonb`, схему не
  валидировать по списку точек (список может расшириться).
- Один кейс может содержать от одного до нескольких сотен кадров (запись идёт,
  пока пользователь не остановит) — тело запроса может быть увесистым
  (десятки–сотни КБ), лимит размера тела на роуте нужно проверить/поднять если
  стоит дефолтный небольшой (например, стандартный `express`/`body-parser`
  лимит в 100kb).

### Ответ
`201 Created`.

### Что сделать в БД
Таблица (условно `pose_dataset_cases`): `id`, `case_id` (unique), `user_id` (из
JWT), `created_at`, `exercise`, `view_mode`, `label`, `comment`,
`frames jsonb` (весь массив кадров одним jsonb-полем — читать его целиком будут
батч-скриптом при подборе порогов, отдельная таблица per-frame не нужна).

## Важно

- Оба роута — просто "запись сырых данных", никакой бизнес-логики/валидации
  сверх типов не требуется.
- `user_id` брать из JWT (`req.user.id`), не из тела запроса.
- Тела запросов **не должны блокировать основной поток** пользователя —
  ответ должен возвращаться быстро (запись в БД, без синхронной пост-обработки).
- Ключи внутри `angles` / `calibrationMetrics` / `landmarks` не фиксированы
  заранее — не валидировать по конкретному списку, просто сохранять весь объект.

## Пример (NestJS + TypeORM)

```typescript
@Post('pose-analysis/calibration-frames')
@UseGuards(JwtAuthGuard)
async uploadCalibrationFrames(
  @Req() req,
  @Body() body: { frames: Record<string, any>[] },
) {
  const rows = body.frames.map((f) => ({
    userId: req.user.id,
    createdAt: f.ts ? new Date(f.ts) : new Date(),
    exercise: f.exercise,
    view: f.view,
    phase: f.phase,
    formScore: f.formScore,
    imageWidth: f.imageWidth,
    imageHeight: f.imageHeight,
    angles: f.angles ?? {},
    calibrationMetrics: f.calibrationMetrics ?? {},
  }));
  await this.calibrationRepo.insert(rows);
  return { saved: rows.length };
}

@Post('pose-analysis/dataset-cases')
@UseGuards(JwtAuthGuard)
async uploadDatasetCase(@Req() req, @Body() body: Record<string, any>) {
  await this.datasetRepo.upsert(
    {
      caseId: body.caseId,
      userId: req.user.id,
      exercise: body.exercise,
      viewMode: body.viewMode,
      label: body.label,
      comment: body.comment,
      frames: body.frames,
    },
    ['caseId'],
  );
  return { ok: true };
}
```

## Как проверить

1. Открыть экран "Анализ техники" в приложении, выбрать упражнение, нажать
   "Начать анализ" — раз в ~10 кадров (батч по 30) должен прилетать
   `POST /api/pose-analysis/calibration-frames`.
2. Открыть "Сбор данных калибровки" (иконка в app bar того же экрана), выбрать
   упражнение, "Правильно"/"Неправильно" (+ комментарий для "Неправильно"),
   "Начать запись" → подвигаться в кадре → "Остановить запись" — должен уйти
   один `POST /api/pose-analysis/dataset-cases` со всеми кадрами кейса.
3. Проверить в БД, что записи появляются с правильным `user_id` и что `jsonb`
   поля не обрезаны/не потеряны.

## Затронутые эндпоинты/файлы (предположительно, нужно найти в коде backend)

- Новый модуль/контроллер, например `pose-analysis` (по аналогии с существующими
  `exercises`, `nutrition` и т.п.)
- Две новые таблицы/сущности: `pose_calibration_frames`, `pose_dataset_cases`
- Убедиться, что body size limit на этих роутах достаточен для кейсов с
  большим числом кадров
