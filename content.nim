import std/[os, strutils, tables]

type
  PathTraversalError = object of ValueError

  statusCode* = enum
    scSuccess
    scNotFound
    scUnhandledError
    scAccessDenied

const
  unhandledErrMsg = staticRead("errs/unhandled.gmi")
  pathTraversalErrMsg = staticRead("errs/traversal.gmi")
  notFoundErrMsg = staticRead("errs/notfound.gmi")

const
  redirects = {
    "": "index.gmi",
  }.toTable

proc getPath(location: string): string =
  if ".." in location:
    raise newException(PathTraversalError, "'..' substring detected.")
  if location.startsWith("/"):
    raise newException(PathTraversalError, "'/' substring detected.")

  if location in redirects:
    return joinPath("content", redirects[location])
  else:
    return joinPath("content", location)

proc getPage*(location: string): (string, statusCode) =
  var path: string
  
  try:
    path = getPath(location)
  except PathTraversalError:
    return (pathTraversalErrMsg, scAccessDenied)

  if not fileExists(path):
    return (notFoundErrMsg, scNotFound)

  try:
    return (readFile(path), scSuccess)
  except CatchableError:
    return (unhandledErrMsg, scUnhandledError)
