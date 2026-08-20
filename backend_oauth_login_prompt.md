# Задача: вход через Google, VK и Mail.ru

## Сервер
`http://144.31.189.154:8080` (NestJS + Prisma + PostgreSQL, тот же backend, что и в
остальных `backend_*_prompt.md`)

## Контекст

Сейчас в приложении только email/password-вход:
`POST /api/auth/register` и `POST /api/auth/login` (`src/auth/auth.controller.ts`,
`src/auth/auth.service.ts`) — оба возвращают `{ user, token }`, где `token` —
JWT со сроком жизни 60 дней (`src/auth/auth.module.ts`), а `user` — модель из
`prisma/schema.prisma` (`id, email, password, firstName, lastName, role,
fcmToken, gymId, address, createdAt, updatedAt`).

Пользователь хочет добавить вход через Google, VK и Mail.ru. Flutter-сторона уже
реализована (в этой сессии) под конкретный контракт, описанный ниже — его нужно
реализовать 1:1, не меняя. Ключевая идея: клиент **не получает и не отправляет
секреты провайдеров** и не видит JWT в URL — всё это остаётся на backend, клиент
только открывает системный браузер и получает одноразовый код обмена.

Flutter-сторона (для справки, ничего здесь менять не нужно):
- `lib/core/services/auth_provider.dart` → `loginWithOAuth(provider)` — открывает
  `FlutterWebAuth2.authenticate(url: '$baseUrl/auth/$provider?platform=web|mobile',
  callbackUrlScheme: 'trainerapp')`, затем шлёт полученный `code` на
  `POST /auth/exchange`, ответ прогоняет через тот же `_handleAuth`, что и обычный
  логин.
- `lib/core/services/api_service.dart` → `exchangeOAuthCode(code)` →
  `POST /auth/exchange`.
- `lib/features/auth/login_screen.dart` — три кнопки (Google/VK/Mail.ru), при
  `isNewUser == true` в ответе `/auth/exchange` ведут на экран выбора роли
  (`ChooseRoleScreen`), который дергает уже существующий `PUT /users/me/role`
  (`src/users/...`, не трогать) — то есть про роль для новых OAuth-пользователей
  никакого отдельного эндпоинта делать не надо, только дефолт `CLIENT` при
  создании.

## 1. Схема БД (Prisma)

В `prisma/schema.prisma`, модель `User`:
- `password` сделать опциональным: `password String?` (OAuth-пользователи пароль
  не задают).
- Добавить два поля: `provider String?` и `providerId String?` — храним, через
  какого провайдера создан аккаунт и его id там (`null`/`null` для обычной
  email/password-регистрации).
- Добавить уникальный составной индекс `@@unique([provider, providerId])`, чтобы
  find-or-create ниже был атомарным на уровне БД.

```prisma
model User {
  id         String   @id @default(uuid())
  email      String   @unique
  password   String?
  provider   String?
  providerId String?
  firstName  String
  lastName   String
  role       Role
  // ...остальные поля без изменений

  @@unique([provider, providerId])
}
```

Прогнать `prisma migrate dev --name add_oauth_fields` (или `migrate deploy` на
проде).

## 2. Одноразовый exchange-код

Чтобы реальный JWT никогда не попадал в redirect URL (браузер логирует историю,
custom-scheme deep link на Android теоретически может перехватить другое
приложение), между OAuth-колбэком и выдачей токена клиенту — промежуточный шаг:

1. После успешной авторизации у провайдера backend формирует финальный ответ
   `{ user, token, isNewUser }` (тот же `token`, что выдаёт `generateToken()` в
   `auth.service.ts`), генерирует случайный одноразовый код
   (`crypto.randomUUID()`), кладёт `{ code -> ответ }` в короткоживущее хранилище
   (in-memory `Map` с TTL ~60 секунд, или Redis, если уже используется в проекте —
   что проще внедрить, то и взять) и удаляет запись сразу после первого чтения
   (single-use).
2. Редиректит браузер на конечный callback (см. пункт 4) с `?code=<uuid>`.
3. Клиент почти сразу же дергает `POST /auth/exchange { code }`, backend отдаёт
   сохранённый `{ user, token, isNewUser }` и удаляет запись. Повторный вызов с
   тем же `code` — `400/404`.

Реализовать как небольшой `OAuthExchangeService` (`src/auth/oauth-exchange.service.ts`)
с методами `create(payload): string` и `consume(code): payload | null`.

## 3. Эндпоинты

Все — в `src/auth/auth.controller.ts`, рядом с существующими `register`/`login`.

### `GET /api/auth/:provider`

`provider` — один из `google`, `vk`, `mailru` (валидировать, иначе `404`).
Query-параметр `platform` — `web` или `mobile` (по умолчанию `mobile`).

Строит authorize-URL нужного провайдера и делает `302`-редирект на него.
`platform` нужно протащить через `state`-параметр (JSON или просто сама строка,
подписанная/провалидированная, чтобы её нельзя было подделать в обход) — он
понадобится в callback, чтобы знать, куда редиректить обратно.

Authorize-URL и redirect_uri (`{PUBLIC_API_URL}/api/auth/:provider/callback`):

- **Google**: `https://accounts.google.com/o/oauth2/v2/auth`,
  `response_type=code&scope=email profile&client_id=$GOOGLE_CLIENT_ID`.
  Можно оформить через `passport-google-oauth20` (пакет уже стоит смысл добавить
  в зависимости) либо вручную через `axios` — на усмотрение реализующего, ниже
  контракт не зависит от выбора.
