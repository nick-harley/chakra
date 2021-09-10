module Viewpoints

export Viewpoint, AtomicViewpoint, LinkedViewpoint, DerivedViewpoint, DelayedViewpoint, ThreadedViewpoint, vp_type, vp_apply, seq_delay, vp_map

using Typeside, Chakra

const Seq = Vector{T} where T<:Chakra.Obj

head(s::Seq)::Option{Chakra.Obj} = isempty(s) ? nothing : s[1]
tail(s::Seq)::Seq = isempty(s) ? [] : s[2:length(s)]

abstract type Viewpoint{T} end

struct AtomicViewpoint{T} <: Viewpoint{T}
    typ::Type{T}
    att::Symbol
    AtomicViewpoint(t,a) = typ(a) != t ? error("ERR") : new{t}(t,a)
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

seq_delay(s::Seq,n::Int64)::Option{Seq} = isempty(s) ? nothing : (n <= 0 ? s : seq_delay(tail(s),n-1))

function vp_type(v::Viewpoint)::DataType end

vp_type(v::AtomicViewpoint)::DataType = typ(v.att)
vp_type(v::LinkedViewpoint)::DataType = Tuple{vp_type(v.fst),vp_type(v.snd)}
vp_type(v::DerivedViewpoint)::DataType = Base.return_types(v.fn)[1]
vp_type(v::DelayedViewpoint)::DataType = vp_type(v.vp)

function vp_apply(v::T where T<:Viewpoint,s::Seq) end

vp_apply(v::AtomicViewpoint,s::Seq) = op_fish(head, Chakra.get(v.att))(s)
vp_apply(v::LinkedViewpoint,s::Seq) = op_bind(vp_apply(v.fst,s), l -> op_bind(vp_apply(v.snd,s), r ->(l,r)))
vp_apply(v::DerivedViewpoint,s::Seq) = op_bind(vp_apply(v.vp,s), as -> typeof(as)<:Tuple ? v.fn(as...) : op_map(v.fn)(as))
vp_apply(v::DelayedViewpoint,s::Seq) = op_bind(seq_delay(s,v.lag),s2 -> vp_apply(v.vp,s2))


vp_map(v::Viewpoint,s::Seq)::Vector = isempty(s) ? [] : (vp_apply(v,s) == nothing ? vp_map(v,tail(s)) : [vp_apply(v,s),(vp_map(v,tail(s)))...])


end
