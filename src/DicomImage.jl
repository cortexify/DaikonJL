module DicomImage
import DaikonJL: DicomParserConsts, DicomUtils, DicomTag

mutable struct Image
    tags
    tagsFlat
    littleEndian::Bool
    index::Number
    decompressed::Bool
    privateDataAll
    convertedPalette::Bool
    Image() = new(Dict{String, DicomTag.Tag}(), Dict{String, Any}(), false, -1, false, nothing, false)
end

const SLICE_DIRECTION_UNKNOWN = -1
const SLICE_DIRECTION_AXIAL = 2
const SLICE_DIRECTION_CORONAL = 1
const SLICE_DIRECTION_SAGITTAL = 0
const SLICE_DIRECTION_OBLIQUE = 3
const OBLIQUITY_THRESHOLD_COSINE_VALUE = 0.8

const BYTE_TYPE_UNKNOWN = 0
const BYTE_TYPE_BINARY = 1
const BYTE_TYPE_INTEGER = 2
const BYTE_TYPE_INTEGER_UNSIGNED = 3
const BYTE_TYPE_FLOAT = 4
const BYTE_TYPE_COMPLEX = 5
const BYTE_TYPE_RGB = 6


skipPaletteConversion = false

function getSingleValueSafely(tag, index) 
    if (tag && tag.value)
        return tag.value[index]
    end

    return nothing 
end

function getValueSafely(tag)
    if (tag != nothing)
        return tag.value
    end

    return nothing 
end

function getMajorAxisFromPatientRelativeDirectionCosine(x, y, z)
    axis = nothing
    orientationX = x < 0 ? "R" : "L"
    orientationY = y < 0 ? "A" : "P"
    orientationZ = z < 0 ? "F" : "H"

    absX = abs(x)
    absY = abs(y)
    absZ = abs(z)

    if ((absX > OBLIQUITY_THRESHOLD_COSINE_VALUE) && (absX > absY) && (absX > absZ))
        axis = orientationX
    elseif ((absY > OBLIQUITY_THRESHOLD_COSINE_VALUE) && (absY > absX) && (absY > absZ))
        axis = orientationY
    elseif ((absZ > OBLIQUITY_THRESHOLD_COSINE_VALUE) && (absZ > absX) && (absZ > absY))
        axis = orientationZ
    else 
        axis = nothing
    end

    return axis
end

function getCols(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_COLS[1], DicomTag.TAG_COLS[2]), 1)
end

function getRows(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_ROWS[1], DicomTag.TAG_ROWS[2]), 1)
end

function getSeriesDescription(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SERIES_DESCRIPTION[1], DicomTag.TAG_SERIES_DESCRIPTION[2]), 1)
end

function getSeriesInstanceUID(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SERIES_INSTANCE_UID[1], DicomTag.TAG_SERIES_INSTANCE_UID[2]), 1)
end

function getSeriesNumber(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SERIES_NUMBER[1], DicomTag.TAG_SERIES_NUMBER[2]), 1)
end

function getEchoNumber(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_ECHO_NUMBER[1], DicomTag.TAG_ECHO_NUMBER[2]), 1)
end

function getImagePosition(image::Image)
    return getValueSafely(getTag(image, DicomTag.TAG_IMAGE_POSITION[1], DicomTag.TAG_IMAGE_POSITION[2]))
end

function getImageDirections(image::Image)
    return getValueSafely(getTag(image, DicomTag.TAG_IMAGE_DIRECTIONS[1], DicomTag.TAG_IMAGE_DIRECTIONS[2]))
end

function getImagePositionSliceDir(image::Image, sliceDir)
    imagePos = getValueSafely(getTag(image, DicomTag.TAG_IMAGE_POSITION[1], DicomTag.TAG_IMAGE_POSITION[2]))
    if (imagePos)
        if (sliceDir >= 1)
            return imagePos[sliceDir]
        end
    end
    return 1
end

function getModality(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_MODALITY[1], DicomTag.TAG_MODALITY[2]), 1)
end

function getSliceLocation(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SLICE_LOCATION[1], DicomTag.TAG_SLICE_LOCATION[2]), 1)
end

function getSliceLocationVector(image::Image)
    return getValueSafely(getTag(image, DicomTag.TAG_SLICE_LOCATION_VECTOR[1], DicomTag.TAG_SLICE_LOCATION_VECTOR[2]))
end

function getImageNumber(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_IMAGE_NUM[1], DicomTag.TAG_IMAGE_NUM[2]), 1)
end

