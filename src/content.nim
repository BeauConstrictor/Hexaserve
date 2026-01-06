import std/[os, strutils, tables, times]

import cache

# -------------------- #
#    GENERAL CONFIG   ##

const
  # map certain URLs on your server to files, so that filenames do not have to
  # be used as-is. You should generally always have a redirect for the homepage
  # ('/'), as is provided here.
  redirects = {
    "/": "index.gmi",
  }.toTable

  # how many a page can remain cached for before a full file lookup is required
  # this value should reflect somewhat how frequently you make changes to your
  # pages.
  cacheLifetimeMins = 5
  # how many pages can be cached as a maximum. if requests to your server are
  # slow enough that cacheLifetimeMins is frequently reached, the cache may
  # never hit this limit. If your server has low memory, reduce this value.
  cacheSize = 20

# -------------------- #

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

var
  pageCache = initLRUCache(readFile)

proc getPath(originalLocation: string): string =
  var location = originalLocation
  if originalLocation in redirects:
    location = redirects[originalLocation]

  location = location.strip(chars={'/'}, trailing=false)

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
    let chosenMinsAgo = epochTime() - cacheLifetimeMins*60
    pageCache.clean(maxItems=cacheSize)
    return (pageCache.get(path, oldest=chosenMinsAgo), scSuccess)
  except CatchableError:
    return (unhandledErrMsg, scUnhandledError)
