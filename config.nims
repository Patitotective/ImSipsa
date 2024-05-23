switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("warning", "ImplicitDefaultValue:off")
switch("threads", "on")
switch("deepcopy", "on")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
