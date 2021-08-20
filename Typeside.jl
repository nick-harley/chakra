module Typeside

export none, some, Option, List, associatedType, typ

struct Unit end
unit = Unit()
none = unit
some(v) = v
Option{T} = Union{T,Unit}

List{T} = Vector{T}

struct Val{n} end

function Typ(::Val{n} where n)::DataType 
    println("There no associated type found")
    return Any
end

macro associatedType(n,T)
    return quote
        function Typ(::Val{$n})
            $T
        end
    end
end

function typ(n::Symbol)::DataType
    Typ(Val{n}())
end

end
