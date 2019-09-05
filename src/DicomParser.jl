module DicomParser

import DaikonJL: DicomImage, DicomTag, DicomTagDicts, DicomParserConsts, DicomUtils

using CodecZlib

mutable struct Parser
    littleEndian::Bool
    explicit::Bool
    metaFound::Bool
    metaFinished::Bool
    metaFinishedOffset::Number
    needsDeflate::Bool
    inflated
    encapsulation::Bool
    level::Number
    error
    Parser() = new(true, true, false, false, -1, false, nothing, false, 0, nothing)
end

function parse(parser::Parser, data::IOBuffer)
    image = nothing
    offset = nothing
    tag = nothing
    copyMeta = nothing
    copyDeflated = nothing
    # try
        image = DicomImage.Image()
        offset = findFirstTagOffset(parser, data)
        tag = getNextTag(parser, data, offset, false)
        while (tag !== nothing)
            DicomImage.putTag(image, tag)

            if (DicomTag.isPixelData(tag))
                break
            end

            if (parser.needsDeflate && (tag.offsetEnd >= parser.metaFinishedOffset))
                parser.needsDeflate = false
                copyMeta = data.buffer[1: tag.offsetEnd + 1]
                copyDeflated = data.buffer[(tag.offsetEnd + 2):end]
                parser.inflated = vcat(copyMeta, transcode(DeflateCompressor, data.data)) ### TODO zlib 
                data = parser.inflated
            end

            tag = getNextTag(parser, data, tag.offsetEnd, false) 
        end
    # catch err
        # println(err)
        # parser.error = err
    # end

    if (image != nothing)
        image.littleEndian = parser.littleEndian
    end

    return image
end

function isMagicCookieFound(parser::Parser, data::IOBuffer)::Bool
    offset = DicomParserConsts.MAGIC_COOKIE_OFFSET
    magicCookieLength = length(DicomParserConsts.MAGIC_COOKIE)
    ret = true
    for ctr = 0:magicCookieLength - 1
        if (DicomUtils.readposition(data, offset+ ctr, UInt8, true) != DicomParserConsts.MAGIC_COOKIE[ctr+1])
            break
        end
    end
    return ret
end


function findFirstTagOffset(parser::Parser, data::IOBuffer)
    offset = 0 
    magicCookieLength = length(DicomParserConsts.MAGIC_COOKIE)
    searchOffsetMax = DicomParserConsts.MAGIC_COOKIE_OFFSET * 5 
    found = false
    ctr = 0
    ctrIn = 0
    ch = 0


    magicCookieFound = isMagicCookieFound(parser, data) 
    if (magicCookieFound == true)
        offset = DicomParserConsts.MAGIC_COOKIE_OFFSET + magicCookieLength
    else 
        for ctr = 0:searchOffsetMax-1
            ch = DicomUtils.readposition(data, ctr, UInt8)
            if (ch == DicomParserConsts.MAGIC_COOKIE[1])
                found = true
                for ctrIn = 0:magicCookieLength-1
                    if (DicomUtils.readposition(data, ctrIn + ctr, UInt8) != DicomParserConsts.MAGIC_COOKIE[ctrIn+1])
                        found = false
                    end
                end

                if (found)
                    offset = ctr
                    break
                end
            end
        end 
    end
    return offset
end

function testForValidTag(parser::Parser, data::IOBuffer)
    tag = nothing
    offset = findFirstTagOffset(parser, data)
    tag = getNextTag(parser, data, offset, true)

    return tag
end

