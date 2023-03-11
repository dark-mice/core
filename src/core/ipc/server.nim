import std/[asyncnet, asyncdispatch, tables, oids, strutils]
import ../emitter;
import ../bytearray;
import message;

type IPCConn = ref object
    channel: string
    socket: AsyncSocket

type IPCServer* = ref object
    requests: Table[string, proc(response: IPCMessage) {.closure.}]
    channels: Table[string, IPCConn]
    name*: string
    emitter*: Emitter
    socket: AsyncSocket

type NewChannel* = ref object of Event
    name*: string

proc send*(self: IPCServer, channel: string, message: string) {.async.} =
    if not self.channels.hasKey(channel):
        return;

    if self.channels[channel].socket.isClosed():
        self.channels.del(channel);
        return;

    let data = newByteArray();
    data.writeByte(2);
    data.writeString(self.name); # quem está enviando?
    data.writeString(channel); # quem está recebendo?
    data.writeString(message);

    data.writeBool(false); # é um pedido?

    await self.channels[channel].socket.send(data.toString() & "\r\n");

proc request*(self: IPCServer, channel: string, message: string): Future[IPCMessage] =
    var future = newFuture[IPCMessage]("request future");

    if not self.channels.hasKey(channel):
        future.complete(nil);
        return future;

    if self.channels[channel].socket.isClosed():
        self.channels.del(channel);
        future.complete(nil);
        return future;

    let uuid = $genOid();
    
    let data = newByteArray();
    data.writeByte(2);
    data.writeString(self.name);
    data.writeString(channel);
    data.writeString(message);

    data.writeBool(true);

    data.writeString(uuid);

    self.requests[uuid] = proc(response: IPCMessage) =
        future.complete(response);

    waitFor(self.channels[channel].socket.send(data.toString() & "\r\n"));

    return future;

proc parseData(self: IPCServer, conn: IPCConn, data: string) {.async.} =
    let packet = data.toByteArray();
    let token = packet.readByte();

    if token == 1 and conn.channel == "":
        conn.channel = packet.readString()
        self.channels[conn.channel] = conn;
        self.emitter.dispatchEvent("new-channel", NewChannel(name: conn.channel));

    elif token == 2 and conn.channel != "":
        let fromChannel = packet.readString();
        let toChannel = packet.readString();
        let message = packet.readString();
        let isRequest = packet.readBool();
        let uuid = if isRequest: packet.readString() else: ""

        if (toChannel == self.name):
            let ipcMessage = newIPCMessage(conn.socket, fromChannel, toChannel, isRequest, uuid, message);

            if isRequest and self.requests.hasKey(uuid):
                self.requests[uuid](ipcMessage);
                self.requests.del(uuid);    
                return;

            self.emitter.dispatchEvent("message", ipcMessage);
        elif self.channels.hasKey(toChannel):
            if not self.channels[toChannel].socket.isClosed():
                asyncCheck self.channels[toChannel].socket.send(data & "\r\n");

proc poll(self: IPCServer, socket: AsyncSocket) {.async.} =
    let conn = IPCConn(socket: socket, channel: "");

    while not socket.isClosed():
        let buffer = await socket.recv(256);

        if buffer == "":
            break;

        for data in buffer.split("\r\n"):
            if data.len() != 0:
                asyncCheck self.parseData(conn, data);

    for uuid, callback in self.requests:
        callback(nil)

    if self.channels.hasKey(conn.channel):
        self.channels.del(conn.channel)

proc listen(self: IPCServer) {.async.} =
    self.socket.listen();

    while not self.socket.isClosed():
        let socket = await self.socket.accept();
        asyncCheck self.poll(socket);

proc createIPCServer*(channel: string, port: Natural, host: string = "127.0.0.1"): IPCServer =
    let socket = newAsyncSocket(buffered=false);
    socket.setSockOpt(OptReuseAddr, true);
    socket.setSockOpt(OptKeepAlive, true);

    socket.bindAddr(Port(port), host);

    let iserver = IPCServer(
        requests: initTable[string, proc(response: IPCMessage) {.closure.}](),
        channels: initTable[string, IPCConn](),
        socket: socket,
        name: channel,
        emitter: createEmitter()
    )

    asyncCheck iserver.listen();

    return iserver;