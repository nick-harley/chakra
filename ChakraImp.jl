module ChakraImp

using ListType, OptionType, Chakra


Id = Symbol
Obj = Tuple{List{Id},Dict{Symbol,Any}}
Str = Dict{Id,Obj}

function Chakra.delimit(ps::List{Id})::Obj 
    (ps,Dict{Symbol,Any}())
end

function Chakra.particles(o::Obj)::List{Id}
    o[1]
end

function Chakra.getatt(::Att{a,T},o::Obj)::Option{T} where {a,T}
    as = o[2]
    haskey(as,a) ? as[a] : none
end

function Chakra.setatt(::Att{a,T},v::T,o::Obj)::Obj where {a,T}
    (o[1],Dict(o[2]...,a=>v))
end

function Chakra.empty(::Type{Obj})::Str
    Dict{Id,Obj}()
end

function Chakra.insert(x::Id,o::Obj,s::Str)::Str 
    Dict(s...,x=>o)
end

function Chakra.find(x::Id,s::Str)::Option{Obj} 
    haskey(s,x) ? s[x] : none
end

function Chakra.domain(s::Str)::List{Id} 
    collect(keys(s))
end



# end of module
end
