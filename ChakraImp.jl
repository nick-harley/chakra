module ChakraImp

using Typeside
using Chakra
import Chakra: delimit, setAtt, getAtt, particles, empty, lookup, insert, domain

struct Id <: Chakra.Id 
    val::Int64
end

struct Cobj <: Chakra.Cobj
    particles::List{Id}
    attributes::Dict{Symbol,Any}
end

struct Struc <: Chakra.Struc
    constituents::Dict{Id,Cobj}
end

delimit(ps::List{Id})::Cobj = Cobj(ps,Dict{Symbol,Any}())
delimit()::Cobj = delimit(Id[])
setAtt(o::Cobj,a::Symbol,v)::Cobj = (o.attributes[a]=v; Cobj(o.particles,o.attributes))
getAtt(o::Cobj,a::Symbol)::Option{Any} = get(o.attributes,a,none)
particles(o::Cobj)::List{Id} = o.particles
empty()::Struc = Struc(Dict{Id,Cobj}())
lookup(x::Id,s::Struc)::Option{Cobj} = get(s.constituents,x,none)
insert(x::Id,o::Cobj,s::Struc)::Struc = (s.constituents[x] = o ; s)
domain(s::Struc)::List{id} = keys(s.constituents)

end
