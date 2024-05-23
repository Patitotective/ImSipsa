import std/[strformat, strutils, tables, os, enumerate]

import xl

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

const colorRed = XlColor(rgb: "FF0000")

# Global vars :skull:
var fromProcess*: Channel[Msg] # Don't forget to open and close the channel
# var processThread*: Thread[Args]

template uniform(str: string): string =
  str.strip().toLowerAscii().multiReplace(("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n"))

proc validateExcel*(path, outPath, sheetName, foodsCol, observCol: string, 
  forbiddenTable: OrderedTable[string, seq[string]]) {.thread, nimcall.} =
  if not fileExists(path):
    fromProcess.send Msg(kind: mkError, title: "Archivo no encontrado", msg: &"No se pudo encontrar {path}")
    return

  let workbook = xl.load(path)
  let sheet = workbook.sheet(sheetName)

  if sheet.isNil:
    fromProcess.send Msg(kind: mkError, title: "Hoja no encontrada", msg: &"No se pudo cargar la hoja {sheetName} en el archivo {path}")
    return

  for rowNum, row in enumerate sheet.rows:
    if rowNum == 0: continue # Skip headers row

    let foodCell = row.cell(foodsCol).value.uniform
    let observCell = row.cell(observCol).value.uniform

    block f:
      for food, observervations in forbiddenTable:
        if foodCell == food.uniform:
          for observ in observervations:
            if observ.uniform in observCell:

              row.cell(foodsCol).style = XlStyle(fill: XlFill(patternFill: XlPattern(patternType: "solid", fgColor: colorRed)))
              row.cell(observCol).style = row.cell(foodsCol).style

              fromProcess.send Msg(kind: mkData, pos: &"{foodsCol}{rowNum}", food: foodCell, observ: observ)
              break f

  {.cast(gcsafe).}:
    workbook.save(outPath)
  fromProcess.send Msg(kind: mkFinished)

# proc startProcess*(args: Args) =
#   processThread.createThread(process, args)

