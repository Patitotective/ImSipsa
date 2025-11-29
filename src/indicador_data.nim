import std/[times, sets, strformat, tables, strutils, encodings, monotimes, logging]
import datamancer
import arraymancer
import pretty
import ./[utils, prefsfile]

type Grupo* = enum
  gVerdHort = "verduras y hortalizas"
  gTubRaiPla = "tubérculos, raíces y plátanos"
  gFrutas = "frutas"
  gOtros = "otros grupos"
    # granos y cereales; lácteos y huevos; pescados; procesados; carnes

const
  grupos* = [ # Not uniformed (with accents)
    "verduras y hortalizas",
    "tubérculos, raíces y plátanos",
    "frutas",
    "granos y cereales",
    "lácteos y huevos",
    "pescados",
    "procesados",
    "carnes", # Otros
  ]
  gruposToEnum* = { # Uniformed (without accents)
    "verduras y hortalizas": gVerdHort,
    "tuberculos, raices y platanos": gTubRaiPla,
    "frutas": gFrutas,
    "granos y cereales": gOtros,
    "lacteos y huevos": gOtros,
    "pescados": gOtros,
    "procesados": gOtros,
    "carnes": gOtros,
  }.toTable

proc uniform(str: string): string =
  str.strip().toLowerAscii().multiReplace(
    ("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n")
  )

