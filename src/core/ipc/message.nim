import std/[asyncnet, asyncdispatch]
import ../emitter
import ../bytearray

type IPCMessage* = ref object of Event
    socket: AsyncSocket
    fromChannel*: string
    toChannel: string

    isRequest: bool
    uuid: string

    content*: string

proc newIPCMessage*(socket: AsyncSocket, fromChannel: string, toChannel: string, isRequest: bool, uuid: string, message: string): IPCMessage =
    IPCMessage(socket: socket, fromChannel: fromChannel, toChannel: toChannel, isRequest: isRequest, uuid: uuid, content: message)

proc reply*(self: IPCMessage, message: string) {.async.} =
    if self.socket.isClosed:
        return;

    let data = newByteArray();
    data.writeByte(2);
    data.writeString(self.toChannel); # quem está enviando?
    data.writeString(self.fromChannel); # quem está recebendo?
    data.writeString(message);

    data.writeBool(self.isRequest); # é um pedido?

    if self.isRequest:
        data.writeString(self.uuid);
        
    await self.socket.send(data.toString());