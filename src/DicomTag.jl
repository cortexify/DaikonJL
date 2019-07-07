module DicomTag
include("./DicomUtils.jl")

struct Tag
    group
    element
    vr::String
    value # 
    offsetStart
    offsetValue
    offsetEnd
    sublist::Bool # false
    preformatted::Bool # false
    id

    #TODO convert value to proper type
    function Tag(group, element, vr, value::IOBuffer, isArray::Bool, offsetStart, offsetValue, offsetEnd, littleEndian)
        id = createId(group, element)
        sublist = false
        preformatted = false
        if (isArray)
            sublist = true
        elseif (value != nothing)
            #TODO convert value to proper type here
            #TODO set preformatted here according to converted value
        end
        return new(group, element, vr, value, offsetStart, offsetValue, offsetEnd, sublist, preformatted, littleEndian, id)
    end
end

# const PRIVATE_DATA_READERS = [daikon.Siemens]

const VR_AE_MAX_LENGTH = 16
const VR_AS_MAX_LENGTH = 4
const VR_AT_MAX_LENGTH = 4
const VR_CS_MAX_LENGTH = 16
const VR_DA_MAX_LENGTH = 8
const VR_DS_MAX_LENGTH = 16
const VR_DT_MAX_LENGTH = 26
const VR_FL_MAX_LENGTH = 4
const VR_FD_MAX_LENGTH = 8
const VR_IS_MAX_LENGTH = 12
const VR_LO_MAX_LENGTH = 64
const VR_LT_MAX_LENGTH = 10240
const VR_OB_MAX_LENGTH = -1
const VR_OD_MAX_LENGTH = -1
const VR_OF_MAX_LENGTH = -1
const VR_OW_MAX_LENGTH = -1
const VR_PN_MAX_LENGTH = 64 * 5
const VR_SH_MAX_LENGTH = 16
const VR_SL_MAX_LENGTH = 4
const VR_SS_MAX_LENGTH = 2
const VR_ST_MAX_LENGTH = 1024
const VR_TM_MAX_LENGTH = 16
const VR_UI_MAX_LENGTH = 64
const VR_UL_MAX_LENGTH = 4
const VR_UN_MAX_LENGTH = -1
const VR_US_MAX_LENGTH = 2
const VR_UT_MAX_LENGTH = -1

const TAG_TRANSFER_SYNTAX = [0x0002, 0x0010]
const TAG_META_LENGTH = [0x0002, 0x0000]

const TAG_SUBLIST_ITEM = [0xFFFE, 0xE000]
const TAG_SUBLIST_ITEM_DELIM = [0xFFFE, 0xE00D]
const TAG_SUBLIST_SEQ_DELIM = [0xFFFE, 0xE0DD]

const TAG_ROWS = [0x0028, 0x0010]
const TAG_COLS = [0x0028, 0x0011]
const TAG_ACQUISITION_MATRIX = [0x0018, 0x1310]
const TAG_NUMBER_OF_FRAMES = [0x0028, 0x0008]
const TAG_NUMBER_TEMPORAL_POSITIONS = [0x0020, 0x0105]

const TAG_PIXEL_SPACING = [0x0028, 0x0030]
const TAG_SLICE_THICKNESS = [0x0018, 0x0050]
const TAG_SLICE_GAP = [0x0018, 0x0088]
const TAG_TR = [0x0018, 0x0080]
const TAG_FRAME_TIME = [0x0018, 0x1063]

const TAG_BITS_ALLOCATED = [0x0028, 0x0100]
const TAG_BITS_STORED = [0x0028, 0x0101]
const TAG_PIXEL_REPRESENTATION = [0x0028, 0x0103]
const TAG_HIGH_BIT = [0x0028, 0x0102]
const TAG_PHOTOMETRIC_INTERPRETATION = [0x0028, 0x0004]
const TAG_SAMPLES_PER_PIXEL = [0x0028, 0x0002]
const TAG_PLANAR_CONFIG = [0x0028, 0x0006]
const TAG_PALETTE_RED = [0x0028, 0x1201]
const TAG_PALETTE_GREEN = [0x0028, 0x1202]
const TAG_PALETTE_BLUE = [0x0028, 0x1203]

const TAG_DATA_SCALE_SLOPE = [0x0028, 0x1053]
const TAG_DATA_SCALE_INTERCEPT = [0x0028, 0x1052]
const TAG_DATA_SCALE_ELSCINT = [0x0207, 0x101F]
const TAG_PIXEL_BANDWIDTH = [0x0018, 0x0095]

const TAG_IMAGE_MIN = [0x0028, 0x0106]
const TAG_IMAGE_MAX = [0x0028, 0x0107]
const TAG_WINDOW_CENTER = [0x0028, 0x1050]
const TAG_WINDOW_WIDTH = [0x0028, 0x1051]

const TAG_PATIENT_NAME = [0x0010, 0x0010]
const TAG_PATIENT_ID = [0x0010, 0x0020]
const TAG_STUDY_DATE = [0x0008, 0x0020]
const TAG_STUDY_TIME = [0x0008, 0x0030]
const TAG_STUDY_DES = [0x0008, 0x1030]
const TAG_IMAGE_TYPE = [0x0008, 0x0008]
const TAG_IMAGE_COMMENTS = [0x0020, 0x4000]
const TAG_SEQUENCE_NAME = [0x0018, 0x0024]
const TAG_MODALITY = [0x0008, 0x0060]