function getTemporalPosition(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_TEMPORAL_POSITION[1], DicomTag.TAG_TEMPORAL_POSITION[2]), 1)
end

function getTemporalNumber(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_NUMBER_TEMPORAL_POSITIONS[1], DicomTag.TAG_NUMBER_TEMPORAL_POSITIONS[2]), 1)
end

function getSliceGap(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SLICE_GAP[1], DicomTag.TAG_SLICE_GAP[2]), 1)
end

function getSliceThickness(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_SLICE_THICKNESS[1], DicomTag.TAG_SLICE_THICKNESS[2]), 1)
end

function getImageMax(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_IMAGE_MAX[1], DicomTag.TAG_IMAGE_MAX[2]), 1)
end

# function getImageMax(image::Image)
#     return getSingleValueSafely(getTag(image, DicomTag.TAG_IMAGE_MIN[1], DicomTag.TAG_IMAGE_MIN[2]), 1)
# end

function getDataScaleSlop(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_DATA_SCALE_SLOPE[1], DicomTag.TAG_DATA_SCALE_SLOPE[2]), 1)
end

function getDataScaleIntercept(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_DATA_SCALE_INTERCEPT[1], DicomTag.TAG_DATA_SCALE_INTERCEPT[2]), 1)
end

function getDataScaleElscint(image::Image)
    scale = getSingleValueSafely(getTag(image, DicomTag.TAG_DATA_SCALE_ELSCINT[1], DicomTag.TAG_DATA_SCALE_ELSCINT[2]), 1)

    if (scale === nothing || scale == 0.0)
        scale = 1
    end

    bandwidth = image.getPixelBandwith()
    scale = sqrt(bandwidth) / (10 * scale)

    if (scale <= 0)
        scale = 1
    end
    
    return scale
end

function getWindowWidth(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_WINDOW_WIDTH[1], DicomTag.TAG_WINDOW_WIDTH[2]), 1)
end

function getWindowCenter(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_WINDOW_CENTER[1], DicomTag.TAG_WINDOW_CENTER[2]), 1)
end

function getPixelBandwidth(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_PIXEL_BANDWIDTH[1], DicomTag.TAG_PIXEL_BANDWIDTH[2]), 1)
end


function getSeriesId(image::Image)
    des = getSeriesDescription(image)
    uid = getSeriesInstanceUID(image)
    num = getSeriesNumber(image)
    echo = getEchoNumber(image)
    orientation = getOrientation(image)
    cols = getCols(image)
    rows = getRows(image)

    id = ""

    if (des != nothing)
        id *= (" " * des)
    end

    if (uid != nothing)
        id *= (" " * uid)
    end

    if (num != nothing)
        id *= (" " * num)
    end

    if (echo != nothing)
        id *= (" " * echo)
    end

    if (orientation != nothing)
        id *= (" " * orientation)
    end

    id *= (" (" * cols * " x" * rows * ")")
    
    return id
end

function getPixelSpacing(image::Image)
    return getValueSafely(getTag(image, DicomTag.TAG_PIXEL_SPACING[1], DicomTag.TAG_PIXEL_SPACING[2]))
end

function getImageType(image::Image)
    return getValueSafely(getTag(image, DicomTag.TAG_IMAGE_TYPE[1], DicomTag.TAG_IMAGE_TYPE[2]))
end

function getBitsStored(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_BITS_STORED[1], DicomTag.TAG_BITS_STORED[2]), 1)
end

function getBitsAllocated(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_BITS_ALLOCATED[1], DicomTag.TAG_BITS_ALLOCATED[2]), 1)
end

function getFrameTime(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_FRAME_TIME[1], DicomTag.TAG_FRAME_TIME[2]), 1)
end

function getAcquisitionMatrix(image::Image)
    mat = [0, 0]

    mat[1] = getSingleValueSafely(getTag(image, DicomTag.TAG_ACQUISITION_MATRIX[1], DicomTag.TAG_ACQUISITION_MATRIX[2]), 1)

    if (image.privateDataAll === nothing)
        image.privateDataAll = getAllInterpretedPrivateData(image)
    end

    if ((image.privateDataAll != nothing), (length(image.privateDataAll) > 0))
        start_end = findfirst("AcquisitionMatrixText", image.privateDataAll)

        if (start_end != nothing)
            start = start_end.start
            start_end = findfirst("\n", image.privateDataAll)
            if(start_end != nothing)
                _end = start_end.stop
                str = image.privateDataAll[start:_end]
                rx = r"\d+"
                matPrivate = match(rx, str).match

                if ((matPrivate != nothing) && length(matPrivate == 2))
                    mat[1] = matPrivate[1]
                    mat[2] = matPrivate[2]
                elseif((matPrivate != nothing) && length(matPrivate == 1))
                    mat[1] = matPrivate[1]
                end
            end
        end

        if (mat[2] == 0)
            mat[2] = mat[1]
        end

        return mat
    end
