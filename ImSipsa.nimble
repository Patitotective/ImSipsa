# Package

author = "Patitotective"
description = "It processes CSV data and outputs a DOCX file"
license = "MIT"
backend = "cpp" # minidocx requires C++
srcDir = "src"
version = "1.1.0"
namedBin["indicador"] =
  "generadorDelIndicador-" & version & (when defined(Windows): ".exe" else: "")
binDir = "bin"

# Dependencies

requires "nim ^= 2.2.0"
requires "kdl ^= 2.0.0"
requires "excelin ^= 0.5.0"
requires "datamancer ^= 0.5.0"
requires "pretty ^= 0.2.0"
requires "https://github.com/Patitotective/minidocx-nim/ ^= 0.1.0"
