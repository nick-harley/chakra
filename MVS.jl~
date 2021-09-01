module MVS

export AtomicViewpoint, LinkedViewpoint, DerivedViewpoint, apply, delay, retType

using Typeside, Chakra

const Seq = Vector{T} where T<:Chakra.Cobj

head(s::Seq)::Option{Chakra.Cobj} = isempty(s) ? none : s[1]
tail(s::Seq)::Option{Seq} = isempty(s) ? none : s[2:length(s)]



abstract type Viewpoint end

struct AtomicViewpoint <: Viewpoint
    att::Symbol
end

struct LinkedViewpoint <: Viewpoint
    elements::Array{Viewpoint}
end

struct DerivedViewpoint <: Viewpoint
    vp::Viewpoint
    fn::Function
end

struct DelayedViewpoint <: Viewpoint
    vp::Viewpoint
    lag::Int64
end

delay(s::Seq,n::Int64)::Option{Seq} = n == 0 ? s : delay(tail(s),n-1)
delay(s::Unit,n::Int64)::Option{Seq} = none

function retType(v::Viewpoint)::DataType end

retType(v::AtomicViewpoint)::DataType = typ(v.att)
retType(v::LinkedViewpoint)::DataType = Tuple{map(retType,v.elements)...}
retType(v::DerivedViewpoint) = Base.return_types(v.fn)[1]

function apply(v::Viewpoint,s::Seq) end

apply(v::AtomicViewpoint,s::Seq) = getAtt(head(s),v.att)
apply(v::LinkedViewpoint,s::Seq) = tuple(map(e -> apply(e,s), v.elements)...)
apply(v::DerivedViewpoint,s::Seq) = (as = apply(v.vp,s); typeof(as)<:Tuple ? v.fn(as...) : v.fn(as))
apply(v::DelayedViewpoint,s::Seq) = apply(v.vp,delay(s,v.lag))

  
end
