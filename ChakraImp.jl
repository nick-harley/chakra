module ChakraImp

using Typeside
using Chakra

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

Chakra.delimit(ps::List{Id})::Cobj = Cobj(ps,Dict{Symbol,Any}())
Chakra.setAtt(o::Cobj,a,v)::Cobj = (o.attributes[a]=v; Cobj(o.particles,o.attributes))
Chakra.getAtt(o,a)::Option{Any} = get(o.attributes,n,none)
Chakra.particles(o::Cobj)::List{Id} = o.particles
Chakra.empty()::Struc = Struc(Dict{Id,Cobj}())
Chakra.lookup(x::Id,s::Struc)::Option{Cobj} = get(s.constituents,x,none)
Chakra.insert(x::Id,o::Cobj,s::Struc)::Struc = (s.constituents[x] = o ; s)
Chakra.domain(s::Struc)::List{id} = keys(s.constituents)

end
