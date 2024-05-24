import std/[threadpool, enumerate, strutils, strformat, os]

import imstyle
import openurl
import tinydialogs
import kdl, kdl/prefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[settingsmodal, utils, types, icons, ali_process]
import src/indicador/[document, data]

when defined(release):
  import resources

proc getConfigDir(app: App): string =
  getConfigDir() / app.config.name

proc drawAboutModal(app: App) =
  igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))
  let unusedOpen = true # Passing this parameter creates a close button
  if igBeginPopupModal(cstring "About " & app.config.name & "###about", unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize)):
    # Display icon image
    var texture: GLuint
    var image = app.res(app.config.iconPath).readImageFromMemory()

    image.loadTextureFromData(texture)

    igImage(cast[ptr ImTextureID](texture), igVec2(64, 64)) # Or igVec2(image.width.float32, image.height.float32)
    if igIsItemHovered() and app.config.website.len > 0:
      igSetTooltip(cstring app.config.website & " " & FA_ExternalLink)

      if igIsMouseClicked(ImGuiMouseButton.Left):
        app.config.website.openURL()

    igSameLine()

    igPushTextWrapPos(250)
    igTextWrapped(cstring app.config.comment)
    igPopTextWrapPos()

    igSpacing()

    # To make it not clickable
    igPushItemFlag(ImGuiItemFlags.Disabled, true)
    igSelectable("Credits", true, makeFlags(ImGuiSelectableFlags.DontClosePopups))
    igPopItemFlag()

    if igBeginChild("##credits", igVec2(0, 75)):
      for (author, url) in app.config.authors:
        if igSelectable(cstring author) and url.len > 0:
          url.openURL()
        if igIsItemHovered() and url.len > 0:
          igSetTooltip(cstring url & " " & FA_ExternalLink)

      igEndChild()

    igSpacing()

    igText(cstring app.config.version)

    igEndPopup()

proc drawEditObservsModal(app: var App) = 
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  let unusedOpen = true # Passing this parameter creates a close button

  if igBeginPopupModal("Editar Observaciones###editObservs", unusedOpen.unsafeAddr):
    if igBeginListBox("##observs", size = igVec2(igGetContentRegionAvail().x, 0)):
      for e, observ in app.prefs[alitab].forbidden[app.alitab.currentFood].deepCopy:
        if igSelectable(cstring &"{observ}##{e}"):
          app.alitab.currentObserv = e
          app.alitab.observBuf = newString(100, observ)
          igOpenPopup("###editObserv")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            app.prefs[alitab].forbidden[app.alitab.currentFood].delete(app.alitab.currentObserv)

          igEndPopup()

      if drawEditModal("Editar observacion###editObserv", cstring app.alitab.observBuf):
        app.prefs[alitab].forbidden[app.alitab.currentFood][app.alitab.currentObserv] = app.alitab.observBuf.cleanString

      igEndListBox()

    if igButton("Add"):
      app.prefs[alitab].forbidden[app.alitab.currentFood].add "Observacion"

    igEndPopup()

proc drawForbiddenModal(app: var App) = 
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  let unusedOpen = true # Passing this parameter creates a close button
  if igBeginPopupModal("Editar Tabla###editForbidden", unusedOpen.unsafeAddr):
    if igBeginTable("##table", 2, makeFlags(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.Resizable)):
      igTableSetupColumn("Alimento")
      igTableSetupColumn("Observaciones")
      igTableHeadersRow()

      for e, (key, val) in enumerate app.prefs[alitab].forbidden.deepCopy.pairs:
        igTableNextRow()

        igTableNextColumn()
        if igSelectable(cstring key, flags = ImGuiSelectableFlags.DontClosePopups):
          app.alitab.currentFood = key
          app.alitab.foodBuf = newString(100, key)
          igOpenPopup("###editFood")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            app.prefs[alitab].forbidden.del(key)

          igEndPopup()

        igTableNextColumn()
        if igSelectable(cstring val.join(", "), flags = ImGuiSelectableFlags.DontClosePopups):
          app.alitab.currentFood = key
          igOpenPopup("###editObservs")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            app.prefs[alitab].forbidden.del(key)
          igEndPopup()

      if drawEditModal("Editar alimento###editFood", cstring app.alitab.foodBuf):
        app.prefs[alitab].forbidden[app.alitab.foodBuf.cleanString] = app.prefs[alitab].forbidden[app.alitab.currentFood]
        app.prefs[alitab].forbidden.del(app.alitab.currentFood)

      app.drawEditObservsModal()

      igEndTable()

    if igButton("Añadir"):
      var n = 1
      while &"Alimento #{n}" in app.prefs[alitab].forbidden:
        inc n

      app.prefs[alitab].forbidden[&"Alimento #{n}"] = @["Observacion"]

    igEndPopup()

