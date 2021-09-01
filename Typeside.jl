module Typeside

export Unit, none, Option, List, Typ, typ, associatedType, op_map, op_fish, op_bind

struct Unit end
unit = Unit()

Option{T} = Union{T,Unit}
none = unit

function op_map(f::Function)::Function
    function (x...)
        length(x) == 1 && x[1] == none ? none : f(x...)
    end
end

op_bind(x,f) = x == none ? none : f(x)
op_fish(f,g) = x -> op_bind(f(x),y-> g(y))
    
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
