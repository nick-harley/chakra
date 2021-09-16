module Models

using Typeside, Chakra, Viewpoints

struct Model{T}
    order::Int
    db::Dict{Vector{T},Int}
    elems::Set{T}
end

get_count(c::Model,s::Vector) = haskey(c.db,s) ? c.db[s] : 0

function construct_model(s::Vector{T} where T<:Chakra.Obj,v::T where T<:Viewpoint,order::Int)

    tau = vp_type(v)
    db = Dict{Vector{tau},Int}()

    vs = vp_map(v,s)
    n = length(vs)

    db[[]] = n
    elems = Set(vs)
    
    for h in 1:order+1
        for i in 1:n-h+1
            seq = vs[i:i+h-1]
            haskey(db,seq) ? db[seq]+=1 : db[seq] = 1
        end
    end
    return Model{tau}(order,db,elems)

end

function prob(nxt::T,ctx::Vector{T},m::Model{S}) where {S,T<:S} 

    ctx_count = get_count(m,ctx)

    if ctx_count == 0
        return 0.0
    end

    seq_count = get_count(m,[nxt,ctx...])

    return seq_count / ctx_count
    
end

prob(nxt::T,m::Model{S}) where {T,S>:T} = prob(nxt,T[],m)

function alpha(nxt::T,ctx::Vector{T},m::Model{S}) where {S,T<:S}
    seq_count = get_count(m,[nxt,ctx...])
    ctx_count = get_count(m,ctx) + 1
    return seq_count / ctx_count
end

function lambda(ctx::Vector{T},m::Model{S}) where {S,T<:S}
    return 1 / (get_count(m,ctx) + 1)
end

function ppm(nxt::T,ctx::Vector{T},m::Model{S}) where {S,T<:S}

    if m.order < length(ctx)
        ctx = ctx[1:m.order]
    end
    
    if isempty(ctx)
        return prob(nxt,m) + 1/(length(m.elems))
    end
    
    alpha(nxt,ctx,m) + lambda(ctx,m) * ppm(hd(ctx),tl(ctx),m)
    
    
end

end




