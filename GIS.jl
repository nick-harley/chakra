module GIS

abstract type Point end
abstract type Interval end

function diff(x::Point,y::Point)::Interval
    error("No implementation of diff")
end

function shift(i::Interval,p::Point)::Point
    error("No implementation of shift")
end

end
