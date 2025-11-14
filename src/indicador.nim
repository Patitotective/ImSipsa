import
  std/[
    strformat, times, strutils, tables, math, algorithm, sequtils, sugar, monotimes,
    random, logging, os, paths,
  ]
import minidocx/lowapi
import pretty

import ./[indicador_data, utils]

const
  spanishMonths = {
    mJan: "enero",
    mFeb: "febrero",
    mMar: "marzo",
    mApr: "abril",
    mMay: "mayo",
    mJun: "junio",
    mJul: "julio",
    mAug: "agosto",
    mSep: "septiembre",
    mOct: "octubre",
    mNov: "noviembre",
    mDec: "diciembre",
  }.toTable

  spanishWeekdays = {
    dMon: "lunes",
    dTue: "martes",
    dWed: "miércoles",
    dThu: "jueves",
    dFri: "viernes",
    dSat: "sábado",
    dSun: "domingo",
  }.toTable

  titleFont = (size: 14, name: "Segoe UI")
  paragraphFont = (size: 11, name: "Segoe UI")
  legendFont = (size: 10, name: "Segoe UI")

  gruposArticle =
    {gVerdHort: "las", gTubRaiPla: "los", gFrutas: "las", gOtros: "los"}.toTable

  ciudadesArticles = {
    "Ipiales (Nariño)": "el",
    "Sincelejo": "el",
    "Manizales": "el",
    "Montería": "el",
    "Tunja": "el",
    "Medellín": "la",
    "Popayán": "la",
    "Ibagué": "la",
    "Cali": "",
    "Neiva": "",
    "Bogotá, D.C.": "",
    "Villavicencio": "",
    "Cúcuta": "",
    "Barranquilla": "",
    "Armenia": "",
    "Tibasosa (Boyacá)": "",
    "Bucaramanga": "",
    "Cartagena": "",
    "Valledupar": "",
    "Santa Marta (Magdalena)": "",
    "Pereira": "",
    "Florencia (Caquetá)": "",
    "Pasto": "",
  }.toTable

randomize()

proc joinButLast[T](a: openArray[T], prefix, sep, lastSep: string): string =
  ## Joins a with sep between elements and prefix before elements, but the last element is joind with lasSep
  if a.len == 1:
    return $a[0]

  var e = 0
  while e in a.low .. (a.high - 2):
    result.add prefix
    result.add $a[e]
    result.add sep
    inc e

  result.add prefix
  result.add $a[e]
  result.add lastSep

  result.add prefix
  result.add $a[e + 1]

proc myFormatFloat(f: SomeFloat): string =
  formatFloat(f, ffDecimal, 2, ',') & '%'

proc at[K, V](t: OrderedTable[K, V], i: int): tuple[key: K, val: V] =
  ## Returns the key-value pair at i index in t.
  var count = 0
  for k, v in t:
    if count == i:
      return (k, v)

    inc count

  raise newException(IndexDefect, &"Not found index {i}")

