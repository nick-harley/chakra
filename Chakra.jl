module Chakra

export hd, tl, Option, op_map, op_fish, op_bind, typ, associatedType, delim, set, get, parts, empty, ins, fnd, dom

hd(x::Vector)::Option = isempty(x) ? nothing : x[1]
tl(x::Vector)::Vector = isempty(x) ? [] : x[2:length(x)]

Option{T} = Union{T,Nothing}

function op_map(f::Function)::Function
    function (x...)
        length(x) == 1 && x[1] == nothing ? nothing : f(x...)
    end
end

op_bind(x,f) = x == nothing ? nothing : f(x)
op_fish(f,g) = x -> op_bind(f(x),y-> g(y))



typ(::Val{n}) where n = error("There is no associated type found")
typ(n::Symbol) = typ(Val{n}())

macro associatedType(n,T)
    esc(:(Chakra.typ(::Val{$n}) = $T))
end




abstract type Id end
abstract type Obj end
abstract type Struc end

function delim(ps::Vector{Id})::Obj
    error("No implementation of delim")
end

function set(o::Obj,a::Symbol,v::Any)::Obj
    error("No implementation of setAtt")
end

function get(o::Obj,a::Symbol)
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
