import std/[os, logging, strformat]
import kdl, kdl/prefs as kdlprefs
import ./utils

type
  Font* = tuple[name: string, size: float]
  Fuente* = tuple[ciudad, mercado: string]
  Prefs* = object
    dateFormat*: string
    titleFont*: Font
    paragraphFont*: Font
    legendFont*: Font
    thirdParagraph*: string
    tenthParagraph*: string
    eleventhParagraph*: seq[string]
    fuentes*: seq[Fuente]
    ciudades*: seq[string]

const default =
  """
dateFormat "d/M/yyyy" // Más información en https://nim-lang.org/docs/times.html#parsing-and-formatting-dates

// Nombre Tamaño
titleFont "Segoe UI" 14
paragraphFont "Segoe UI" 11
legendFont "Segoe UI" 10
thirdParagraph "Gráfico 4. Abastecimiento diario de alimentos de las últimas dos semanas"
tenthParagraph "Revisando el acopio entre la semana 1 y la semana 8 de los últimos tres años, el abastecimiento del presente año se encuentra por encima de los periodos anteriores, y específicamente la octava semana del año aumentó 14,03% con respecto a la misma semana de 2023 y 20,95% frente al 2022."
eleventhParagraph {
  - "Gráfico 5. Abastecimiento semanal de alimentos de los últimos tres años"
  - "32 mercados mayoristas"
  - "Semana X a la Y de 2024, 2025 y 2026"
}

fuentes {
    // Ciudad Mercado
    Armenia "Mercar"
    Barranquilla "Barranquillita"
    Barranquilla "Granabastos"
    "Bogotá, D.C." "Corabastos"
    "Bogotá, D.C." "Paloquemao"
    "Bogotá, D.C." "Plaza Las Flores"
    "Bogotá, D.C." "Plaza Samper Mendoza"
    Bucaramanga "Centroabastos"
    Cali "Cavasa"
    Cali "Santa Elena"
    Cartagena "Bazurto"
    Cúcuta "Cenabastos"
    Cúcuta "La Nueva Sexta"
    "Florencia (Caquetá)" ""
    Ibagué "Plaza La 21"
    "Ipiales (Nariño)" "Centro de acopio"
    Manizales "Centro Galerías"
    Medellín "Central Mayorista de Antioquia"
    Medellín "Plaza Minorista \"José María Villa\""
    Montería "Mercado del Sur"
    Neiva "Surabastos"
    Pereira "La 41-Impala"
    Pereira "Mercasa"
    Pasto "El Potrerillo"
    Popayán "Plaza de mercado del barrio Bolívar"
    "Santa Marta (Magdalena)" ""
    Sincelejo "Nuevo Mercado"
    "Tibasosa (Boyacá)" "Coomproriente"
    Tunja "Complejo de Servicios del Sur"
    Valledupar "Mercabastos"
    Valledupar "Mercado Nuevo"
    Villavicencio "CAV"
}
"""

proc decodeKdl*(a: KdlNode, v: var Fuente) =
  assert a.args.len == 1,
    &"Cada Fuente debe tener la ciudad en el nombre y un argumento que es el mercado: {system.`$`(a)}"
  v = (ciudad: a.name, mercado: a.args[0].getString())

proc decodeKdl*(a: KdlNode, v: var Font) =
  assert a.args.len == 2,
    &"Cada Font debe tener dos argumentos (nombre y tamaño): {system.`$`(a)}"
  v = (name: a.args[0].getString(), size: a.args[1].get(float))

proc findPrefsPath(): string =
  for kind, path in walkDir(getAppDir()):
    if kind != pcFile:
      continue

    let (dir, name, ext) = path.splitFile()
    if ext == ".kdl":
      if result.len > 0:
        fail "Se encontró más de un archivo .kdl y no debe haber más de un archivo .kdl"

      info &"Se dectecto el archivo de preferencias {path}"
      result = path

proc readPrefs*(): Prefs =
  let path = findPrefsPath()
  if path.len == 0:
    info "No se encotró el archivo de preferencias, generándolo con los valores por defecto"
    writeFile(getAppDir() / "prefs.kdl", default)
    result = parseKdl(default).decodeKdl(Prefs)
  else:
    result = parseKdlFile(path).decodeKdl(Prefs)

  assert result.eleventhParagraph.len == 3, "eleventhParagraph debe tener 3 hijos"

  result.ciudades = block:
    var s: seq[string]
    for (ciudad, mercado) in result.fuentes:
      if ciudad notin s:
        s.add ciudad
    s
