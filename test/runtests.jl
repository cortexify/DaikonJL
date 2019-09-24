import DaikonJL: DicomParser

dcm = open("0003.DCM")
buffer = IOBuffer(read(dcm, String))
parser = DicomParser.Parser()
image = DicomParser.parse(parser, buffer)
println(image