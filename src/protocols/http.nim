import std/[net, uri, logging, strutils]

import ../content

const
  htmlTemplate = staticRead("../template.html")

var
  consoleLogger = newConsoleLogger()
  fileLog = newFileLogger("logs/gemini.txt", levelThreshold=lvlError) 

proc getStatusNumber(status: statusCode): string =
  return case status:
    of scSuccess: "200 OK"
    of scNotFound: "404 Not Found"
    of scAccessDenied: "403 Forbidden"
    of scUnhandledError: "500 Internal Server Error"

proc handleBadRequest(client: Socket) =
  client.send("HTTP/1.1 400 Bad Request\r\n")
  client.send("Content-Type: text/plain\r\n")
  client.send("Content-Length: 13\r\n")
  client.send("Connection: close\r\n")
  client.send("\r\n")
  client.send("400 Bad Request\r\n")
  client.close()
proc handleInvalidVersion(client: Socket) =
  client.send("HTTP/1.1 505 HTTP Version Not Supported\r\n")
  client.send("Content-Type: text/plain\r\n")
  client.send("Content-Length: 34\r\n")
  client.send("Connection: close\r\n")
  client.send("\r\n")
  client.send("That http version is not supported by this server.\r\n")
  client.close()
proc handleInvalidMethod(client: Socket) =
  client.send("HTTP/1.1 405 Method Not Allowed\r\n")
  client.send("Content-Type: text/plain\r\n")
  client.send("Content-Length: 22\r\n")
  client.send("Connection: close\r\n")
  client.send("Allow: GET, POST\r\n")
  client.send("\r\n")
  client.send("Method Not Allowed\r\n")
  client.close()

proc generateHtml(page: string): string =
  var article = ""
  var preformatted = false
  var lastLineWasAListItem = false

  for line in page.split("\n"):
    if lastLineWasAListItem and not (line.startsWith("=> ") or line.startsWith("* ")):
      article &= "</ul>\n"
      lastLineWasAListItem = false

    if line.startsWith("```") and not preformatted:
      preformatted = true
      article &= "<pre>\n"
    elif line.startsWith("```") and preformatted:
      preformatted = false
      article &= "</pre>\n"
    elif preformatted:
      article &= line & "\n"
    elif line.startsWith("# "):
      article &= "<h1>" & line[2..^1] & "</h1>\n"
    elif line.startsWith("## "):
      article &= "<h2>" & line[3..^1] & "</h2>\n"
    elif line.startsWith("### "):
      article &= "<h3>" & line[4..^1] & "</h3>\n"
    elif line.startsWith("=> "):
      if not lastLineWasAListItem:
        lastLineWasAListItem = true
        article &= "<ul>\n"
      let parts = line.split(" ")
      article &= "<li><a href=\"" & parts[1] & "\">" & parts[2..^1].join(" ") & "</a></li>\n"
    else:
      article &= "<p>" & line & "</p>\n"

  result = htmlTemplate.replace("$CONTENT", article)
  result = result.replace("$TITLE", page.split("\n")[0].replace("# ", ""))

proc handleClient(client: Socket, address: string) =
  try:

    let requestLine = client.recvLine(timeout=1000, maxLength=1024).split(" ")
    if requestLine.len() != 3:
      handleBadRequest(client)
      return
    if requestLine[2] != "HTTP/1.1":
      handleInvalidVersion(client)
      return
    if requestLine[0] != "GET":
      handleInvalidMethod(client)
      return

    let path = requestLine[1]
    let (page, status) = getPage(path)
    let statusLine = getStatusNumber(status)

    info("[REQUEST] " & address & " " & path)

    let html = generateHtml(page)

    client.send("HTTP/1.1 " & statusLine & "\r\n")
    client.send("Content-Type: text/html\r\n")
    client.send("Connection: close\r\n")
    client.send("Content-Length: " & $len(html) & "\r\n")
    client.send("\r\n")
    client.send(html)

  except CatchableError as err:
    error("[REQUEST/RESPONSE] " & err.msg)
  finally:
    client.close()

proc startServer() =
  let socket = newSocket()
  socket.setSockOpt(OptReuseAddr, true)

  socket.bindAddr(Port(8080))
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
