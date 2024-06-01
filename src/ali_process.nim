import std/[strformat, strutils, tables, os, parsecsv]

type
  # Args = tuple[path, outPath, sheet, foodsCol, observCol: string, forbiddenTable: OrderedTable[string, seq[string]]]
  MsgKind* = enum
    mkData, mkError, mkFinished
  Msg* = object
    case kind*: MsgKind
    of mkData:
      pos*, food*, observ*: string
    of mkError:
      msg*: string
    else: discard

# Global vars :skull:
var aliChannel*: Channel[Msg] # Don't forget to open and close the channel
# var processThread*: Thread[Args]

template uniform(str: string): string =
  str.strip().toLowerAscii().multiReplace(("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n"))

proc headerToLetter(p: CsvParser, header: string): string = 
  for e, h in p.headers:
      if h == header:
        result.add char('A'.int + e)

proc validateExcel*(path, foodsCol, observCol: string, 
  forbiddenTable: OrderedTable[string, seq[string]]) {.thread.} =
  
  if not fileExists(path):
    aliChannel.send Msg(kind: mkError, msg: &"No se pudo encontrar el archivo {path}")
    return
  
  var p: CsvParser

  p.open(path, separator = ';')
  p.readHeaderRow()

  let foodsColLetter = p.headerToLetter(foodsCol)

  var rowNum = 1

  while p.readRow():
    let foodVal = p.rowEntry(foodsCol).uniform
    let observVal = p.rowEntry(observCol).uniform

    block f:
      for food, observervations in forbiddenTable:
        if foodVal == food.uniform:
          for observ in observervations:
            if observ.uniform in observVal:
              aliChannel.send Msg(kind: mkData, pos: &"{foodsColLetter}{rowNum + 1}", food: foodVal, observ: observ)
              break f
  
    inc rowNum
  
  aliChannel.send Msg(kind: mkFinished)

# proc startProcess*(args: Args) =
#   processThread.createThread(process, args)

