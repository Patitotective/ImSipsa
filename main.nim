import std/[threadpool, enumerate, strutils, strformat, os]

import imstyle
import openurl
import tinydialogs
import kdl, kdl/prefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[settingsmodal, utils, types, icons, process]
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
      for e, observ in app.prefs[forbidden][app.currentFood].deepCopy:
        if igSelectable(cstring &"{observ}##{e}"):
          app.currentObserv = e
          app.observBuf = newString(100, observ)
          igOpenPopup("###editObserv")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            echo (e: e, c: app.currentObserv)
            app.prefs[forbidden][app.currentFood].delete(app.currentObserv)

          igEndPopup()

      if drawEditModal("Editar observacion###editObserv", cstring app.observBuf):
        app.prefs[forbidden][app.currentFood][app.currentObserv] = app.observBuf.cleanString

      igEndListBox()

    if igButton("Add"):
      app.prefs[forbidden][app.currentFood].add "Observacion"

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

      for e, (key, val) in enumerate app.prefs[forbidden].deepCopy.pairs:
        igTableNextRow()

        igTableNextColumn()
        if igSelectable(cstring key, flags = ImGuiSelectableFlags.DontClosePopups):
          app.currentFood = key
          app.foodBuf = newString(100, key)
          igOpenPopup("###editFood")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            app.prefs[forbidden].del(key)

          igEndPopup()

        igTableNextColumn()
        if igSelectable(cstring val.join(", "), flags = ImGuiSelectableFlags.DontClosePopups):
          app.currentFood = key
          igOpenPopup("###editObservs")

        if igBeginPopupContextItem():
          if igMenuItem(cstring &"Borrar {FA_TrashO}"):
            app.prefs[forbidden].del(key)
          igEndPopup()

      if drawEditModal("Editar alimento###editFood", cstring app.foodBuf):
        app.prefs[forbidden][app.foodBuf.cleanString] = app.prefs[forbidden][app.currentFood]
        app.prefs[forbidden].del(app.currentFood)

      app.drawEditObservsModal()

      igEndTable()

    if igButton("Añadir"):
      var n = 1
      while &"Alimento #{n}" in app.prefs[forbidden]:
        inc n

      app.prefs[forbidden][&"Alimento #{n}"] = @["Observacion"]

    igEndPopup()

proc drawMainMenuBar(app: var App) =
  var openAbout, openPrefs, openBlockdialog, openForbidden = false

  if igBeginMainMenuBar():
    if igBeginMenu("Archivo"):
      # igMenuItem("Settings " & FA_Cog, "Ctrl+P", openPrefs.addr)
      if igMenuItem("Volver al inicio", enabled = app.processState == psFinished):
        app.errors.setLen(0)
        app.processError.setLen(0)
        app.processState = psUnstarted

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