function getNextTag(parser::Parser, data::IOBuffer, offset, testForTag)
    group = 0
    value = nothing
    offsetStart = offset
    length = 0
    little = true
    vr = nothing

    if (offset >= Base.length(data.data))
        return nothing
    end

    if (parser.metaFinished)
        little = parser.littleEndian
        group = DicomUtils.readposition(data, offset, UInt16, little)
    else
        group = DicomUtils.readposition(data, offset, UInt16, true)
        if ((parser.metaFinishedOffset != -1 && offset >= parser.metaFinishedOffset) || group != 0x0002)
            parser.metaFinished = true
            little = parser.littleEndian
            group = DicomUtils.readposition(data, offset, UInt16, little) 
        else 
            little = true
        end
    end

    if (!parser.metaFound && group == 0x0002)
        parser.metaFound = true
    end

    offset += 2
    element = DicomUtils.readposition(data, offset, UInt16, little)
    offset += 2

    if (parser.explicit || !parser.metaFinished)
        vr = DicomUtils.readpositionstring(data, offset, 2)
        if (!parser.metaFound && parser.metaFinished && (vr in DicomParserConsts.DATA_VRS))
            vr = DicomTagDicts.getVr(group, element)
            length = DicomUtils.readposition(data, offset, UInt32, little)
            offset += 4
            parser.explicit = false
        else 
            offset += 2
            if (vr in DicomParserConsts.DATA_VRS)
                offset += 2
                length = DicomUtils.readposition(data, offset, UInt32, little)
                offset += 4
            else
                length = DicomUtils.readposition(data, offset, UInt16, little)
                offset += 2
            end
        end
    else 
        vr = DicomTagDicts.getVr(group, element)
        length = DicomUtils.readposition(data, offset, UInt32, little)

        if (length == DicomParserConsts.UNDEFINED_LENGTH)
            vr = "SQ"
        end

        offset += 4
    end
    offsetValue = offset

    isPixelData = (group == DicomTag.TAG_PIXEL_DATA[1]) && (element == DicomTag.TAG_PIXEL_DATA[2]);

    if (vr === "SQ" || (isPixelData && parser.encapsulation && (vr in DicomParserConsts.DATA_VRS)))
        value = parseSublist(parser, data, offset, length, vr !== "SQ")
        if (length == DicomParserConsts.UNDEFINED_LENGTH)
            length = value[length(value) - 1].offsetEnd - offset
        end
    elseif ((length > -1) && !testForTag)
        if (length == DicomParserConsts.UNDEFINED_LENGTH)
            if (isPixelData)
                length = length(data.data) - offset
            end
        end

        value = IOBuffer(data.data[(offset + 1): (offset + length +1)])
    end

    offset += length
    println("VR ", String(vr))

    tag = DicomTag.Tag(group, element, vr, value, false, offsetStart, offsetValue, offset, little)

    if (DicomTag.isTransformSyntax(tag))
        if (tag.value[1] == DicomParserConsts.TRANSFER_SYNTAX_IMPLICIT_LITTLE)
            parser.explicit = false
            parser.littleEndian = true
        elseif (tag.value[1] == DicomParserConsts.TRANSFER_SYNTAX_EXPLICIT_BIG)
            parser.explicit = true
            parser.littleEndian = false
        elseif ( tag.value[1] == DicomParserConsts.TRANSFER_SYNTAX_COMPRESSION_DEFLATE)
            parser.needsDeflate = true
            parser.explicit = true
            parser.littleEndian = true
        else 
            parser.explicit = true
            parser.littleEndian = true
        end
    elseif (DicomTag.isMetaLength(tag))
        parser.metaFinishedOffset = tag.value.data[1] + offset
    end

    return tag
end

function parseSublist(parser::Parser, data::IOBuffer, offset, length, raw)
    sublistItem = nothing
    offsetEnd = offset + length
    tags = []

    parser.level+=1

    if (length == DicomParserConsts.UNDEFINED_LENGTH)
        sublistItem = parseSublistItem(parser, data, offset, raw)
        while (!DicomTag.isSequentalDelim(sublistItem))
            push!(tags, sublistItem)
            offset = sublistItem.offsetEnd
            sublistItem = parseSublistItem(parser, data, offset, raw)
        end
        push!(parser, sublistItem)
    else 
        while (offset < offsetEnd)
            sublistItem = parseSublistItem(parser, data, offset, raw)
            push!(tags, sublistItem)
            offset = sublistItem.offsetEnd
        end
    end

    parser.level -= 1
    return tags
end

function parseSublistItem(parser::Parser, data::IO, offset, raw)
    group = nothing
    element = nothing
    length = nothing
    ofsetEnd = nothing
    tag = nothing
    offsetStart = offset
    value = nothing
    offetValue = nothing
    sublistItemTag = nothing
    tags = []

    group = DicomUtils.readposition(data, offset, UInt16, parser.littleEndian)
    offset += 2

    element = DicomUtils.readposition(data, offset, UInt16, parser.littleEndian)
    offset += 2

    length = DicomUtils.readposition(data, offset, UInt16, parser.littleEndian)
    offset += 4

    offsetValue = offset

    if (length == DicomParserConsts.UNDEFINED_LENGTH)
        tag = getNextTag(parser, data, offset)

        while(!DicomTag.isSublistItemDelim(tag))
            push!(tags, tag)
            offset = tag.offsetEnd
            tag = getNextTag(parser, data, offset)
        end

        push!(tags, tag)
        offset = tag.offsetEnd
    elseif (raw != nothing)
        value = data.buffer[(offset + 1), (offset + length +1)]
        offset = offset + length
    else 
        offsetEnd = offset + length

        while (offset < offsetEnd)
            tag = getNextTag(parser, data, offset)
            push!(tags, tag)
            offset = tag.offsetEnd
        end
    end

    if (value != nothing)
        sublistItemTag = DicomTag.Tag(group, element, nothing, value, false, offsetStart, offsetValue, offset, parser.littleEndian) 
    else 
        sublistItemTag = DicomTag.Tag(group, element, nothing, tags, true, offsetStart, offsetValue, offset, parser.littleEndian)
    end
    return sublistItemTag
end

function parseEncapsulated(parser::Parser, data::IO)
    offset = 1
    tag = nothing
    tags = []

    parser.encapsulation = true

    try
        tag = getNextTag(parser, data, offset)

        while(tag != nothing)
            if DicomTag.isSublistItem(tag)
                push!(tags, tag)
            end

            tag = getNextTag(parser, data, offset)
        end

    catch err
        parser.err = err
    end

    return tags
end


end

