# ------------------- #
#    GOPHER CONFIG    #

const
  port = 70
  host = "localhost"

# =------------------ #

import std/[asyncdispatch, asyncnet, strutils, logging, uri]

import ../content


var
  consoleLogger = newConsoleLogger(fmtStr="GOPHER/$levelname ")
  fileLog = newFileLogger("logs/gopher.txt", levelThreshold=lvlError)

proc wrap(text: string, width: int): string =
  var lines = newSeq[string]()
  var inCodeBlock = false

  for line in text.splitLines():
    if line.startsWith("```"):
      inCodeBlock = not inCodeBlock
      lines.add(line)
      continue

    if inCodeBlock:
      lines.add(line)
      continue

    if line.strip() == "":
      lines.add("")
      continue

    var isGemLink = line.startsWith("=>")
    var prefix = ""
    var content = line

    if isGemLink:
      let parts = line.splitWhitespace()
      if parts.len >= 2:
        prefix = parts[0] & " " & parts[1] & " "
        content = parts[2 .. ^1].join(" ")
      else:
        lines.add(line)
        continue

    var currentLine = ""

    for word in content.splitWhitespace():
      if currentLine.len + word.len + (if currentLine.len > 0: 1 else: 0) > width:
        if currentLine.len > 0:
          lines.add(prefix & currentLine)
        currentLine = word
      else:
        if currentLine.len > 0:
          currentLine.add(" ")
        currentLine.add(word)

    if currentLine.len > 0:
      if isGemLink:
        lines.add(prefix & currentLine)
      else:
        lines.add(currentLine)

  return lines.join("\n")

proc translateToGophermap(gemtext: string): string =
  for line in gemtext.wrap(70).split("\n"):
    if line.startsWith("```"):
      result &= "i\r\n"
    elif line.startsWith("=> "):
      let parts = line.split(" ")

      let target = parts[1]
      let url = parseUri(target)
      var name = target
      if parts.len() > 2:
        name = parts[2..^1].join(" ")

      if url.scheme == "gopher":
        var port = url.port
        if port == "": port = "70"

        result &= "1" & name & "\t" & url.path & "\t" & url.hostname & "\t"
        result &= port & "\r\n"
      elif url.isAbsolute():
        var port = url.port
        if port == "": port = "70"
        result &= "h" & name & "\tURL:" & $url & "\t" & url.hostname & "\t" 
        result &= port & "\r\n"
      else:
        result &= "1" & name & "\t" & target & "\t" & host & "\t" & $port
        result &= "\r\n"
    elif line.startsWith("# "):
      let text = line[2..^1]
      result &= "i" & "#".repeat(text.len()) & "\tfake\t(NULL)\t0\r\n"
      result &= "i" & text  & "\tfake\t(NULL)\t0\r\n"
      result &= "i" & "#".repeat(text.len()) & "\tfake\t(NULL)\t0\r\n"
    elif line.startsWith("## "):
      let text = line[3..^1]
      result &= "i" & "=".repeat(text.len()) & "\tfake\t(NULL)\t0\r\n"
      result &= "i" & text  & "\tfake\t(NULL)\t0\r\n"
      result &= "i" & "=".repeat(text.len()) & "\tfake\t(NULL)\t0\r\n"
    elif line.startsWith("### "):
      let text = line[4..^1]
      result &= "i" & text  & "\tfake\t(NULL)\t0\r\n"
      result &= "i" & "-".repeat(text.len()) & "\tfake\t(NULL)\t0\r\n"
    else:
      result &= "i" & line & "\tfake\t(NULL)\t0\r\n"

  result &= ".\r\n"

proc handleClient(client: AsyncSocket, address: string) {.async.} =
  try:

    let path = "/" & (await client.recvLine(maxLength=1024)).strip()
    let (gemtext, _) = getPage(path)
    let page = gemtext.translateToGophermap()

    info("[REQUEST]          " & address & " " & path)

    await client.send(page)

  except CatchableError as err:
    error("[REQUEST/RESPONSE] " & err.msg)
  finally:
    client.close()

proc startServer() {.async.} =
  let socket = newAsyncSocket()
  socket.setSockOpt(OptReuseAddr, true)

  socket.bindAddr(Port(port))
  socket.listen()

  info("[START]            Listening on port " & $port)

  while true:
    let (address, client) = await socket.acceptAddr(flags={SafeDisconn})
    await handleClient(client, address)

if isMainModule:
  addHandler(consoleLogger)
  addHandler(fileLog)
  asyncCheck startServer()
  runForever()
