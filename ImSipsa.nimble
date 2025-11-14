# Package

author = "Patitotective"
description = "A new awesome Dear ImGui application"
license = "MIT"
backend = "cpp" # minidocx requires C++
srcDir = "src"
version = "1.0.1"
namedBin["indicador"] = "generadorDelIndicador-" & version

# Dependencies

requires "nim >= 1.6.2"
# requires "kdl >= 2.0.1"
requires "excelin >= 0.5.4"
requires "datamancer >= 0.4.2"
requires "pretty >= 0.2.0"
requires "https://github.com/Patitotective/minidocx-nim/ >= 0.1.0"
