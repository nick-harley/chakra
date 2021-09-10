module Chakra

export delim, set, get, parts, empty, ins, fnd, dom

using Typeside

abstract type Id end
abstract type Obj end
abstract type Struc end

function delim(ps::Vector{Id})::Obj
    error("No implementation of delim")
end

function set(o::Obj,a::Symbol,v)::Obj
    error("No implementation of setAtt")
end

function get(o::Obj,a::Symbol)::Option{Any}
    error("No implementation of get")
end

get(a::Symbol) = o -> get(o,a)

function parts(o::Obj)::Vector{Id}
    error("No implementation of getParts")
end

function empty()::Struc
    error("No implementation of emp")
end

function ins(x::Id,o::Obj,s::Struc)::Struc
    error("No implementation of ins")
end

function fnd(x::Id,s::Struc)::Option{Obj}
    error("No implementation of lup")
end

function dom(s::Struc)::Vector{Id}
    error("No implementation of dom")
end

end