proc generateDocument(dateFormat, inputPath: string) =
  let startTime = getMonoTime()

  let (
    firstWeekStart, secondWeekEnd, firstWeekEnd, secondWeekStart, firstWeekTotalKg,
    secondWeekTotalKg, weeksKgDifference, firstWeekGruposTotalKg,
    secondWeekGruposTotalKg, weeksGruposDifference, weeksFuentesDifference,
    weeksCiudadesDifference, weeksFuentesGruposDifference,
    weeksCiudadesGruposDifference, weeksWeekdaysDifference,
  ) = processDataIndicador(dateFormat, inputPath)

  var doc: Document

  if weeksKgDifference == 0:
    raise newException(ValueError, "No hubo cambio entre la oferta de las dos semanas")

  let secondWeekIncreased = weeksKgDifference > 0

  block title:
    var p = doc.appendParagraph()
    p.setAlignment(ParagraphAlignment.Centered)

    var r = p.appendRun(
      "$# oferta de alimentos" % [if secondWeekIncreased: "Mayor" else: "Menor"],
      cdouble titleFont.size,
      titleFont.name,
    )

    r.setFontStyle(RunFontStyle.Bold)

  proc weekText(startDate, endDate: DateTime): string =
    # If the end of the week is in the next year
    if startDate.year != endDate.year:
      &"del {startDate.monthday} de {spanishMonths[startDate.month]} de {startDate.year} al {endDate.monthday} de {spanishMonths[endDate.month]} de {endDate.year}"
    # If the end of the week is in the next month
    elif startDate.month != endDate.month:
      &"del {startDate.monthday} de {spanishMonths[startDate.month]} al {endDate.monthday} de {spanishMonths[endDate.month]}"
    else:
      &"del {startDate.monthday} al {endDate.monthday} de {spanishMonths[startDate.month]}"

  block p1:
    let weeksText =
      if firstWeekStart.year == firstWeekEnd.year and
          firstWeekEnd.year != secondWeekStart.year:
        &"{weekText(firstWeekStart, firstWeekEnd)} de {firstWeekEnd.year} y {weekText(secondWeekStart, secondWeekEnd)} de {secondWeekEnd.year}"
      else:
        &"{weekText(firstWeekStart, firstWeekEnd)} y {weekText(secondWeekStart, secondWeekEnd)} de {secondWeekEnd.year}"

    var p = doc.appendParagraph()

    var r = p.appendRun()
    r.setFont(paragraphFont.name)
    r.setFontSize(cdouble paragraphFont.size)
    r.appendLineBreak()
    r.appendText(
      (
        "El abastecimiento en los mercados mayoristas donde el SIPSA en el Componente de Abastecimiento " &
        "tomó información para las semanas $# $# en $#."
      ) % [
        weeksText,
        if secondWeekIncreased: "aumentó" else: "disminuyó",
        myFormatFloat(abs(weeksKgDifference)),
      ]
    )
    r.appendLineBreak()
    p.setAlignment(ParagraphAlignment.Justified)

  block p2:
    let secondWeekEndDifference = weeksWeekdaysDifference[secondWeekEnd.weekday]
    let secondWeekEndYear =
      if firstWeekEnd.year != secondWeekEnd.year:
        &" de {secondWeekEnd.year}"
      else:
        ""
    let firstWeekEndYear =
      if secondWeekEndYear.len > 0:
        &" de {firstWeekEnd.year}"
      else:
        ""

    var p = doc.appendParagraph(
      (
        "El comportamiento del acopio diario de alimentos para las últimas dos semanas se observa en la siguiente gráfica, " &
        "en donde se presenta la misma tendencia entre las dos semanas, finalizando el $# $# por $# del $#."
      ) % [
        &"{spanishWeekdays[secondWeekEnd.weekday]} {secondWeekEnd.monthday} de {spanishMonths[secondWeekEnd.month]}{secondWeekEndYear}",
        if abs(weeksKgDifference) <= 1:
          "levemente"
        elif abs(weeksKgDifference) <= 10:
          "notablemente"
        else:
          "enormemente",
        if secondWeekEndDifference > 0:
          "encima"
        elif secondWeekEndDifference < 0:
          "debajo"
        else:
          "igual",
        &"{spanishWeekdays[firstWeekEnd.weekday]} {firstWeekEnd.monthday} de {spanishMonths[firstWeekEnd.month]}{firstWeekEndYear}",
      ],
      cdouble paragraphFont.size,
      paragraphFont.name,
    )
    p.setAlignment(ParagraphAlignment.Justified)

  block p3:
    var p = doc.appendParagraph()
    p.setAlignment(ParagraphAlignment.Left)

    let firstWeekStartMonth =
      if firstWeekStart.month != secondWeekEnd.month:
        &" de {spanishMonths[firstWeekStart.month]}"
      else:
        ""

    let firstWeekStartYear =
      if firstWeekStart.year != secondWeekEnd.year:
        &" de {firstWeekStart.year}"
      else:
        ""

    var r = p.appendRun()
    r.setFont(legendFont.name)
    r.setFontSize(cdouble legendFont.size)
    r.setFontStyle(RunFontStyle.Bold)

    r.appendLineBreak()
    r.appendText(
      "Gráfico 4. Abastecimiento diario de alimentos de las últimas dos semanas"
    )
    r.appendLineBreak()
    r.appendText(&"{fuentes.len} mercados mayoristas")
    r.appendLineBreak()
    r.appendText(
      &"{firstWeekStart.monthday}{firstWeekStartMonth}{firstWeekStartYear} al {secondWeekEnd.monthday} de {spanishMonths[secondWeekEnd.month]} de {secondWeekEnd.year}"
    )

    r.appendLineBreak()

    var r2 = p.appendRun("IMAGEN DE LA GRÁFICA", cdouble titleFont.size + 10)
    r2.setFontStyle(mixFlags(RunFontStyle.Bold, RunFontStyle.Underline))

    r2.appendLineBreak()

    var r3 = p.appendRun("Fuente:", cdouble legendFont.size - 1, legendFont.name)
    r3.setFontStyle(RunFontStyle.Bold)

    var r4 =
      p.appendRun(" DANE – SIPSA_A", cdouble legendFont.size - 1, legendFont.name)
    r4.appendLineBreak()

  block p4:
    var p = doc.appendParagraph()
    let order = if secondWeekIncreased: SortOrder.Descending else: SortOrder.Ascending

    let gruposSorted = sorted(
      Grupo.toSeq,
      proc(x, y: Grupo): int =
        cmp(weeksGruposDifference[x], weeksGruposDifference[y]),
      order,
    )
    assert gruposSorted.len == 4

    var r = p.appendRun(
      (
        &"Así, $# $# su oferta $#, $# $# su acopio en $#, " &
        &"en cambio $# $# $# y el abastecimiento de $# $# $#."
      ) % [
        &"{gruposArticle[gruposSorted[0]]} {gruposSorted[0]}",
        if weeksGruposDifference[gruposSorted[0]] > 0: "aumentaron" else: "disminuyeron",
        myFormatFloat(abs(weeksGruposDifference[gruposSorted[0]])),
        &"{gruposArticle[gruposSorted[1]]} {gruposSorted[1]}",
        if weeksGruposDifference[gruposSorted[1]] > 0: "subieron" else: "bajaron",
        myFormatFloat(abs(weeksGruposDifference[gruposSorted[1]])),
        &"{gruposArticle[gruposSorted[2]]} {gruposSorted[2]}",
        if weeksGruposDifference[gruposSorted[2]] > 0: "aumentaron" else: "disminuyeron",
        myFormatFloat(abs(weeksGruposDifference[gruposSorted[2]])),
        &"{gruposArticle[gruposSorted[3]]} {gruposSorted[3]}",
        if weeksGruposDifference[gruposSorted[3]] > 0: "subió" else: "bajó",
        myFormatFloat(abs(weeksGruposDifference[gruposSorted[3]])),
      ],
      cdouble paragraphFont.size,
      paragraphFont.name,
    )
    r.appendLineBreak()

  block p5: # Actually these creates 4 paragraphs
    let order = if secondWeekIncreased: SortOrder.Descending else: SortOrder.Ascending

    let ciudadesSorted = sorted(
      ciudades,
      proc(x, y: string): int =
        cmp(weeksCiudadesDifference[x], weeksCiudadesDifference[y]),
      order,
    )
    var ciudadesMercados = initOrderedTable[string, seq[string]]()
      # {ciudad: @[mercado1, mercado2], ...}
    for ciudad in ciudadesSorted:
      ciudadesMercados[ciudad] = newSeq[string]()

    for fuente in fuentes:
      ciudadesMercados[fuente.ciudad].add fuente.mercado

    info pretty ciudadesMercados

    proc ciudadSentence(ciudad: string, index: int): string =
      assert ciudad in ciudadesMercados and ciudad in ciudadesArticles, &"{ciudad=}"

      let fuentes = ciudadesMercados[ciudad]
      let ciudadMostGrupo = block:
        let order =
          if secondWeekIncreased: SortOrder.Descending else: SortOrder.Ascending

        Grupo.toSeq().sorted(
          proc(x, y: Grupo): int =
            ## Sort grupos in order of most importance in the difference between the two weeks.
            ## If there is a group that is NaN, it's sorted in the last place
            let xx = weeksCiudadesGruposDifference[ciudad][x]
            let yy = weeksCiudadesGruposDifference[ciudad][y]
            if xx.isNan and yy.isNan:
              0
            elif xx.isNan:
              if order == SortOrder.Descending: -100 else: 100
            elif yy.isNan:
              if order == SortOrder.Descending: 100 else: -100
            else:
              cmp(xx, yy),
          order,
        )[0]

      result =
        case index
        of 0:
          "Entre los mercados mayoristas que registraron $# en su oferta de alimentos se $#" %
          [
            if secondWeekIncreased: "alzas" else: "bajas",
            case fuentes.len
            of 0, 1: "encuentra"
            else: "encuentran"
            ,
          ]
        of 1, 3:
          "En"
        of 2:
          "En el mercado de"
        of 4:
          "En cuanto a"
        of 5:
          "En la central de"
        of 6:
          "Respecto a"
        of 7:
          "Finalmente, en"
        else:
          "En"

      result.add " "

      block:
        var ciudad2 = ciudad # ciudad without parenthesis
        if ciudad2 == "Bogotá, D.C.":
          ciudad2 = "Bogotá"
        elif '(' in ciudad2:
          ciudad2 = ciudad2[0 .. ciudad2.find('(') - 2]

        let article =
          if ciudadesArticles[ciudad].len > 0:
            ciudadesArticles[ciudad] & " "
          else:
            ""

        result.add:
          case index
          of 2, 5:
            ciudad2
          else:
            if index in [4, 6] and fuentes.len == 0: # a el mercado -> al mercado
              &"l mercado de {ciudad2}"
            else:
              case fuentes.len
              of 0:
                &"el mercado de {ciudad2}"
              of 1:
                &"{article}{fuentes[0]} en {ciudad2}"
              else:
                fuentes.joinButLast(article, ", ", " y ") & &" en {ciudad2}"

      if index == 0:
        result.add " que"

      # TODO: add more variants
      case index
      of 0:
        result.add " $# su abastecimiento $# por $# $# que $# sus inventarios en $#, debido al $# ingreso de ..., principalmente." %
        [
          if weeksCiudadesDifference[ciudad] > 0: "aumentó" else: "disminuyó",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo],
          $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "incrementaron"
          else:
            "redujeron",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayor"
          else:
            "menor",
        ]
      of 1:
        result.add (
          ", el abastecimiento $# $# por $# que registraron un $# suministro " &
          "del orden del $#, ante $# en el abastecimiento de ..., entre otros."
        ) % [
          if weeksCiudadesDifference[ciudad] > 0: "incrementó" else: "decreció",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayor"
          else:
            "menor",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "un aumento"
          else:
            "una disminución",
        ]
      of 2:
        result.add (
          ", la oferta de alimentos $# $#, a causa de $# que presentaron una variación $# del " &
          "$# influenciado por el ingreso de alimentos como ..."
        ) % [
          if weeksCiudadesDifference[ciudad] > 0: "incrementó" else: "decreció",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "positiva"
          else:
            "negativa",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
        ]
      of 3:
        result.add ", el aprovisionamiento $# $#, por $# que presentaron un $# acopio llegando al $# $#, debido $# de ..., entre otros." %
        [
          if weeksCiudadesDifference[ciudad] > 0: "subió" else: "bajó",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayor"
          else:
            "menor",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "más"
          else:
            "menos",
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "al crecimiento en la entrada"
          else:
            "al decrecimiento en la entrada",
        ]
      of 4:
        result.add ", los inventarios de alimentos $# $# por $# que presentaron $# del $# ante los $# volúmenes de ..., especialmente." %
        [
          if weeksCiudadesDifference[ciudad] > 0: "aumentaron" else: "cayeron",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "un incremento"
          else:
            "una reducción",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayores"
          else:
            "menores",
        ]
      of 5:
        result.add " $# el acopio en $# por $# que reportaron un $# del $# por los $# ingreso de inventarios de alimentos como ..." %
        [
          if weeksCiudadesDifference[ciudad] > 0: "incrementó" else: "disminuyó",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "crecimiento"
          else:
            "decrecimiento",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayores"
          else:
            "menores",
        ]
      of 6:
        result.add (
          ", el aprovisionamiento de alimentos $# $# por $# que registraron una variación " &
          "$# del $#, como consecuencia de la $# entrada de ..., entre otros."
        ) % [
          if weeksCiudadesDifference[ciudad] > 0: "creció" else: "descendió",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "positiva"
          else:
            "negativa",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayor"
          else:
            "menor",
        ]
      of 7:
        result.add (
          ", $# la oferta en $# por $# que registraron una $# " &
          "del $#, como resultado del $# ingreso de alimentos como ..."
        ) % [
          if weeksCiudadesDifference[ciudad] > 0: "aumentó" else: "decreció",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          "variación",
          #if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
          #  "subida"
          #else:
          #  "baja",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayor"
          else:
            "menor",
        ]
      else: # Same as the 4th one
        result.add ", los inventarios de alimentos $# $# por $# que presentaron $# del $# ante los $# volúmenes de ..., especialmente." %
        [
          if weeksCiudadesDifference[ciudad] > 0: "aumentaron" else: "cayeron",
          myFormatFloat(abs(weeksCiudadesDifference[ciudad])),
          gruposArticle[ciudadMostGrupo] & " " & $ciudadMostGrupo,
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "un incremento"
          else:
            "una reducción",
          myFormatFloat(abs(weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo])),
          if weeksCiudadesGruposDifference[ciudad][ciudadMostGrupo] > 0:
            "mayores"
          else:
            "menores",
        ]

    var p = doc.appendParagraph()
    var options = @[1, 2, 3, 4, 5, 6]

    for i in countup(0, 6, 2):
      var r1, r2: int
      if i == 0:
        r1 = 0
        r2 = sample(options)
        options.del(options.find(r2))
      elif i == 6:
        r1 = sample(options)
        options.del(options.find(r1))
        r2 = 7
      else:
        r1 = sample(options)
        options.del(options.find(r1))
        r2 = sample(options)
        options.del(options.find(r2))

      assert r1 < ciudadesMercados.len and r2 < ciudadesMercados.len,
        &"No hay suficientes ciudades para los párrafos {ciudadesMercados=}"
      var r = p.appendRun(
        ciudadSentence(ciudadesMercados.at(i).key, r1) & " " &
          ciudadSentence(ciudadesMercados.at(i + 1).key, r2),
        cdouble paragraphFont.size,
        paragraphFont.name,
      )
      r.appendLineBreak()

      if i < 6:
        r.appendLineBreak()

  block p9:
    const sentences =
      ["participaron con el", "concentraron el", "representaron el", "el"]

    var weeksText = &"{secondWeekStart.monthday}"
    if secondWeekStart.month != secondWeekEnd.month:
      weeksText.add &" de {spanishMonths[secondWeekStart.month]}"

    weeksText.add &" al {secondWeekEnd.monthday} de {spanishMonths[secondWeekEnd.month]}"

    var gruposParcipation = initTable[Grupo, float]()
    for grupo in Grupo:
      gruposParcipation[grupo] =
        (secondWeekGruposTotalKg[grupo] / secondWeekTotalKg) * 100

    var gruposText = ""
    for e, grupo in Grupo.toSeq.sorted(
      (x, y) => cmp(gruposParcipation[x], gruposParcipation[y]), SortOrder.Descending
    ):
      let sentence =
        if e < sentences.len:
          sentences[e]
        else:
          sentences[0]

      gruposText.add &"{gruposArticle[grupo]} {grupo} {sentence} {myFormatFloat(gruposParcipation[grupo])}"

      gruposText.add:
        if e < Grupo.high.int - 1: # Until the third-last one
          ", "
        elif e < Grupo.high.int: # Second-last
          " y "
        else: # Last
          "."

    var p = doc.appendParagraph()
    var r = p.appendRun(
      "La participación de los diferentes grupos en el total del abastecimiento " &
        "para la semana comprendida del $# fue la siguiente: $#" %
        [weeksText, gruposText],
      cdouble paragraphFont.size,
      paragraphFont.name,
    )
    r.appendLineBreak()

  block p10:
    var p = doc.appendParagraph(
      "Revisando el acopio entre la semana 1 y la semana 8 de los últimos " &
        "tres años¹, el abastecimiento del presente año se encuentra por encima de los periodos " &
        "anteriores, y específicamente la octava semana del año aumentó 14,03% con respecto a la " &
        "misma semana de 2023 y 20,95% frente al 2022.",
      cdouble paragraphFont.size,
      paragraphFont.name,
    )
    var footNote = doc.appendParagraph(
      "PIE DE NOTA¹: Se comparan 23 ciudades que cubre el SIPSA_A en 2023 y 2024 frente a 21 ciudades que cubría en 2022."
    )

  block p11:
    var p = doc.appendParagraph()
    var r = p.appendRun()
    r.setFont(legendFont.name)
    r.setFontSize(cdouble legendFont.size)
    r.setFontStyle(RunFontStyle.Bold)

    for i in 1 .. 9:
      r.appendLineBreak()

    r.appendText(
      "Gráfico 5. Abastecimiento semanal de alimentos de los últimos tres años"
    )
    r.appendLineBreak()
    r.appendText("29 mercados mayoristas (2022) y 32 mercados mayoristas (2023 y 2024)")
    r.appendLineBreak()

    var r2 = p.appendRun("IMAGEN DE LA GRÁFICA", cdouble titleFont.size + 10)
    r2.setFontStyle(mixFlags(RunFontStyle.Bold, RunFontStyle.Underline))

    r2.appendLineBreak()

    var r3 = p.appendRun("Fuente:", cdouble legendFont.size - 1, legendFont.name)
    r3.setFontStyle(RunFontStyle.Bold)

    var r4 =
      p.appendRun(" DANE – SIPSA_A", cdouble legendFont.size - 1, legendFont.name)
    r4.appendLineBreak()

  let filename = block:
    let firstWeekStartMonth =
      if firstWeekStart.month != secondWeekEnd.month:
        spanishMonths[firstWeekStart.month][0 .. 2]
      else:
        ""

    let secondWeekEndMonth = spanishMonths[secondWeekEnd.month][0 .. 2]

    let firstWeekStartYear =
      if firstWeekStart.year != secondWeekEnd.year:
        $firstWeekStart.year
      else:
        ""

    # An example of filename: Indicador 15-28feb2024.docx
    &"Indicador {firstWeekStart.monthday}{firstWeekStartMonth}{firstWeekStartYear}-{secondWeekEnd.monthday}{secondWeekEndMonth}{secondWeekEnd.year}.docx"

  let outputPath = inputPath.splitFile.dir & "/" & filename
  info &"Archivo del documento: {outputPath}"

  assert doc.save(outputPath), "No se pudo guardar el archivo correctamente :("
  info &"Generando el documento se demoró {getMonoTime() - startTime}"

when isMainModule:
  let logPath = getAppDir() & "/" & currentSourcePath().splitFile().name & ".log"
  setupLogging(logPath)

  var inputPath: string
  for kind, path in walkDir(getAppDir()):
    if kind != pcFile:
      continue

    let (dir, name, ext) = path.splitFile()
    if ext == ".csv":
      info &"Se dectecto el archivo {path} y se va a utilizar para generar el indicador"
      inputPath = path
      break

  if inputPath.len > 0:
    try:
      generateDocument("d/M/yyyy", inputPath)
    except:
      fail "No se pudo generar el indicador"
  else:
    fatal "No se encontró ningún archivo CSV"
