include("../src/DicomTagDicts.jl")
include("../src/DicomImage.jl")

println(Dictionary.getVr(0x4010, 0x1069))
println(Dictionary.getDescription(0x4010, 0x1069))
println(DicomImage.Image())