module Viewpoints

export Viewpoint, AtomicViewpoint, LinkedViewpoint, DerivedViewpoint, DelayedViewpoint, ThreadedViewpoint, vp_type, seq_delay, vp_map

using Chakra

const Seq = Vector{T} where T<:Chakra.Obj

abstract type Viewpoint{T} end

struct AtomicViewpoint{T} <: Viewpoint{T}
    typ::Type{S} where {S<:T}
    att::Symbol
    AtomicViewpoint(t,a::Symbol) = t <: typ(a) ? new{typ(a)}(t,a) : error("Incorrect viewpoint type.")
end

struct LinkedViewpoint{T1,T2} <: Viewpoint{Tuple{T1,T2}}
    fst::Viewpoint{T1}
    snd::Viewpoint{T2}
end

struct DerivedViewpoint{T2} <: Viewpoint{T2}
    typ::Type{T2}
    vp::Viewpoint{T1} where T1
    fn::Function
    DerivedViewpoint(t,v,f) = Base.return_types(f)[1] <: t ? new{t}(t,v,f) : error("ERR")
end

struct DelayedViewpoint{T} <: Viewpoint{T}
    vp::Viewpoint{T}
    lag::Int64
end

struct ThreadedViewpoint{T} <: Viewpoint{T}
    test::Viewpoint{Bool}
    vp::Viewpoint{T}
end

seq_delay(s::Seq,n::Int64)::Option{Seq} = isempty(s) ? nothing : (n <= 0 ? s : seq_delay(tl(s),n-1))

function vp_type(v::Viewpoint)::DataType end

vp_type(v::AtomicViewpoint)::DataType = typ(v.att)
vp_type(v::LinkedViewpoint)::DataType = Tuple{vp_type(v.fst),vp_type(v.snd)}
vp_type(v::DerivedViewpoint)::DataType = Base.return_types(v.fn)[1]
vp_type(v::DelayedViewpoint)::DataType = vp_type(v.vp)


(v::AtomicViewpoint)(s::Seq) = op_fish(hd, Chakra.get(v.att))(s)
(v::LinkedViewpoint)(s::Seq) = op_bind(v.fst(s), l -> op_bind(v.snd(s), r ->(l,r)))
(v::DerivedViewpoint)(s::Seq) = op_bind(v.vp(s), as -> typeof(as)<:Tuple ? v.fn(as...) : op_map(v.fn)(as))
(v::DelayedViewpoint)(s::Seq) = op_bind(seq_delay(s,v.lag),s2 -> v.vp(s2))


vp_map(v::Viewpoint,s::Seq)::Vector = isempty(s) ? [] : v(s) == nothing ? vp_map(v,tl(s)) : [v(s),vp_map(v,tl(s))...]


end
