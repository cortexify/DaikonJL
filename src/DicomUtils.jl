module DicomUtils

crcTable = nothing

MAX_VALUE = 9007199254740991
MIN_VALUE = -9007199254740991


# TODO add endianness
function readposition(io::IO, offset, T, isLittleEndian::Bool)
    mark(io)
    seekstart(io)
    seek(io, offset)
    ret = read(io, T)
    reset(io)
    if isLittleEndian
        return htol(ret)
    else 
        return hton(ret)
    end
end

function readpositionarray(io::IO, offset, nb=typemax(Int))
    mark(io)
    seekstart(io)
    seek(io, offset)
    ret = read(io, nb)
    reset(io)
    return ret
end

function slice(io::IO, offsetStart, offsetEnd)
    return readpositionarray(io, offsetStart, offsetEnd - offsetStart)
end

function readpositionstring(io::IO, offset, len)
    mark(io)
    seekstart(io)
    seek(io, offset)
    ret = read(io, len)
    reset(io)
    return ret
end

function trim(inp::IO, offset) 
    return 
end

end