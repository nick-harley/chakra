module ChakraImp

using Chakra
import Chakra: delim, set, get, parts, empty, fnd, ins, dom

struct Id <: Chakra.Id 
    val::Int64
end

struct Obj <: Chakra.Obj
    particles::Vector{Id}
    attributes::Base.ImmutableDict{Symbol,Any}
end

struct Struc <: Chakra.Struc
    constituents::Dict{Id,Obj}
end

delim(ps::Vector{Id})::Obj = Obj(ps,Base.ImmutableDict{Symbol,Any}())

delim()::Obj = delim(Id[])

set(o::Obj,a::Symbol,v)::Obj = Obj(o.particles,Base.ImmutableDict(o.attributes,a=>v))

get(o::Obj,a::Symbol)::Option{Any} = Base.get(o.attributes,a,nothing)

parts(o::Obj)::List{Id} = o.particles

empty() = Struc(Dict{Id,Obj}())

fnd(x::Id,s::Struc)::Option{Obj} = get(s.constituents,x,nothing)

ins(x::Id,o::Obj,s::Struc)::Struc = (s.constituents[x] = o ; s)

dom(s::Struc)::List{id} = keys(s.constituents)

end
