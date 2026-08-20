# Задача: удаление сезона + изменение даты занятия (Workout)

## Сервер
`http://144.31.189.154:8080` (NestJS + TypeORM/Prisma + PostgreSQL, тот же backend,
что и в остальных `backend_*_prompt.md`)

## Контекст

Пользователь запросил 4 функции для тренера: удалить сезон, удалить занятие,
поменять дату занятия, поменять дату сезона. Проверил реальный код на сервере
(`C:\proj\trainer-app\backend`) — из четырёх уже готовы:

- **Удалить занятие** — `DELETE /api/workouts/:id` уже есть
  (`workouts.controller.ts` → `WorkoutsService.deleteWorkout`). Flutter-сторона
  подключена.
- **Поменять дату сезона** — `PUT /api/clients/:clientId/seasons/:seasonId`
  уже есть (`seasons.controller.ts` → `SeasonsService.updateSeason`, принимает
  `{ name?, startDate?, endDate? }`). Flutter-сторона подключена.

Не хватает двух вещей:

## 1. `DELETE /api/clients/:clientId/seasons/:seasonId` — удалить сезон

В `src/seasons/seasons.controller.ts` рядом с существующими `@Get()`/`@Post()`/
`@Put(':seasonId')` добавить:

```ts
@Delete(':seasonId')
@ApiOperation({ summary: 'Удалить сезон' })
@ApiParam({ name: 'clientId', description: 'ID клиента' })
@ApiParam({ name: 'seasonId', description: 'ID сезона' })
@ApiResponse({ status: 200, description: 'Сезон удалён' })
@ApiResponse({ status: 404, description: 'Сезон не найден' })
public deleteSeason(
  @CurrentUser() user: any,
  @Param('seasonId') seasonId: string,
) {
  return this.seasonsService.deleteSeason(seasonId, user.id);
}
```

(не забыть добавить `Delete` в импорт из `@nestjs/common`)

В `src/seasons/seasons.service.ts` добавить метод, по образцу уже существующего
`updateSeason` (та же проверка владения через `trainerClient.trainerId`):

```ts
public async deleteSeason(seasonId: string, trainerId: string) {
  const season = await this.prisma.season.findUnique({
    where: { id: seasonId },
    include: { trainerClient: true },
  });
  if (!season) throw new NotFoundException('Season not found');
  if (season.trainerClient.trainerId !== trainerId) throw new ForbiddenException();

  await this.prisma.season.delete({ where: { id: seasonId } });
  return { message: 'Season deleted' };
}
```

Проверил `prisma/schema.prisma` — `Workout.season` уже объявлен с
`onDelete: Cascade`, так что удаление сезона автоматически каскадно удалит все
его `Workout` (и через их собственные relations — `WorkoutExercise`,
`WorkoutCompletion`). Вручную ничего досыпать не нужно, миграция не требуется.

## 2. `date` в `UpdateWorkoutDto` — изменить дату занятия

`Workout.date` в схеме (`prisma/schema.prisma:154`) уже существует
(`DateTime @default(now())`), но выставляется только при создании (неявно,
через дефолт) — `CreateWorkoutDto`/`UpdateWorkoutDto`
(`src/workouts/dto/create-workout.dto.ts`) вообще не принимают `date`.

В `UpdateWorkoutDto` добавить:

```ts
@ApiPropertyOptional({ example: '2026-08-20' })
@IsOptional()
@IsDateString()
date?: string;
```

(добавить `IsDateString` в импорт из `class-validator`)

В `src/workouts/workouts.service.ts` → `updateWorkout()` — сейчас там что-то
вроде:

```ts
const updated = await this.prisma.workout.update({
  where: { id },
  data: {
    ...(dto.notes !== undefined && { notes: dto.notes }),
    // ...workoutExercises пересоздание...
  },
  ...
});
```

Добавить туда же `...(dto.date && { date: new Date(dto.date) })`.

Опционально (не обязательно для этой задачи, но симметрично): то же самое
можно добавить и в `CreateWorkoutDto`/`createWorkout()`, если тренер должен
уметь сразу проставить дату при создании занятия, а не только менять её потом.
Сейчас `createWorkout()` дату вообще не принимает — берётся дефолт `now()`.
Уточнить у меня, нужно ли это заодно, или сфокусироваться только на update.

## Проверка

```bash
curl -X DELETE http://144.31.189.154:8080/api/clients/<clientId>/seasons/<seasonId> \
  -H "Authorization: Bearer <валидный_токен_тренера>"
# Ожидается 200, сезон и все его занятия пропадают из GET .../seasons

curl -X PUT http://144.31.189.154:8080/api/workouts/<workoutId> \
  -H "Authorization: Bearer <валидный_токен_тренера>" \
  -H "Content-Type: application/json" \
  -d '{"date": "2026-08-20"}'
# Ожидается 200, GET /api/workouts/<workoutId> отдаёт новую date
```

## После фикса

Дать знать — на Flutter-стороне после этого нужно:
- добавить `deleteSeason` в `api_service.dart` + кнопку удаления в
  `_SeasonCard` (`client_detail_screen.dart`, там же где уже есть кнопка
  изменения даты сезона — я её уже сделал в этой сессии)
- добавить `date` в `updateWorkout()` в `api_service.dart` + поле выбора даты
  в `WorkoutEditorScreen` (`workout_editor_screen.dart`) — сейчас там нет
  вообще никакого UI для даты, только notes и упражнения