proc processDataIndicador*(inputPath: string, prefs: Prefs): auto =
  let startTime = getMonoTime()

  var df = parseCsvString(
    readFile(inputPath).convert(destEncoding = "UTF-8", srcEncoding = "CP1252"),
    sep = ';',
    quote = '\0',
  )

  for column in [
    "Fuente", "FechaEncuesta", "HoraEncuesta", "TipoVehiculo", "PlacaVehiculo",
    "Divipola Depto Proc.", "Departamento",
    "Divipola Municipio / ISO 3166-1 País Proc.",
    "Municipio de Colombia / País Proc.", "Observaciones", "Grupo", "Codigo CPC",
    "Ali", "Cant Pres", "Pres", "Peso Pres", "Cant Kg",
  ]:
    assert column in df, &"La columna \"{column}\" no existe"

  df = df.mutate(f{"Cant Kg" ~ c"Cant Kg".replace(',', '.').parseFloat()})

  {.cast(gcsafe).}:
    let dateCol = df["FechaEncuesta"]
    let firstWeekStart = dateCol[0, string].parse(prefs.dateFormat)
    let secondWeekEnd = dateCol[dateCol.high, string].parse(prefs.dateFormat)
  let firstWeekEnd = firstWeekStart + 6.days
  let secondWeekStart = secondWeekEnd - 6.days

  assert inDays(secondWeekEnd - firstWeekStart) == 13,
    &"Entre el primer y último registro no hay dos semanas, hay {{inDays(secondWeekEnd - firstWeekStart)}} días"
    # Two weeks, not 14 since subtracting doesn't include secondWeekEnd
  {.cast(gcsafe).}:
    let firstWeekDf = df.filter(
      f{
        string -> bool:
          inDays(idx(`FechaEncuesta`).parse(prefs.dateFormat) - firstWeekStart) < 7
      }
    )
    let secondWeekDf = df.filter(
      f{
        string -> bool:
          inDays(secondWeekEnd - idx(`FechaEncuesta`).parse(prefs.dateFormat)) < 7
      }
    )
    let firstWeekTotalKg = firstWeekDf["Cant Kg", float].sum
    let secondWeekTotalKg = secondWeekDf["Cant Kg", float].sum

    # var firstWeekTotalKg, secondWeekTotalKg: float
    # try:
    #   firstWeekTotalKg = firstWeekDf["Cant Kg", float].sum
    #   secondWeekTotalKg = secondWeekDf["Cant Kg", float].sum
    # except Exception:
    #   fail $df["Cant Kg", string]
  let weeksKgDifference =
    ((secondWeekTotalKg - firstWeekTotalKg) / firstWeekTotalKg) * 100 # Percentage

  info pretty weeksKgDifference

  proc parseGrupo(input: string): Grupo =
    let grupo = input.uniform
    assert grupo in gruposToEnum, &"{grupo=}"
    gruposToEnum[grupo]

  proc sumGrupos(df: DataFrame): Table[Grupo, float] =
    for g in Grupo:
      result[g] = 0
    {.cast(gcsafe).}:
      for t, subDf in groups df.group_by("Grupo"):
        assert t.len == 1, &"{t.len=}" # Since it was only grouped_by one column
        assert t[0][1].kind == VString, &"{t[0][1].kind=}"

        let grupo = t[0][1].toStr.parseGrupo() # t[0][1] would be each grupo
        result[grupo] += subDf["Cant Kg", float].sum

  let firstWeekGruposTotalKg = firstWeekDf.sumGrupos()
  let secondWeekGruposTotalKg = secondWeekDf.sumGrupos()

  var weeksGruposDifference = initTable[Grupo, float]() # Percentage per grupo
  for grupo, total in firstWeekGruposTotalKg:
    assert grupo in secondWeekGruposTotalKg, &"{grupo=}"
    weeksGruposDifference[grupo] =
      ((secondWeekGruposTotalKg[grupo] - total) / total) * 100

  info pretty weeksGruposDifference

  proc parseFuente(input: string): Fuente =
    var input = input
    # This is to parse things like "Medellín, Plaza Minorista ""José María Villa"""
    if input.len > 0 and input[0] == '"':
      input = input[1 ..^ 2]
      input = input.replace("\"\"", "\"")

    let fuenteSplit = input.rsplit(", ", maxsplit = 1)
    assert fuenteSplit.len in 1 .. 2, &"{fuenteSplit=}"

    result =
      if fuenteSplit.len == 2:
        (ciudad: fuenteSplit[0], mercado: fuenteSplit[1])
      else:
        (ciudad: fuenteSplit[0], mercado: "")

    if result.ciudad == "Cali" and result.mercado == "Santa Helena":
      result.mercado = "Santa Elena"

  proc sumFuentesAndCiudades(
      df: DataFrame
  ): tuple[fuentes: Table[Fuente, float], ciudades: Table[string, float]] =
    for f in prefs.fuentes:
      result.fuentes[f] = 0

    for c in prefs.ciudades:
      result.ciudades[c] = 0
    {.cast(gcsafe).}:
      for t, subDf in groups df.group_by("Fuente"):
        assert t.len == 1, &"{t.len=}" # Since it was only grouped_by one column
        assert t[0][1].kind == VString, &"{t[0][1].kind=}"

        let fuente = t[0][1].toStr.parseFuente() # t[0][1] would be each fuente
        result.fuentes[fuente] += subDf["Cant Kg", float].sum
        result.ciudades[fuente.ciudad] += subDf["Cant Kg", float].sum

  let (firstWeekFuentesTotalKg, firstWeekCiudadesTotalKg) =
    firstWeekDf.sumFuentesAndCiudades()
  let (secondWeekFuentesTotalKg, secondWeekCiudadesTotalKg) =
    secondWeekDf.sumFuentesAndCiudades()

  var weeksFuentesDifference = initTable[Fuente, float]() # Percentage per fuente
  for fuente, total in firstWeekFuentesTotalKg:
    assert fuente in secondWeekFuentesTotalKg, &"{fuente=}"
    weeksFuentesDifference[fuente] =
      ((secondWeekFuentesTotalKg[fuente] - total) / total) * 100

  info pretty weeksFuentesDifference

  var weeksCiudadesDifference = initTable[string, float]() # Percentage per fuente
  for ciudad, total in firstWeekCiudadesTotalKg:
    assert ciudad in secondWeekCiudadesTotalKg, &"{ciudad=}"
    weeksCiudadesDifference[ciudad] =
      ((secondWeekCiudadesTotalKg[ciudad] - total) / total) * 100

  info pretty weeksCiudadesDifference

  proc sumFuentesAndCiudadesGrupos(
      df: DataFrame
  ): tuple[
    fuentes: Table[Fuente, Table[Grupo, float]],
    ciudades: Table[string, Table[Grupo, float]],
  ] =
    for f in prefs.fuentes:
      result.fuentes[f] = initTable[Grupo, float]()
      for g in Grupo:
        result.fuentes[f][g] = 0

    for c in prefs.ciudades:
      result.ciudades[c] = initTable[Grupo, float]()
      for g in Grupo:
        result.ciudades[c][g] = 0

    {.cast(gcsafe).}:
      for t, subDf in groups(df.group_by(["Fuente", "Grupo"])):
        assert t.len == 2, &"{t.len=}" # Since it was grouped_by two columns

        assert t[0][1].kind == VString, &"{t[0][1].kind=}"
        assert t[1][1].kind == VString, &"{t[0][1].kind=}"

        let fuente = t[0][1].toStr.parseFuente() # t[0][1] would be each fuente
        let grupo = t[1][1].toStr.parseGrupo() # t[0][1] would be each grupo
        result.fuentes[fuente][grupo] += subDf["Cant Kg", float].sum
        result.ciudades[fuente.ciudad][grupo] += subDf["Cant Kg", float].sum

  let (firstWeekFuentesGruposTotalKg, firstWeekCiudadesGruposTotalKg) =
    firstWeekDf.sumFuentesAndCiudadesGrupos()
  let (secondWeekFuentesGruposTotalKg, secondWeeksCiudadesGruposTotalKg) =
    secondWeekDf.sumFuentesAndCiudadesGrupos()

  var weeksFuentesGruposDifference = initTable[Fuente, Table[Grupo, float]]()
    # Percentage per fuente and grupo
  for fuente, grupos in firstWeekFuentesGruposTotalKg:
    assert fuente in secondWeekFuentesGruposTotalKg, &"{fuente=}"
    weeksFuentesGruposDifference[fuente] = initTable[Grupo, float]()
    for grupo, total in grupos:
      assert grupo in secondWeekFuentesGruposTotalKg[fuente], &"{fuente=} {grupo=}"
      weeksFuentesGruposDifference[fuente][grupo] =
        ((secondWeekFuentesGruposTotalKg[fuente][grupo] - total) / total) * 100

  info pretty weeksFuentesGruposDifference

  var weeksCiudadesGruposDifference = initTable[string, Table[Grupo, float]]()
    # Percentage per ciudad and grupo
  for ciudad, grupos in firstWeekCiudadesGruposTotalKg:
    assert ciudad in secondWeeksCiudadesGruposTotalKg, &"{ciudad=}"
    weeksCiudadesGruposDifference[ciudad] = initTable[Grupo, float]()
    for grupo, total in grupos:
      assert grupo in secondWeeksCiudadesGruposTotalKg[ciudad], &"{ciudad=} {grupo=}"
      #if total == 0 and secondWeeksCiudadesGruposTotalKg[ciudad][grupo] == 0:
      #  continue
      weeksCiudadesGruposDifference[ciudad][grupo] =
        ((secondWeeksCiudadesGruposTotalKg[ciudad][grupo] - total) / total) * 100

  info pretty firstWeekCiudadesGruposTotalKg
  info pretty secondWeeksCiudadesGruposTotalKg
  info pretty weeksCiudadesGruposDifference

  proc sumWeekdays(df: DataFrame): Table[WeekDay, float] =
    for i in WeekDay:
      result[i] = 0

    {.cast(gcsafe).}:
      for t, subDf in groups(df.group_by("FechaEncuesta")):
        assert t.len == 1, &"{t.len=}" # Since it was only grouped_by one column

        assert t[0][1].kind == VString, &"{t[0][1].kind=}"

        let fecha = t[0][1].toStr.parse(prefs.dateFormat)
          # t[0][1] would be each FechaEncuesta
        result[fecha.weekday] += subDf["Cant Kg", float].sum

  let firstWeekWeekdaysTotalKg = firstWeekDf.sumWeekdays()
  let secondWeekWeekdaysTotalKg = secondWeekDf.sumWeekdays()

  var weeksWeekdaysDifference = initTable[WeekDay, float]() # Percentage per weekday
  for weekday, total in firstWeekWeekdaysTotalKg:
    assert weekday in secondWeekWeekdaysTotalKg, &"{weekday=}"
    weeksWeekdaysDifference[weekday] =
      ((secondWeekWeekdaysTotalKg[weekday] - total) / total) * 100

  info pretty weeksWeekdaysDifference
  info &"Procesando los datos se demoró {getMonoTime() - startTime}"

  (
    firstWeekStart: firstWeekStart,
    secondWeekEnd: secondWeekEnd,
    firstWeekEnd: firstWeekEnd,
    secondWeekStart: secondWeekStart,
    firstWeekTotalKg: firstWeekTotalKg,
    secondWeekTotalKg: secondWeekTotalKg,
    weeksKgDifference: weeksKgDifference,
    firstWeekGruposTotalKg: firstWeekGruposTotalKg,
    secondWeekGruposTotalKg: secondWeekGruposTotalKg,
    weeksGruposDifference: weeksGruposDifference,
    weeksFuentesDifference: weeksFuentesDifference,
    weeksCiudadesDifference: weeksCiudadesDifference,
    weeksFuentesGruposDifference: weeksFuentesGruposDifference,
    weeksCiudadesGruposDifference: weeksCiudadesGruposDifference,
    weeksWeekdaysDifference: weeksWeekdaysDifference,
  )