proc drawMainMenuBar(app: var App) =
  var openAbout, openPrefs, openBlockdialog, openForbidden = false

  if igBeginMainMenuBar():
    if igBeginMenu("Archivo"):
      # igMenuItem("Settings " & FA_Cog, "Ctrl+P", openPrefs.addr)
      if igMenuItem("Volver al inicio", enabled = app.currentTab == 0 and app.alitab.processState == psFinished):
        app.alitab.errors.setLen(0)
        app.alitab.processError.setLen(0)
        app.alitab.processState = psUnstarted

      if igMenuItem("Cerrar " & FA_Times, "Ctrl+Q"):
        app.win.setWindowShouldClose(true)
      igEndMenu()

    if igBeginMenu("Editar"):
      igMenuItem("Tabla##forbidden", shortcut = nil, p_selected = openForbidden.addr)

      igEndMenu()

    if igBeginMenu("Acerca"):
      if igMenuItem("Sitio web " & FA_ExternalLink, enabled = app.config.website.len > 0):
        app.config.website.openurl()

      igMenuItem(cstring "About " & app.config.name, shortcut = nil, p_selected = openAbout.addr)

      igEndMenu()

    igEndMainMenuBar()

  # See https://github.com/ocornut/imgui/issues/331#issuecomment-751372071
  if openPrefs:
    initCache(app.prefs[settings])
    igOpenPopup("Configuracion")
  if openAbout:
    igOpenPopup("###about")
  if openBlockdialog:
    igOpenPopup("###blockdialog")
  if openForbidden:
    igOpenPopup("###editForbidden")

  # These modals will only get drawn when igOpenPopup(name) are called, respectly
  app.drawAboutModal()
  app.drawSettingsmodal()
  app.drawBlockDialogModal()
  app.drawForbiddenModal()

proc drawAlimentosTab(app: var App) = 
  if app.alitab.processState == psUnstarted:
    # Input
    if not app.alitab.file.flowvar.isNil and app.alitab.file.flowvar.isReady and (let val = ^app.alitab.file.flowvar; val.len > 0):
      app.alitab.file = (val: val, flowvar: nil) # Here we set flowvar to nil because once we acquire its value it's not neccessary until it's spawned again

    igInputTextWithHint("##file", "Ningun archivo seleccionado", cstring app.alitab.file.val, uint app.alitab.file.val.len, flags = ImGuiInputTextFlags.ReadOnly)
    igSameLine()
    if igButton("Examinar " & FA_FolderOpen):
      app.alitab.file.flowvar = spawn openFileDialog("Elige un archivo", getCurrentDir() / "\0", ["*.csv"], "CSV")
      igOpenPopup("###blockdialog")

    app.drawBlockDialogModal()
  
    # Other 
    igInputText("Columna alimentos##foodsCol", cstring app.alitab.foodColBuf, 100)
    igInputText("Columna observaciones##observCol", cstring app.alitab.observColBuf, 100)

    if app.alitab.file.val.len == 0 or app.alitab.foodColBuf.cleanString.len == 0 or app.alitab.observColBuf.cleanString.len == 0:
      igPushDisabled()

    if igButton("Procesar##process"):
      spawn validateExcel(app.alitab.file.val, app.alitab.foodColBuf.cleanString, 
        app.alitab.observColBuf.cleanString, app.prefs[alitab].forbidden)
      app.alitab.processState = psRunning

    if app.alitab.file.val.len == 0 or app.alitab.foodColBuf.cleanString.len == 0 or app.alitab.observColBuf.cleanString.len == 0:
      igPopDisabled()

  else:
    if (let (ok, msg) = aliChannel.tryRecv; ok):
      case msg.kind
      of mkData:
        app.alitab.errors.add (msg.pos, msg.food, msg.observ)
      of mkError:
        spawn notifyPopup("ImSipsa", msg.msg, IconType.Error)
        app.alitab.processError = $msg.msg
        app.alitab.processState = psFinished
      of mkFinished:
        app.alitab.processState = psFinished
        spawn notifyPopup("ImSipsa", &"El archivo ha sido procesado", IconType.Info)

    if app.alitab.processState == psFinished:
      igText("Completado")

    if app.alitab.processError.len > 0:
      igPushTextWrapPos(igGetWindowWidth())
      igTextWrapped(cstring app.alitab.processError)
      igPopTextWrapPos()

    if igBeginListBox("##listbox", igGetContentRegionAvail()):
      for e, error in app.alitab.errors:
        igSelectable(cstring &"{error.pos}: Alimento {error.food} contiene {error.observ}##{e}")
        if igBeginPopupContextItem():
          if igMenuItem(cstring "Copiar " & FA_FilesO):
            app.win.setClipboardString(cstring error.pos)

          igEndPopup()

      if app.alitab.processState != psFinished:
        igSpinner("##spinner", 30, 10, igGetColorU32(ButtonHovered))
      igEndListBox()

