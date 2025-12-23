import std/[net, uri, logging]

import ../content

var
  consoleLogger = newConsoleLogger()
  fileLog = newFileLogger("logs/gemini.txt", levelThreshold=lvlError)

proc handleClient(client: Socket, address: string) =
  try:

    client.send("\e[2J\e[H\n")
    client.send("\nWelcome to BeauConstrictor's Place!\n")
    client.send("To visit a page, just enter its path (what you would see " &
                 "after the hostname in a URL).\n")
    client.send("\e[H\e[2K\e[G")
    client.send("Enter a path to visit: ")

    while true:
      let urlText = client.recvLine()
      let url = parseUri(decodeUrl(urlText))
      let (page, _) = getPage(url.path)

      info("[REQUEST] " & address & " " & url.path)

      client.send("\e[2J\e[H\n\n")
      client.send(page)
      client.send("\e[H\e[2K\e[G")
      client.send("Enter a path to visit: ")

  except CatchableError as err:
    error("[REQUEST/RESPONSE] " & err.msg)
  finally:
    client.close()
  
proc startServer() =
  let socket = newSocket()
  socket.setSockOpt(OptReuseAddr, true)

  socket.bindAddr(Port(2323))
  socket.listen()

  while true:
    var client: Socket
    var address = ""
    socket.acceptAddr(client, address, flags={SafeDisconn})
    handleClient(client, address)

if isMainModule:
  addHandler(consoleLogger)
  addHandler(fileLog)
  startServer()
