import std/[strformat, strutils, tables, os, parsecsv]

template uniform(str: string): string =
  str.strip().toLowerAscii().multiReplace(
    ("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n")
  )

proc headerToLetter(p: CsvParser, header: string): string =
  for e, h in p.headers:
    if h == header:
      result.add char('A'.int + e)

proc validateExcelAlimentos*(
    path, foodsCol, observCol: string, forbiddenTable: OrderedTable[string, seq[string]]
) =
  if not fileExists(path):
    fail &"No se pudo encontrar el archivo {path}"
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
              let pos = &"{foodsColLetter}{rowNum + 1}"
              info "{pos}: Alimento {foodVal} contiene {observVal}"
              break f

    inc rowNum

when isMainModule:
  {.error: "This module is not ready to be used directly".}
