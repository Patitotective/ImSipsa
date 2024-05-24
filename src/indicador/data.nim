import std/[times, sets, strformat, tables, strutils, encodings, os, monotimes]
import datamancer
import arraymancer
import pretty

type
  Grupo* = enum
    gVerdHort = "verduras y hortalizas"
    gTubRaiPla = "tubérculos, raíces y plátanos"
    gFrutas = "frutas"
    gOtros = "otros grupos" # granos y cereales; lácteos y huevos; pescados; procesados; carnes

  Fuente* = tuple[ciudad, mercado: string]

  MessageKind* = enum
    mkInfo, mkFinishData, mkFinishDoc, mkExtraInfo, mkErroMsg

  Message* = object
    case kind*: MessageKind
    of mkInfo:
      info*: string
    of mkExtraInfo:
      extraInfo*: string
    of mkErroMsg:
      errorMsg*: string
    else: discard

var indiChannel*: Channel[Message]

proc infoMsg*(s: string): Message = 
  Message(kind: mkInfo, info: s)

proc extraInfoMsg*(s: string): Message = 
  Message(kind: mkExtraInfo, extraInfo: s)

proc finishDataMsg*(): Message = 
  Message(kind: mkFinishData)

proc finishDocMsg*(): Message = 
  Message(kind: mkFinishDoc)

proc errorMsg*(msg: string): Message = 
  Message(kind: mkErroMsg, errorMsg: msg)

proc pretty*(a: auto): string = 
    prettyString(prettyWalk(a))

template info*(a: typed): untyped = 
  indiChannel.send infoMsg a

template extraInfo*(a: typed): untyped = 
  indiChannel.send extraInfoMsg a

const
  #dateFormat = "dd/MM/yyyy"
  ciudades* = [
    "Armenia", "Barranquilla",
    "Bogotá, D.C.", "Bucaramanga",
    "Cali", "Cartagena",
    "Cúcuta","Florencia (Caquetá)",
    "Ibagué", "Ipiales (Nariño)",
    "Manizales", "Medellín",
    "Montería", "Neiva",
    "Pereira", "Pasto",
    "Popayán", "Santa Marta (Magdalena)",
    "Sincelejo", "Tibasosa (Boyacá)",
    "Tunja", "Valledupar",
    "Villavicencio",
  ]
  fuentes* = [
    (ciudad: "Armenia", mercado: "Mercar"),
    ("Barranquilla", "Barranquillita"),
    ("Barranquilla", "Granabastos"),
    ("Bogotá, D.C.", "Corabastos"),
    ("Bogotá, D.C.", "Paloquemao"),
    ("Bogotá, D.C.", "Plaza Las Flores"),
    ("Bogotá, D.C.", "Plaza Samper Mendoza"),
    ("Bucaramanga", "Centroabastos"),
    ("Cali", "Cavasa"),
    ("Cali", "Santa Elena"),
    ("Cartagena", "Bazurto"),
    ("Cúcuta", "Cenabastos"),
    ("Cúcuta", "La Nueva Sexta"),
    ("Florencia (Caquetá)", ""),
    ("Ibagué", "Plaza La 21"),
    ("Ipiales (Nariño)", "Centro de acopio"),
    ("Manizales", "Centro Galerías"),
    ("Medellín", "Central Mayorista de Antioquia"),
    ("Medellín", "Plaza Minorista \"José María Villa\""),
    ("Montería", "Mercado del Sur"),
    ("Neiva", "Surabastos"),
    ("Pereira", "La 41"),
    ("Pereira", "Mercasa"),
    ("Pasto", "El Potrerillo"),
    ("Popayán", "Plaza de mercado del barrio Bolívar"),
    ("Santa Marta (Magdalena)", ""),
    ("Sincelejo", "Nuevo Mercado"),
    ("Tibasosa (Boyacá)", "Coomproriente"),
    ("Tunja", "Complejo de Servicios del Sur"),
    ("Valledupar", "Mercabastos"),
    ("Valledupar", "Mercado Nuevo"),
    ("Villavicencio", "CAV")
  ]
  grupos* = [ # Not uniformed (with accents)
    "verduras y hortalizas", "tubérculos, raíces y plátanos", "frutas",
    "granos y cereales", "lácteos y huevos", "pescados", "procesados", "carnes" # Otros
  ]
  gruposToEnum* = { # Uniformed (without accents)
    "verduras y hortalizas": gVerdHort, "tuberculos, raices y platanos": gTubRaiPla, "frutas": gFrutas,
    "granos y cereales": gOtros, "lacteos y huevos": gOtros, "pescados": gOtros, "procesados": gOtros, "carnes": gOtros
  }.toTable

proc uniform*(str: string): string =
  str.strip().toLowerAscii().multiReplace(("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ñ", "n"))

