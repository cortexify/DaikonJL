import DaikonJL: DicomParser, DicomImage


dcm = open("0003.DCM")
buffer = IOBuffer(read(dcm, String))
parser = DicomParser.Parser()
image = DicomParser.parse(parser, buffer)
show(image)
# show(DicomImage.getRawData(image).data)
# println(image)