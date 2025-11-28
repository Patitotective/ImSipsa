switch("backend", "cpp")
switch("warning", "HoleEnumConv:off")
switch("cpu", "amd64")
patchFile("untar", "untar/gzip", "patches/gzip")

when defined(Windows):
  switch("passC", "-static")
  switch("passL", "-static")
