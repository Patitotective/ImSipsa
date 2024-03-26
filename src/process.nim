import std/[strformat, strutils, tables, colors, os]

import excelin

type
  # Args = tuple[path, outPath, sheet, foodsCol, observCol: string, forbiddenTable: OrderedTable[string, seq[string]]]
  MsgKind* = enum
    mkData, mkError, mkFinished
  Msg* = object
    case kind*: MsgKind
    of mkData:
      pos*, food*, observ*: string
    of mkError:
      title*, msg*: string
    else: discard

# Global vars :skull:
var fromProcess*: Channel[Msg] # Don't forget to open and close the channel
# var processThread*: Thread[Args]

template uniform(str: string): string =
  str.strip().toLowerAscii().multiReplace(("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n"))

proc validateExcel*(path, outPath, sheetName, foodsCol, observCol: string, forbiddenTable: OrderedTable[string, seq[string]]) = #{.thread, nimcall.} =
  if not fileExists(path):
    fromProcess.send Msg(kind: mkError, title: "File not found", msg: &"Could not find {path}")
    return

  let excel = readExcel(path)
  let sheet = excel.getSheet(sheetName)

  if sheet.isNil:
    fromProcess.send Msg(kind: mkError, title: "Sheet not found", msg: &"Could not load {sheetName} sheet from {path}")
    return

  for row in sheet.rows:
    if row.rowNum == 1: continue # Skip headers row

    let foodCell = row.getCell[:string](foodsCol).uniform
    let observCell = row.getCell[:string](observCol).uniform

    block f:
      for food, observervations in forbiddenTable:
        if foodCell == food.uniform:
          for observ in observervations:
            if observ.uniform in observCell:
              # var foodFont = row.styleFont(foodsCol)
              # foodFont.color = $colRed

              row.style(foodsCol, fill = fillStyle(pattern = patternFillStyle(patternType = ptSolid, fgColor = $colRed)))
              row.copyStyle(foodsCol, &"{observCol}{row.rowNum}")

              fromProcess.send Msg(kind: mkData, pos: &"{foodsCol}{row.rowNum}", food: foodCell, observ: observ)
              break f

  excel.writeFile(outPath)
  fromProcess.send Msg(kind: mkFinished)

# proc startProcess*(args: Args) =
#   processThread.createThread(process, args)