proc drawMain(app: var App) = # Draw the main window
  let viewport = igGetMainViewport()

  app.drawMainMenuBar()
  # Work area is the entire viewport minus main menu bar, task bars, etc.
  igSetNextWindowPos(viewport.workPos)
  igSetNextWindowSize(viewport.workSize)

  if igBegin(cstring app.config.name, flags = makeFlags(ImGuiWindowFlags.NoResize, NoDecoration, NoMove)):
    if app.processState == psUnstarted:
      # Input
      if not app.file.flowvar.isNil and app.file.flowvar.isReady and (let val = ^app.file.flowvar; val.len > 0):
        app.file = (val: val, flowvar: nil) # Here we set flowvar to nil because once we acquire its value it's not neccessary until it's spawned again
        if app.output.val.len == 0:
          let path = val.splitPath()
          app.output.val = path.head / ("Procesado "  & path.tail)

      igInputTextWithHint("##file", "Ningun archivo seleccionado", cstring app.file.val, uint app.file.val.len, flags = ImGuiInputTextFlags.ReadOnly)
      igSameLine()
      if igButton("Examinar " & FA_FolderOpen):
        app.file.flowvar = spawn openFileDialog("Elige un archivo", getCurrentDir() / "\0", ["*.xlsx"], "Excel 2007-365")
        igOpenPopup("###blockdialog")

      # Output
      if not app.output.flowvar.isNil and app.output.flowvar.isReady and (let val = ^app.output.flowvar; val.len > 0):
        app.output = (val: val, flowvar: nil) # Here we set flowvar to nil because once we acquire it's value it's not neccessary until it's spawned again
      
      igInputTextWithHint("##output", "Archivo de resultado", cstring app.output.val, uint app.output.val.len, flags = ImGuiInputTextFlags.ReadOnly)
      igSameLine()
      if igButton("Examinar " & FA_FolderOpen):
        app.output.flowvar = spawn saveFileDialog("Elige el archivo de resultado", getCurrentDir() / "\0", ["*.xlsx"], "Excel 2007-365")
        igOpenPopup("###blockdialog")

      app.drawBlockDialogModal()
    
      # Other 
      igInputText("Hoja##sheet", cstring app.sheetBuf, 100)
      igInputText("Columna alimentos##foodsCol", cstring app.foodColBuf, 2)
      igInputText("Columna observaciones##observCol", cstring app.observColBuf, 2)

      if app.file.val.len == 0 or app.output.val.len == 0:
        igPushDisabled()

      if igButton("Procesar##process"):
        spawn validateExcel(app.file.val, app.output.val, app.sheetBuf.cleanString, 
          app.foodColBuf.cleanString, app.observColBuf.cleanString, app.prefs[forbidden])
        app.processState = psRunning
        # startProcess((path: app.file.val, outPath: app.output.val, 
        #   sheet: app.sheetBuf.cleanString, foodsCol: app.foodColBuf.cleanString, 
        #   observCol: app.observColBuf.cleanString, forbiddenTable: app.prefs[forbidden]
        # ))

      if app.file.val.len == 0 or app.output.val.len == 0:
        igPopDisabled()

    else:
      if (let (ok, msg) = fromProcess.tryRecv; ok):
        case msg.kind
        of mkData:
          app.errors.add (msg.pos, msg.food, msg.observ)
        of mkError:
          spawn notifyPopup(msg.title, msg.msg, IconType.Error)
          app.processError = &"{msg.title}: {msg.msg}"
          app.processState = psFinished
        of mkFinished:
          app.processState = psFinished
          spawn notifyPopup("Termino", &"Resultado: {app.output.val}", IconType.Info)

      if app.processState == psFinished:
        igText("Completado")

      if app.processError.len > 0:
        igPushTextWrapPos(igGetWindowWidth())
        igTextWrapped(cstring app.processError)
        igPopTextWrapPos()

      if igBeginListBox("##listbox", igGetContentRegionAvail()):
        for e, error in app.errors:
          igSelectable(cstring &"{error.pos}: Alimento {error.food} contiene {error.observ}##{e}")
          if igBeginPopupContextItem():
            if igMenuItem(cstring "Copia " & FA_FilesO):
              app.win.setClipboardString(cstring error.pos)

            igEndPopup()

        if app.processState != psFinished:
          igSpinner("##spinner", 30, 10, igGetColorU32(ButtonHovered))
        igEndListBox()

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

  result.processState = psUnstarted

  result.sheetBuf = newString(100, result.prefs[lastSheet])
  result.foodColBuf = newString(2, result.prefs[lastFoodCol])
  result.observColBuf = newString(2, result.prefs[lastObservCol])
  result.file = (val: result.prefs[lastFile], flowvar: nil)
  if result.file.val.len > 0:
    let path = result.file.val.splitPath()
    result.output.val = path.head / ("Procesado "  & path.tail)

  result.updatePrefs()
  
  fromProcess.open()

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
  fromProcess.close()

  var x, y, width, height: int32

  app.win.getWindowPos(x.addr, y.addr)
  app.win.getWindowSize(width.addr, height.addr)

  app.prefs[winpos] = (x, y)
  app.prefs[winsize] = (width, height)
  app.prefs[maximized] = app.win.getWindowAttrib(GLFWMaximized) == GLFW_TRUE

  app.prefs[lastSheet] = app.sheetBuf.cleanString()
  app.prefs[lastFoodCol] = app.foodColBuf.cleanString()
  app.prefs[lastObservCol] = app.observColBuf.cleanString()
  app.prefs[lastFile] = app.file.val

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

