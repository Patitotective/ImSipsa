import std/[os, logging, strformat]
import kdl, kdl/prefs
import ./utils

type
  Font* = tuple[size: int, name: string]
  Fuente* = tuple[ciudad, mercado: string]
  Prefs* = object
    titleFont*: Font
    paragraphFont*: Font
    legendFont*: Font
    fuentes*: seq[Fuente]
    ciudades*: seq[string]

proc findPrefsPath(): string =
  for kind, path in walkDir(getAppDir()):
    if kind != pcFile:
      continue

    let (dir, name, ext) = path.splitFile()
    if ext == ".kdl":
      if result.len > 0:
        fail "Se encontró más de un archivo .kdl y no debe haber más de un archivo .kdl"

      info &"Se dectecto el archivo {path}"
      result = path

let path = findPrefsPath()
let p = parseKdlFile(path)
echo p