end

function getTR(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_TR[1], DicomTag.TAG_TR[2]), 1)
end

function putTag(image::Image, tag)
    image.tags[tag.id] = tag
    putFlattenedTag(image, image.tagsFlat, tag)
end

function putFlattenedTag(image::Image, tags, tag)
    if(isdefined(tag, :sublist) && tag.sublist != nothing)
        for ctr = 1:length(tag.value.data)
            putFlattenedTag(image, tags, tag.value.data[ctr])
        end
    else
        if (isdefined(tag, :id) && get(tags, tag.id, nothing) === nothing)
            tag[tag.id] = tag
        end
    end
end

function getTag(image::Image, group, element)
    tagId = DicomTag.createId(group, element)

    if(get(image.tags, tagId, nothing) != nothing)
        return image.tags[tagId] 
    end

    return get(image.tagsFlat, tagId, nothing)
end


function getPixelData(image::Image)
    return image.tags[DicomTag.createId(DicomTag.TAG_PIXEL_DATA[1], DicomTag.TAG_PIXEL_DATA[2])]
end

function getPixelDataBytes(image::Image)
    # if (isCompressed(image))
    #     decompress(image)
    # end

    # if (isPalette() && !skipPaletteConversion)
    #     convertPalette(image)
    # end

    # TODO 
    return image.tags[DicomTag.createId(DicomTag.TAG_PIXEL_DATA[1], DicomTag.TAG_PIXEL_DATA[2])].value
end

function getRawData(image::Image)
    return getPixelDataBytes(image)
end

# function getInterpretedData(image::Image, asArray, asObject, frameIndex)
#     allFrames = false
#     mask = DicomUtils.createBitMask(getBitsAllocated(image) / 8, getBitsStored(image), getDataType(image) == DicomImage.BYTE_TYPE_INTEGER_UNSIGNED)
#     dataType = getPixelRepresentation(image) ? DicomImage.BYTE_TYPE_INTEGER : DicomImage.BYTE_TYPE_INTEGER_UNSIGNED
#     numBytes = getBitsAllocated(image) / 8
#     rawData = getRawData(image)
#     totalElements = length(rawData) / numBytes
#     elementsPerFrame = totalElements / getNumberOfFrames(image)
#     numElements = allFrames ? totalElements : elementsPerFrame
#     offset = allFrames ? 0 : frameIndex * elementsPerFrame
#     slope = getDataScaleSlope(image) || 1
#     intercept = getDataScaleIntercept(image) || 0
#     min = DicomUtils.MAX_VALUE
#     max = DicomUtils.MIN_VALUE

#     minIndex = -1
#     maxIndex = -1

#     if (asArray != nothing)
#         data =  
#     else
#     end
# end

function isCompressed(image::Image)
    transferSyntax = getTransferSyntax(image)
    if (transferSyntax)
        contains_jpeg = findfirst(DicomParserConsts.TRANSFER_SYNTAX_COMPRESSION_JPEG, transferSyntax)
        contains_rle = findfirst(DicomParserConsts.TRANSFER_SYNTAX_COMPRESSION_RLE)
        if (contains_jpeg != nothing)
            return true
        elseif(contains_rle != nothing)
            return true
        end
    end
    return false
end

function getTransferSyntax(image::Image)
    return getSingleValueSafely(getTag(image, DicomTag.TAG_STUDY_DATE[1], DicomTag.TAG_STUDY_DATE[2]), 1)
end

# function decompress(image::Image)
#     decompressed = nothing

#     if (!image.decompressed)
#         image.decompressed = true
#         frameSize = getRows(image) * getCols(image) * ceil(getBitsAllocated(image) / 8) # TODO Note parseInt

#         numFrames = getNumberOfFrames(image)

#         if (isCompressedJPEGLossless(image))
#             jpegs = getJpegs(image)

#             for ctr=1:length(jpegs)
#                 decode
#             end
#         end
#     end
# end

end