const TAG_FRAME_OF_REF_UID = [0x0020, 0x0052]

const TAG_STUDY_UID = [0x0020, 0x000D]

const TAG_SERIES_DESCRIPTION = [0x0008, 0x103E]
const TAG_SERIES_INSTANCE_UID = [0x0020, 0x000E]
const TAG_SERIES_NUMBER = [0x0020, 0x0011]
const TAG_ECHO_NUMBER = [0x0018, 0x0086]
const TAG_TEMPORAL_POSITION = [0x0020, 0x0100]

const TAG_IMAGE_NUM = [0x0020, 0x0013]
const TAG_SLICE_LOCATION = [0x0020, 0x1041]

const TAG_IMAGE_ORIENTATION = [0x0020, 0x0037]
const TAG_IMAGE_POSITION = [0x0020, 0x0032]
const TAG_SLICE_LOCATION_VECTOR = [0x0018, 0x2005]

const TAG_LUT_SHAPE = [0x2050, 0x0020]

const TAG_PIXEL_DATA = [0x7FE0, 0x0010]


function createId(group, element)
    groupStr = string(group, base=16, pad=4)
    elemStr = string(element, base=16, pad=4)
    return groupStr * elemStr
end

function getUnsignedInteger16(rawData::IOBuffer, T, littleEndian::Bool)
    data = []
    mul = length(rawData) / 2
    for ctr = 1:mul+1
        push!(data, DicomUtils.readposition(rawData, (ctr * 2) - 1), T)
    end

    return data
end

# NOTE toStrin is not written
# NOTE toHtmlString is not written

function isTransformSyntax(tag::Tag)
    return (tag.group == TAG_TRANSFER_SYNTAX[1]) && (tag.element == TAG_TRANSFER_SYNTAX[2]) 
end

function isPixelData(tag::Tag)
    return (tag.group == TAG_PIXEL_DATA[1]) && (tag.element == TAG_PIXEL_DATA[2])
end  

function isPrivateData(tag::Tag)
    return (tag.group & 1) == 1
end

# function hasINterpretedPrivateData(tag::Tag)
#      # TODO implement utils
#     return (isPrivateData(tag) && )
# end

function isSublistItem(tag::Tag)
    return (tag.group == TAG_SUBLIST_ITEM[1]) && (tag.element == TAG_SUBLIST_ITEM[2])
end

function isSublistItemDelim(tag::Tag)
    return (tag.group == TAG_SUBLIST_ITEM_DELIM[1]) && (tag.element == TAG_SUBLIST_ITEM_DELIM[2])
end

function isSequenceDelim(tag::Tag)
    return (tag.group == TAG_SUBLIST_SEQ_DELIM[1]) && (tag.element == TAG_SUBLIST_SEQ_DELIM[2])
end

function isMetaLength(tag::Tag)
    return (tag.group == TAG_META_LENGTH[1]) && (tag.element == TAG_META_LENGTH[2])
end

function convertValue(vr::String, rawData::IOBuffer, littleEndian::Bool) 
    data = nothing

    if (vr === "AE") 
        data = getSingleStringValue(rawData, VR_AE_MAX_LENGTH)
    elseif (vr === "AS")
        data = getFixedLengthStringValue(rawData, VR_AS_MAX_LENGTH)
    elseif (vr === "AT")
        data = getUnsignedInteger16(rawData) # ADD endianness
    elseif (vr === "JCS")
        data = getStringValue(rawData)
    elseif (vr === "DA")
        data = getDateStringValue(rawData)
    elseif (vr === "DS")
        data = getDoubleStringValue(rawData)
    elseif (vr === "DT")
        data = getDateTimeStringValue(rawData)
    elseif (vr === "FL")
        data = getFloat32(rawData, littleEndian)
    elseif (vr === "FD")
        data = getFloat64(rawData, littleEndian)
    elseif (vr === "FE")  
        data = getDoubleElscint(rawData, littleEndian)
    elseif (vr === "IS")
        data = getIntegerStringValue(rawData)
    elseif (vr === "LO")
        data = getStringValue(rawData)
    elseif (vr === "LT")
        data = getSingleStringValue(rawData)
    elseif (vr === "OB")
        data = rawData
    elseif (vr === "OD")
        data = rawData
    elseif (vr === "OF")
        data = rawData
    elseif (vr === "OW")
        data = rawData
    elseif (vr === "PN")
        data = getPersonNameStringValue(rawData)
    elseif (vr === "SH")
        data = getStringValue(rawData)
    elseif (vr === "SL")
        data = getSignedInteger32(rawData, littleEndian)
    elseif (vr === "SQ")
        data = null
    elseif (vr === "SS")
        data = getSignedInteger16(rawData, littleEndian)
    elseif (vr === "ST")
        data = getSingleStringValue(rawData)
    elseif (vr === "TM")
        data = getTimeStringValue(rawData)
    elseif (vr === "UI")
        data = getStringValue(rawData)
    elseif (vr === "UL")
        data = getUnsignedInteger32(rawData, littleEndian)
    elseif (vr === "UN")
        data = rawData
    elseif (vr === "US")
        data = getUnsignedInteger16(rawData, littleEndian)
    elseif (vr === "UT")
        data = getSingleStringValue(rawData)
    end

    return data;
end

function getSingleStringValue(rawData::IO)
    return [read(rawData, String)]
end

end