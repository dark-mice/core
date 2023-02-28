import std/[tables, async]

type Event* = ref object of RootObj;

type Emitter* = ref object
  handlers: Table[string, seq[proc(event: Event) {.closure.}]]
  asyncHandlers: Table[string, seq[proc(event: Event) {.closure, async.}]]

proc createEmitter*(): Emitter =
  return Emitter(handlers: initTable[string, seq[proc(event: Event)]]());

proc addEventListener*(self: Emitter, event: string, handler: proc(event: Event) {.closure.}) =
    if not self.handlers.hasKey(event):
        self.handlers[event] = @[];

    self.handlers[event].add(handler);

proc addEventListener*(self: Emitter, event: string, handler: proc(event: Event) {.closure, async.}) =
    if not self.asyncHandlers.hasKey(event):
        self.asyncHandlers[event] = @[];

    self.asyncHandlers[event].add(handler);

proc removeEventListener*(self: Emitter, event: string) =
    if self.handlers.hasKey(event):
        self.handlers.clear();

    if self.asyncHandlers.hasKey(event):
        self.asyncHandlers.clear();

proc removeEventListener*(self: Emitter, event: string, handler: proc(event: Event) {.closure.}) =
    if self.handlers.hasKey(event):
        self.handlers[event].del(self.handlers[event].find(handler));

proc removeEventListener*(self: Emitter, event: string, handler: proc(event: Event) {.closure, async.}) =
    if self.asyncHandlers.hasKey(event):
        self.asyncHandlers[event].del(self.asyncHandlers[event].find(handler));

proc dispatchEvent*(self: Emitter, event: string, args: Event) =
    if self.handlers.hasKey(event):
        for handler in self.handlers[event]:
            handler(args);

    if self.asyncHandlers.hasKey(event):
        for handler in self.asyncHandlers[event]:
            asyncCheck handler(args);