proc drawIndicadorTab(app: var App) = 
  if app.inditab.processState == psUnstarted:
    # Input
    if not app.inditab.file.flowvar.isNil and app.inditab.file.flowvar.isReady and (let val = ^app.inditab.file.flowvar; val.len > 0):
      app.inditab.file = (val: val, flowvar: nil) # Here we set flowvar to nil because once we acquire its value it's not neccessary until it's spawned again

    igInputTextWithHint("##file", "Ningun archivo seleccionado", cstring app.inditab.file.val, uint app.inditab.file.val.len, flags = ImGuiInputTextFlags.ReadOnly)
    igSameLine()
    if igButton("Examinar " & FA_FolderOpen):
      app.inditab.file.flowvar = spawn openFileDialog("Elige un archivo", getCurrentDir() / "\0", ["*.csv"], "CSV")
      igOpenPopup("###blockdialog")

    app.drawBlockDialogModal()
  
    # Other 
    igInputText("Formato de fecha##dateFormat", cstring app.inditab.dateFormatBuf, 100)

    if app.inditab.file.val.len == 0 or app.inditab.dateFormatBuf.cleanString.len == 0:
      igPushDisabled()

    if igButton("Generar##generar"):
      spawn generateDocument(app.inditab.dateFormatBuf.cleanString, app.inditab.file.val)
      app.inditab.processState = psRunning

    if app.inditab.file.val.len == 0 or app.inditab.dateFormatBuf.cleanString.len == 0:
      igPopDisabled()

  else:
    if (let (ok, msg) = indiChannel.tryRecv; ok):
      case msg.kind
      of mkInfo:
        app.indiTab.log.add (msg: msg.info, extraInfo: false)
      of mkExtraInfo:
        app.indiTab.log.add (msg: msg.extrainfo, extraInfo: true)
      of mkFinishData: discard
      of mkErroMsg:
        spawn notifyPopup("ImSipsa", msg.errorMsg, IconType.Error)
        app.inditab.processError = msg.errorMsg
        app.inditab.processState = psFinished
      of mkFinishDoc:
        app.inditab.processState = psFinished
        spawn notifyPopup("ImSipsa", &"El documento ha sido generado", IconType.Info)

    if app.inditab.processState == psFinished:
      igText("Completado")

    if app.inditab.processError.len > 0:
      igPushTextWrapPos(igGetWindowWidth())
      igTextWrapped(cstring app.inditab.processError)
      igPopTextWrapPos()

    igCheckbox("Mostrar informacion extra", app.inditab.showExtraInfo.addr)

    if igBeginListBox("##listbox", igGetContentRegionAvail()):
      for e, msg in app.inditab.log:
        if not msg.extrainfo or app.inditab.showExtraInfo:
          igSelectable(cstring &"{msg.msg}##{e}")

        if igBeginPopupContextItem():
          if igMenuItem(cstring "Copiar " & FA_FilesO):
            app.win.setClipboardString(cstring msg.msg)

          igEndPopup()

      if app.inditab.processState != psFinished:
        igSpinner("##spinner", 30, 10, igGetColorU32(ButtonHovered))
      igEndListBox()

