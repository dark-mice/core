import asyncdispatch

type ScheduleCall* = ref object
    future*: Future[void]
    ms*: int
    cancelled: bool

proc isFinished*(self: ScheduleCall): bool =
    return self.future.finished or self.cancelled or self.future.failed

proc isCancelled*(self: ScheduleCall): bool =
    return self.cancelled

proc cancel*(self: ScheduleCall) =
    self.cancelled = true
    self.future.complete()

proc scheduleTask(self: ScheduleCall, callback: proc()): Future[void] {.async.} =
    self.future = sleepAsync(self.ms)
    await self.future

    if not self.cancelled:
        callback()

proc scheduleTaskAsync(self: ScheduleCall, callback: proc() {.async.}): Future[void] {.async.} =
    self.future = sleepAsync(self.ms)
    await self.future

    if not self.cancelled:
        await callback()

proc scheduleCall*(callback: proc(), ms: int | float): ScheduleCall =
    let schedule = ScheduleCall(ms: ms, cancelled: false)
    asyncCheck scheduleTask(schedule, callback)
    return schedule

proc scheduleCall*(callback: proc() {.async.}, ms: int | float): ScheduleCall =
    let schedule = ScheduleCall(ms: ms, cancelled: false)
    asyncCheck scheduleTaskAsync(schedule, callback)
    return schedule