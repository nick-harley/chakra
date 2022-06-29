module ChakraReference

using Chakra


Id = Symbol

struct Obj
    particles::List{Id}
    attribtues::Dict{Symbol,Any}}
end

struct Str
    objects::Dict{Id,Obj}
end

function Chakra.delimit(ps::List{Id})::Obj 
    Obj(ps,Dict{Symbol,Any}())
end

function Chakra.particles(o::Obj)::List{Id}
    o.particles
end

function Chakra.getatt(::Att{a,T},o::Obj)::Option{T} where {a,T}
    Base.get(o.attributes,a,none)
end

function Chakra.setatt(::Att{a,T},v::T,o::Obj)::Obj where {a,T}
    Obj(o.partiles,Dict(o.attributes...,a=>v))
end

function Chakra.empty(::Type{Obj})::Str
    Str(Dict{Id,Obj}())
end

function Chakra.insert(x::Id,o::Obj,s::Str)::Str 
    Str(Dict(s.objects...,x=>o))
end

function Chakra.find(x::Id,s::Str)::Option{Obj} 
    Base.get(s.objects,x,none)
end

function Chakra.domain(s::Str)::List{Id} 
    collect(keys(s.objects))
end



function Chakra.setatt!(::Att{a,T},v::T,o::Obj)::Obj where {a,T}
    o.attributes[a] = v
    o
end

function Chakra.insert!(x::Id,o::Obj,s::Str)::Str 
    s.objects[x] = o
end


# end of module
end
