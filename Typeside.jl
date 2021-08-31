module Typeside

export Unit, none, Option, List, Typ, typ, associatedType

struct Unit end
unit = Unit()

Option{T} = Union{T,Unit}
none = unit

List{T} = Vector{T}

function Typ(::Val{n} where n)
    println("There no associated type found")
    return Any
end

function typ(n::Symbol)
    Typ(Val{n}())
end

macro associatedType(n,T)
    esc(:(Typeside.Typ(::Val{$n}) = $T))
end

end