- **VK** (VK ID, `id.vk.com`): `https://id.vk.com/authorize`,
  `response_type=code&client_id=$VK_CLIENT_ID&scope=email`. VK ID требует PKCE
  (`code_verifier`/`code_challenge`) — сгенерировать `code_verifier`, положить
  во временное хранилище вместе с `state`, использовать при обмене кода на токен.
- **Mail.ru**: `https://oauth.mail.ru/login`,
  `response_type=code&client_id=$MAILRU_CLIENT_ID&scope=userinfo`.

Готовых актуальных NestJS/passport-стратегий под VK и Mail.ru скорее всего нет —
делать вручную через `axios`/`HttpService` (в проекте уже используется axios,
судя по `nutrition`/`ai`-модулям).

### `GET /api/auth/:provider/callback`

Принимает `code` и `state` от провайдера. Шаги:
1. Восстановить `platform` из `state`.
2. Обменять `code` на access-токен провайдера (token endpoint):
   - Google: `POST https://oauth2.googleapis.com/token`
   - VK: `POST https://id.vk.com/oauth2/auth`
   - Mail.ru: `POST https://oauth.mail.ru/token`
3. Получить профиль пользователя (userinfo endpoint):
   - Google: `GET https://www.googleapis.com/oauth2/v3/userinfo` — `sub`, `email`,
     `given_name`, `family_name`.
   - VK: `GET https://id.vk.com/oauth2/user_info` (передать access-токен) —
     `user_id`, `email` (если запрошен и подтверждён), `first_name`, `last_name`.
   - Mail.ru: `GET https://oauth.mail.ru/userinfo` — `id`, `email`, `first_name`,
     `last_name`.
4. **Find-or-create** пользователя:
   - Сначала ищем по `(provider, providerId)` — если нашли, это возврат
     существующего OAuth-пользователя → `isNewUser = false`.
   - Если не нашли, но `email` совпадает с уже существующим (email/password или
     другим OAuth-провайдером) аккаунтом — линкуем: проставляем этому
     существующему `User` найденные `provider`/`providerId` (если у него их ещё
     нет), логиним под него → `isNewUser = false`.
   - Иначе создаём нового `User`: `email`, `firstName`, `lastName` из профиля
     провайдера, `password: null`, `provider`, `providerId`, `role: 'CLIENT'`
     (дефолт — пользователь сможет сменить в приложении через уже существующий
     `PUT /users/me/role`) → `isNewUser = true`.
   - Если у провайдера email не пришёл (у VK/Mail.ru это возможно, если юзер не
     подтвердил email) — сгенерировать заглушку вида
     `${provider}_${providerId}@noemail.local`, не блокировать регистрацию.
5. `generateToken(user)` — тем же методом, что и в `auth.service.ts` для обычного
   логина.
6. `OAuthExchangeService.create({ user: <тот же формат, что возвращает
   register/login>, token, isNewUser })` → получить одноразовый `code`.
7. Редирект:
   - `platform === 'mobile'` → `302` на
     `trainerapp://auth-callback?code=<code>`
   - `platform === 'web'` → `302` на `${FRONTEND_URL}/auth_callback.html?code=<code>`
   - при любой ошибке на шагах 2-4 — редирект на тот же callback с
     `?error=<короткое_машиночитаемое_описание>` вместо `code` (Flutter показывает
     пользователю просто "не удалось войти").

### `POST /api/auth/exchange`

Body: `{ "code": "..." }`. Смотрит код в `OAuthExchangeService.consume(code)`:
- Нашли и не протух → `200 { user, token, isNewUser }` (ровно та же форма
  `user`/`token`, что у `/auth/login`), запись удаляется.
- Не нашли/протух/уже использован → `400 Bad Request`.

Без авторизации (это и есть точка получения токена).

## 4. Переменные окружения

Добавить в `.env` (и задокументировать в `.env.example`, которого сейчас не
хватает многих уже используемых переменных — заодно синхронизировать):

```
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
VK_CLIENT_ID=
VK_CLIENT_SECRET=
MAILRU_CLIENT_ID=
MAILRU_CLIENT_SECRET=
PUBLIC_API_URL=http://144.31.189.154:8080   # для redirect_uri провайдеров
OAUTH_MOBILE_REDIRECT_SCHEME=trainerapp
```

`FRONTEND_URL` уже есть в `.env.example` — используется как есть для web-редиректа
(должен указывать на домен, где задеплоен `web/auth_callback.html` из
Flutter-репозитория, см. Firebase Hosting конфиг `firebase.json`).

Client id/secret для всех трёх провайдеров получает и вписывает сам пользователь
(создание OAuth-приложений в Google Cloud Console / VK ID / Mail.ru OAuth — вне
скоупа этой задачи), redirect URI, который нужно будет указать в консолях
провайдеров: `{PUBLIC_API_URL}/api/auth/:provider/callback` для каждого из трёх.

## 5. Проверка

```bash
# должен отдать 302 на consent-экран Google
curl -i "http://144.31.189.154:8080/api/auth/google?platform=web"

# после ручного прохождения флоу в браузере — код из редиректа:
curl -X POST http://144.31.189.154:8080/api/auth/exchange \
  -H "Content-Type: application/json" \
  -d '{"code": "<код из ?code=...>"}'
# ожидается 200 { user, token, isNewUser }

# повторный вызов с тем же code — уже 400
```

Затем — вручную через Flutter-приложение (`flutter run`, экран логина, три новые
кнопки): первый вход новым email через каждого из трёх провайдеров должен создать
пользователя с `role = CLIENT` и показать экран выбора роли; повторный вход тем же
провайдером — сразу попасть на dashboard без экрана выбора роли.
