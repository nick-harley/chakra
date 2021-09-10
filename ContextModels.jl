module ContextModels

using Typeside, Chakra, Viewpoints

function construct_model(s::Vector{T} where T<:Chakra.Obj,v::T where T<:Viewpoint,order::Int)

    tau = vp_type(v)
    db = Dict{Vector{tau},Int}()

    vs = reverse(vp_map(v,s))
    n = length(vs)

    db[[]] = n
    
    for h in 1:order+1
        for i in 1:n-h+1
            seq = reverse(vs[i:i+h-1])
            haskey(db,seq) ? db[seq]+=1 : db[seq] = 1
        end
    end
    return db

end

function probability_of(next,context,model)

    ctx_count = model[context]
    seq_count = model[[next,context...]]

    return seq_count/ctx_count

end



end