proc drawMain(app: var App) = # Draw the main window
  let viewport = igGetMainViewport()

  app.drawMainMenuBar()
  # Work area is the entire viewport minus main menu bar, task bars, etc.
  igSetNextWindowPos(viewport.workPos)
  igSetNextWindowSize(viewport.workSize)

  if igBegin(cstring app.config.name, flags = makeFlags(ImGuiWindowFlags.NoResize, NoDecoration, NoMove)):
    if igBeginTabBar("##tabs"):      
      if igBeginTabItem("Revision Clasificacion Alimentos"):
        app.currentTab = 0
        app.drawAlimentosTab()
        igEndTabItem()
      if igBeginTabItem("Generador Indicador"):
        app.currentTab = 1
        app.drawIndicadorTab()
        igEndTabItem()
      igEndTabBar()
  igEnd()

  # GLFW clipboard -> ImGui clipboard
  if (let clip = app.win.getClipboardString(); not clip.isNil and $clip != app.lastClipboard):
    igSetClipboardText(clip)
    app.lastClipboard = $clip

  # ImGui clipboard -> GLFW clipboard
  if (let clip = igGetClipboardText(); not clip.isNil and $clip != app.lastClipboard):
    app.win.setClipboardString(clip)
    app.lastClipboard = $clip

proc render(app: var App) = # Called in the main loop
  # Poll and handle events (inputs, window resize, etc.)
  glfwPollEvents() # Use glfwWaitEvents() to only draw on events (more efficient)

  # Start Dear ImGui Frame
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  # Draw application
  app.drawMain()

  # Render
  igRender()

  var displayW, displayH: int32
  let bgColor = igColorConvertU32ToFloat4(uint32 WindowBg)

  app.win.getFramebufferSize(displayW.addr, displayH.addr)
  glViewport(0, 0, displayW, displayH)
  glClearColor(bgColor.x, bgColor.y, bgColor.z, bgColor.w)
  glClear(GL_COLOR_BUFFER_BIT)

  igOpenGL3RenderDrawData(igGetDrawData())

  app.win.makeContextCurrent()
  app.win.swapBuffers()
  
proc keyboardCallback(window: GLFWWindow; key: int32; scancode: int32; action: int32; mods: int32): void {.cdecl.} = 
  # echo (k: key, s: scancode, a: action, m: mods)
  # Quit on Ctrl+W
  if key == GLFWKey.W.int32 and mods == GLFWModControl:
    quit(-1)

proc initWindow(app: var App) =
  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  if app.prefs[maximized]:
    glfwWindowHint(GLFWMaximized, GLFW_TRUE)

  app.win = glfwCreateWindow(
    app.prefs[winsize].w,
    app.prefs[winsize].h,
    cstring app.config.name,
    # glfwGetPrimaryMonitor(), # Show the window on the primary monitor
    icon = false # Do not use default icon
  )

  if app.win == nil:
    quit(-1)

  # Set the window icon
  var icon = initGLFWImage(app.res(app.config.iconPath).readImageFromMemory())
  app.win.setWindowIcon(1, icon.addr)

  # min width, min height, max widht, max height
  app.win.setWindowSizeLimits(app.config.minSize.w, app.config.minSize.h, GLFW_DONT_CARE, GLFW_DONT_CARE)

  # If negative pos, center the window in the first monitor
  if app.prefs[winpos].x < 0 or app.prefs[winpos].y < 0:
    var monitorX, monitorY, count, width, height: int32
    let monitor = glfwGetMonitors(count.addr)[0]#glfwGetPrimaryMonitor()
    let videoMode = monitor.getVideoMode()

    monitor.getMonitorPos(monitorX.addr, monitorY.addr)
    app.win.getWindowSize(width.addr, height.addr)
    app.win.setWindowPos(
      monitorX + int32((videoMode.width - width) / 2),
      monitorY + int32((videoMode.height - height) / 2)
    )
  else:
    app.win.setWindowPos(app.prefs[winpos].x, app.prefs[winpos].y)

  discard setKeyCallback(app.win, keyboardCallback)

