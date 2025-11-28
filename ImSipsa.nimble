# Package

author = "Patitotective"
description = "A new awesome Dear ImGui application"
license = "MIT"
backend = "cpp" # minidocx requires C++
srcDir = "src"
version = "1.0.1"
namedBin["indicador"] = "generadorDelIndicador-" & version

# Dependencies

requires "nim ^= 2.2.6"
requires "kdl ^= 2.0.3"
requires "excelin ^= 0.5.4"
requires "datamancer ^= 0.4.6"
requires "pretty ^= 0.2.0"
requires "https://github.com/Patitotective/minidocx-nim/ ^= 0.1.0"

import std/strformat

task windows, "Build exe from Linux":
  # Make sure to have mingw-w64 installed
  exec &"nim {backend} -d:mingw -o:{namedBin[\"indicador\"]}.exe src/indicador.nim"
