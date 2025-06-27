import std/[strformat, paths, strutils, logging, macros]

const NimblePkgVersion* {.strdefine.} = "Unknown"

proc quoted*(s: string): string =
  result.addQuoted(s)

proc contains*[V](a: openArray[V], values: varargs[V]): bool =
  ## Checks that a has all elements from values
  for v in values:
    if v notin a:
      return false

  return true

proc fail*(msg: string, level: Level = lvlFatal) =
  ## Log an exception and quit if it's fatal
  let e = getCurrentException()
  if e.isNil:
    log level, &"{msg}\n{getStackTrace().indent(2)}"
  else:
    log level, &"{msg}\n{getStackTrace().indent(2)}{e.msg} [{e.name}]"

  if level in [lvlAll, lvlFatal]:
    quit(QuitFailure)

proc setupLogging*(path: string) =
  const logFormat = "[$date $time] $levelname "

  var consoleLog = newConsoleLogger(fmtStr = logFormat)
  var rollingLog = newFileLogger(path, fmtStr = logFormat, mode = fmWrite)

  addHandler(consoleLog)
  addHandler(rollingLog)

  debug "Start v" & NimblePkgVersion

macro pretty*(a: typed): string =
  a.expectKind(nnkSym)
  let name = a.strVal

  quote:
    let ctx = newPrettyContext()
    ctx.highlight = false
    ctx.add(`name`, `a`)
    ctx.prettyString()
