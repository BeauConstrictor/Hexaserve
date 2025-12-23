import std/[rdstdin]

import ../content

proc main() =
  while true:
    let location = readLineFromStdin("localhost/")
    let (page, status) = getPage(location)
    if status != scSuccess:
      echo "Abnormal status: " & ($status)[2..^1]
    echo page

if isMainModule:
  main()
