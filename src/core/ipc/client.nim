import std/[asyncnet, asyncdispatch, tables, oids, strutils]
import ../bytearray
import ../emitter
import message

type IPCClient* = ref object
    requests: Table[string, proc(response: IPCMessage) {.closure.}]
    socket: AsyncSocket
    name*: string
    emitter*: Emitter
    address: (string, Port)

proc send*(self: IPCClient, channel: string, message: string) {.async.} =
    if self.socket.isClosed:
        return;

    let data = newByteArray();
    data.writeByte(2);
    data.writeString(self.name); # quem está enviando?
    data.writeString(channel); # quem está recebendo?
    data.writeString(message);

    data.writeBool(false); # é um pedido?

    await self.socket.send(data.toString() & "\r\n");

proc request*(self: IPCClient, channel: string, message: string): Future[IPCMessage] =
    var future = newFuture[IPCMessage]("request future");

    if self.socket.isClosed:
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

    waitFor(self.socket.send(data.toString() & "\r\n"));

    return future;

proc parseData(self: IPCClient, data: string) {.async.} =
    let packet = data.toByteArray();
    let token = packet.readByte();

    if token == 2 and self.name != "":
        let fromChannel = packet.readString();
        let toChannel = packet.readString();
        let message = packet.readString();
        let isRequest = packet.readBool();
        let uuid = if isRequest: packet.readString() else: ""

        if (toChannel == self.name):
            let ipcMessage = newIPCMessage(self.socket, fromChannel, toChannel, isRequest, uuid, message);

            if isRequest and self.requests.hasKey(uuid):
                self.requests[uuid](ipcMessage);
                self.requests.del(uuid);    
                return;

            self.emitter.dispatchEvent("message", ipcMessage);

proc poll(self: IPCClient) {.async.} =
    while not self.socket.isClosed():
        let buffer = await self.socket.recv(256);

        if buffer == "":
            break;

        for data in buffer.split("\r\n"):
            if data.len() != 0:
                asyncCheck self.parseData(data);

    for uuid, callback in self.requests:
        callback(nil)

    echo "IPC Client: The connection was closed, trying to reconnect."

    try:
        let socket = newAsyncSocket(buffered=false);
        socket.setSockOpt(OptReuseAddr, true);
        socket.setSockOpt(OptKeepAlive, true);

        await socket.connect(self.address[0], self.address[1]);

        self.socket = socket

        let data = newByteArray();
        data.writeByte(1);
        data.writeString(self.name);

        await socket.send(data.toString() & "\r\n");

        echo "IPC Client: Reconnected."
    except:
        await sleepAsync(1000)

    asyncCheck self.poll()

proc createIPCClient*(channel: string, port: Natural, host: string = "127.0.0.1"): Future[IPCClient] {.async.} =
    try:
        let socket = newAsyncSocket(buffered=false);
        socket.setSockOpt(OptReuseAddr, true);
        socket.setSockOpt(OptKeepAlive, true);

        await socket.connect(host, Port(port));

        let data = newByteArray();
        data.writeByte(1);
        data.writeString(channel);

        await socket.send(data.toString() & "\r\n");

        let iclient = IPCClient(
            requests: initTable[string, proc(response: IPCMessage) {.closure.}](),
            socket: socket,
            name: channel,
            emitter: createEmitter(),
            address: (host, Port(port))
        )

        asyncCheck iclient.poll();

        return iclient;
    except:
        echo "IPC Client: Could not connect to server, trying again in 1s.";
        await sleepAsync(1000);
        return await createIPCClient(channel, port, host);