module ContextModels

using Typeside, Chakra, Viewpoints

struct ContextModel{T}
    db::Dict{Vector{T},Int}
    elems::Set{T}
end

get_count(c::ContextModel,s::Vector) = haskey(c.db,s) ? c.db[s] : 0

function construct_model(s::Vector{T} where T<:Chakra.Obj,v::T where T<:Viewpoint,order::Int)

    tau = vp_type(v)
    db = Dict{Vector{tau},Int}()

    vs = reverse(vp_map(v,s))
    n = length(vs)

    db[[]] = n
    elems = Set(vs)
    
    for h in 1:order+1
        for i in 1:n-h+1
            seq = reverse(vs[i:i+h-1])
            haskey(db,seq) ? db[seq]+=1 : db[seq] = 1
        end
    end
    return ContextModel{tau}(db,elems)

end

function probability_of(next::T,context::Vector{T},model::ContextModel{S}) where {S,T<:S} 
    ctx_count = get_count(model,context)
    seq_count = get_count(model,[next,context...])

    return seq_count/ctx_count

end

probability_of(next::T,model::ContextModel{S}) where {T,S>:T} = probability_of(next,T[],model)

end




