import std/[asyncnet, net, asyncdispatch];
import emitter

type Reactor* = ref object
  servers: seq[AsyncSocket]
  emitter*: Emitter

type ReactorError* = ref object of Event
  error*: ref Exception

type ReactorClient* = ref object of Event
  socket*: AsyncSocket

proc createReactor*(): Reactor =
  return Reactor(servers: @[], emitter: createEmitter());

proc listen*(self: Reactor, port: Natural, host: string = "127.0.0.1") =
    var server = newAsyncSocket(buffered=false);
    server.setSockOpt(OptReuseAddr, true);
    server.setSockOpt(OptKeepAlive, true);

    try:
      server.bindAddr(Port(port), host);
      self.servers.add(server);
    except Exception as error:
      self.emitter.dispatchEvent("error", ReactorError(error: error));

proc startServer(server: AsyncSocket, reactor: Reactor) {.async.} =
  try:
    server.listen();
  except Exception as error:
    reactor.emitter.dispatchEvent("error", ReactorError(error: error));
    return;

  while true:
    let socket = await server.accept();
    reactor.emitter.dispatchEvent("newclient", ReactorClient(socket: socket));

proc start*(self: Reactor, blocking: bool = true) =
  for server in self.servers:
    asyncCheck server.startServer(self);

  self.emitter.dispatchEvent("ready", Event());

  if self.servers.len() > 0 and blocking:
    runForever();