proc processData*(dateFormat, inputPath: string): auto =
  let startTime = getMonoTime()

  #const path = currentSourcePath.parentDir() / "../InfoAbaste-2-26_03_2024.csv"

  let df = parseCsvString(readFile(inputPath).convert(destEncoding = "UTF-8", srcEncoding = "CP1252"), sep = ';', quote = '\0')

  for column in ["Fuente", "FechaEncuesta", "HoraEncuesta", "TipoVehiculo", "PlacaVehiculo", "Cod. Depto Proc.", "Departamento Proc.", "Cod. Municipio Proc.", "Municipio Proc.", "Observaciones", "Grupo", "Codigo CPC", "Ali", "Cant Pres", "Pres", "Peso Pres", "Cant Kg"]:
    assert column in df, &"La columna \"{column}\" no existe"
  {.cast(gcsafe).}:
    let dateCol = df["FechaEncuesta"]
    let firstWeekStart = dateCol[0, string].parse(dateFormat)
    let secondWeekEnd = dateCol[dateCol.high, string].parse(dateFormat)
  let firstWeekEnd = firstWeekStart + 6.days
  let secondWeekStart = secondWeekEnd - 6.days

  assert inDays(secondWeekEnd - firstWeekStart) == 13, &"Entre el primer y último registro no hay dos semanas, hay {{inDays(secondWeekEnd - firstWeekStart)}} días" # Two weeks, not 14 since subtracting doesn't include secondWeekEnd
  {.cast(gcsafe).}:
    let firstWeekDf = df.filter(f{string -> bool: inDays(idx(`FechaEncuesta`).parse(dateFormat) - firstWeekStart) < 7})
    let secondWeekDf = df.filter(f{string -> bool: inDays(secondWeekEnd - idx(`FechaEncuesta`).parse(dateFormat)) < 7})
    let firstWeekTotalKg = firstWeekDf["Cant Kg", float].sum
    let secondWeekTotalKg = secondWeekDf["Cant Kg", float].sum
  let weeksKgDifference = ((secondWeekTotalKg - firstWeekTotalKg) / firstWeekTotalKg) * 100 # Percentage

  extraInfo pretty weeksKgDifference

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
    weeksGruposDifference[grupo] = ((secondWeekGruposTotalKg[grupo] - total) / total) * 100

  extraInfo pretty weeksGruposDifference

  proc parseFuente(input: string): Fuente =
    let fuenteSplit = input.rsplit(", ", maxsplit = 1)
    assert fuenteSplit.len in 1..2, &"{fuenteSplit=}"

    result =
      if fuenteSplit.len == 2:
        (ciudad: fuenteSplit[0], mercado: fuenteSplit[1])
      else:
        (ciudad: fuenteSplit[0], mercado: "")

    if result.ciudad == "Cali" and result.mercado == "Santa Helena":
      result.mercado = "Santa Elena"

  proc sumFuentesAndCiudades(df: DataFrame): tuple[fuentes: Table[Fuente, float], ciudades: Table[string, float]] =
    for f in fuentes:
      result.fuentes[f] = 0

    for c in ciudades:
      result.ciudades[c] = 0
    {.cast(gcsafe).}:
      for t, subDf in groups df.group_by("Fuente"):
        assert t.len == 1, &"{t.len=}" # Since it was only grouped_by one column
        assert t[0][1].kind == VString, &"{t[0][1].kind=}"

        let fuente = t[0][1].toStr.parseFuente() # t[0][1] would be each fuente
        result.fuentes[fuente] += subDf["Cant Kg", float].sum
        result.ciudades[fuente.ciudad] += subDf["Cant Kg", float].sum

  let (firstWeekFuentesTotalKg, firstWeekCiudadesTotalKg) = firstWeekDf.sumFuentesAndCiudades()
  let (secondWeekFuentesTotalKg, secondWeekCiudadesTotalKg) = secondWeekDf.sumFuentesAndCiudades()

  var weeksFuentesDifference = initTable[Fuente, float]() # Percentage per fuente
  for fuente, total in firstWeekFuentesTotalKg:
    assert fuente in secondWeekFuentesTotalKg, &"{fuente=}"
    weeksFuentesDifference[fuente] = ((secondWeekFuentesTotalKg[fuente] - total) / total) * 100

  extraInfo pretty weeksFuentesDifference

  var weeksCiudadesDifference = initTable[string, float]() # Percentage per fuente
  for ciudad, total in firstWeekCiudadesTotalKg:
    assert ciudad in secondWeekCiudadesTotalKg, &"{ciudad=}"
    weeksCiudadesDifference[ciudad] = ((secondWeekCiudadesTotalKg[ciudad] - total) / total) * 100

  extraInfo pretty weeksCiudadesDifference

  proc sumFuentesAndCiudadesGrupos(df: DataFrame): tuple[fuentes: Table[Fuente, Table[Grupo, float]], ciudades: Table[string, Table[Grupo, float]]] =
    for f in fuentes:
      result.fuentes[f] = initTable[Grupo, float]()
      for g in Grupo:
        result.fuentes[f][g] = 0

    for c in ciudades:
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

  let (firstWeekFuentesGruposTotalKg, firstWeekCiudadesGruposTotalKg) = firstWeekDf.sumFuentesAndCiudadesGrupos()
  let (secondWeekFuentesGruposTotalKg, secondWeeksCiudadesGruposTotalKg) = secondWeekDf.sumFuentesAndCiudadesGrupos()

  var weeksFuentesGruposDifference = initTable[Fuente, Table[Grupo, float]]() # Percentage per fuente and grupo
  for fuente, grupos in firstWeekFuentesGruposTotalKg:
    assert fuente in secondWeekFuentesGruposTotalKg, &"{fuente=}"
    weeksFuentesGruposDifference[fuente] = initTable[Grupo, float]()
    for grupo, total in grupos:
      assert grupo in secondWeekFuentesGruposTotalKg[fuente], &"{fuente=} {grupo=}"
      weeksFuentesGruposDifference[fuente][grupo] = ((secondWeekFuentesGruposTotalKg[fuente][grupo] - total) / total) * 100

  extraInfo pretty weeksFuentesGruposDifference

  var weeksCiudadesGruposDifference = initTable[string, Table[Grupo, float]]() # Percentage per ciudad and grupo
  for ciudad, grupos in firstWeekCiudadesGruposTotalKg:
    assert ciudad in secondWeeksCiudadesGruposTotalKg, &"{ciudad=}"
    weeksCiudadesGruposDifference[ciudad] = initTable[Grupo, float]()
    for grupo, total in grupos:
      assert grupo in secondWeeksCiudadesGruposTotalKg[ciudad], &"{ciudad=} {grupo=}"
      #if total == 0 and secondWeeksCiudadesGruposTotalKg[ciudad][grupo] == 0:
      #  continue
      weeksCiudadesGruposDifference[ciudad][grupo] = ((secondWeeksCiudadesGruposTotalKg[ciudad][grupo] - total) / total) * 100

  extraInfo pretty firstWeekCiudadesGruposTotalKg
  extraInfo pretty secondWeeksCiudadesGruposTotalKg
  extraInfo pretty weeksCiudadesGruposDifference

  proc sumWeekdays(df: DataFrame): Table[WeekDay, float] =
    for i in WeekDay:
      result[i] = 0

    {.cast(gcsafe).}:
      for t, subDf in groups(df.group_by("FechaEncuesta")):
        assert t.len == 1, &"{t.len=}" # Since it was only grouped_by one column

        assert t[0][1].kind == VString, &"{t[0][1].kind=}"

        let fecha = t[0][1].toStr.parse(dateFormat) # t[0][1] would be each FechaEncuesta
        result[fecha.weekday] += subDf["Cant Kg", float].sum

  let firstWeekWeekdaysTotalKg = firstWeekDf.sumWeekdays()
  let secondWeekWeekdaysTotalKg = secondWeekDf.sumWeekdays()

  var weeksWeekdaysDifference = initTable[WeekDay, float]() # Percentage per weekday
  for weekday, total in firstWeekWeekdaysTotalKg:
    assert weekday in secondWeekWeekdaysTotalKg, &"{weekday=}"
    weeksWeekdaysDifference[weekday] = ((secondWeekWeekdaysTotalKg[weekday] - total) / total) * 100

  extraInfo pretty weeksWeekdaysDifference
  info &"Procesando los datos se demoró {getMonoTime() - startTime}"

  indiChannel.send finishDataMsg()

  (
    firstWeekStart: firstWeekStart, secondWeekEnd: secondWeekEnd, firstWeekEnd: firstWeekEnd, secondWeekStart: secondWeekStart, 
    firstWeekTotalKg: firstWeekTotalKg, secondWeekTotalKg: secondWeekTotalKg, weeksKgDifference: weeksKgDifference, 
    firstWeekGruposTotalKg: firstWeekGruposTotalKg, secondWeekGruposTotalKg: secondWeekGruposTotalKg, weeksGruposDifference: weeksGruposDifference, 
    weeksFuentesDifference: weeksFuentesDifference, weeksCiudadesDifference: weeksCiudadesDifference, 
    weeksFuentesGruposDifference: weeksFuentesGruposDifference, weeksCiudadesGruposDifference: weeksCiudadesGruposDifference, 
    weeksWeekdaysDifference: weeksWeekdaysDifference, 
  )

