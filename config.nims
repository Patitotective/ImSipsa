switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("warning", "ImplicitDefaultValue:off")
switch("threads", "on")
switch("deepcopy", "on")

patchFile("excelin", "internal_cells", "internal_cells.nim")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