proc initApp(): App =
  when defined(release):
    result.resources = readResources()

  result.config = Config()

  let filename =
    when defined(release): "prefs"
    else: "prefs_dev"

  let path = (result.getConfigDir() / filename).changeFileExt("kdl")

  try:
    result.prefs = initKPrefs(
      path = path,
      default = initPrefs()
    )
  except KdlError:
    let m = messageBox(result.config.name, &"Corrupt preferences file {path}.\nYou cannot continue using the app until it is fixed.\nYou may fix it manually or do you want to delete it and reset its content? You cannot undo this action", DialogType.OkCancel, IconType.Error, Button.No)
    if m == Button.Yes:
      discard tryRemoveFile(path)
      result.prefs = initKPrefs(
        path = path,
        default = initPrefs()
      )
    else:
      raise

  result.alitab.processState = psUnstarted

  result.alitab.foodColBuf = newString(100, result.prefs[alitab].lastFoodCol)
  result.alitab.observColBuf = newString(100, result.prefs[alitab].lastObservCol)
  result.alitab.file = (val: result.prefs[alitab].lastFile, flowvar: nil)

  result.inditab.file = (val: result.prefs[inditab].lastFile, flowvar: nil)
  result.inditab.dateFormatBuf = newString(100, result.prefs[inditab].lastDateFormat)

  result.updatePrefs()
  
  aliChannel.open()
  indiChannel.open()

template initFonts(app: var App) =
  # Merge ForkAwesome icon font
  let config = utils.newImFontConfig(mergeMode = true)
  let iconFontGlyphRanges = [uint16 FA_Min, uint16 FA_Max]

  for e, font in app.config.fonts:
    let glyph_ranges =
      case font.glyphRanges
      of GlyphRanges.Default: io.fonts.getGlyphRangesDefault()
      of ChineseFull: io.fonts.getGlyphRangesChineseFull()
      of ChineseSimplified: io.fonts.getGlyphRangesChineseSimplifiedCommon()
      of Cyrillic: io.fonts.getGlyphRangesCyrillic()
      of Japanese: io.fonts.getGlyphRangesJapanese()
      of Korean: io.fonts.getGlyphRangesKorean()
      of Thai: io.fonts.getGlyphRangesThai()
      of Vietnamese: io.fonts.getGlyphRangesVietnamese()

    app.fonts[e] = io.fonts.igAddFontFromMemoryTTF(app.res(font.path), font.size, glyph_ranges = glyph_ranges)

    # Here we add the icon font to every font
    if app.config.iconFontPath.len > 0:
      io.fonts.igAddFontFromMemoryTTF(app.res(app.config.iconFontPath), font.size, config.unsafeAddr, iconFontGlyphRanges[0].unsafeAddr)

proc terminate(app: var App) =
  sync() # Wait for spawned threads
  aliChannel.close()
  indiChannel.close()

  var x, y, width, height: int32

  app.win.getWindowPos(x.addr, y.addr)
  app.win.getWindowSize(width.addr, height.addr)

  app.prefs[winpos] = (x, y)
  app.prefs[winsize] = (width, height)
  app.prefs[maximized] = app.win.getWindowAttrib(GLFWMaximized) == GLFW_TRUE

  app.prefs[alitab].lastFoodCol = app.alitab.foodColBuf.cleanString()
  app.prefs[alitab].lastObservCol = app.alitab.observColBuf.cleanString()
  app.prefs[alitab].lastFile = app.alitab.file.val

  app.prefs[inditab].lastDateFormat = app.inditab.dateFormatBuf.cleanString()
  app.prefs[inditab].lastFile = app.inditab.file.val

  app.prefs.save()

proc main() =
  var app = initApp()

  # Setup Window
  doAssert glfwInit()
  app.initWindow()

  app.win.makeContextCurrent()
  glfwSwapInterval(1) # Enable vsync

  doAssert glInit()

  # Setup Dear ImGui context
  igCreateContext()
  let io = igGetIO()
  io.iniFilename = nil # Disable .ini config file

  # Setup Dear ImGui style using ImStyle
  app.res(app.config.stylePath).parseKdl().loadStyle().setCurrent()

  # Setup Platform/Renderer backends
  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  app.initFonts()

  # Main loop
  while not app.win.windowShouldClose:
    app.render()

  # Cleanup
  igOpenGL3Shutdown()
  igGlfwShutdown()

  igDestroyContext()

  app.terminate()
  app.win.destroyWindow()
  glfwTerminate()

when isMainModule:
  main()

