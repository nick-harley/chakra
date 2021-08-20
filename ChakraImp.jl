module ChakraImp

using Typeside
import ChakraSpec as ch

struct Id <: ch.Id 
    val::Int64
end

struct Cobj <: ch.Cobj
    particles::List{Id}
    attributes::Dict{Symbol,Any}
end

struct Struc <: ch.Struc
    constituents::Dict{Id,Cobj}
end

delimit(ps::List{Id})::Cobj = Cobj(ps,Dict{Symbol,Any}())
function setAtt(o::Cobj,a,v)::Cobj
    o.attributes[a]=v
    Cobj(o.particles,o.attributes)
end
getAtt(o,a)::Option{Any} = get(o.attributes,n,none)
particles(o::Cobj)::List{Id} = o.particles
empty()::Struc = Struc(Dict{Id,Cobj}())
lookup(x::Id,s::Struc)::Option{Cobj} = get(s.constituents,x,none)
insert(x::Id,o::Cobj,s::Struc)::Struc = s.constituents[x] = o
domain(s::Struc)::List{id} = keys(s.constituents)

end
