module Typeside

export hd, tl, Option, op_map, op_fish, op_bind, Typ, typ, associatedType

Option{T} = Union{T,Nothing}

hd(x::Vector)::Option = isempty(x) ? nothing : x[1]
tl(x::Vector)::Vector = isempty(x) ? [] : x[2:length(x)]

function op_map(f::Function)::Function
    function (x...)
        length(x) == 1 && x[1] == nothing ? nothing : f(x...)
    end
end

op_bind(x,f) = x == nothing ? nothing : f(x)
op_fish(f,g) = x -> op_bind(f(x),y-> g(y))
    
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
