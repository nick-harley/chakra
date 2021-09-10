module ContextModels

using Typeside, Chakra, Viewpoints

function construct_model(s::Vector{T} where T<:Chakra.Obj,v::T where T<:Viewpoint,order::Int)

    tau = vp_type(v)
    db = Dict{Vector{tau},Int}()

    vs = reverse(vp_map(v,s))
    n = length(vs)
    
    for h in 1:order+1
        println(h)
        for i in 1:n-h+1
            seq = vs[i:i+h-1]
            haskey(db,seq) ? db[seq]+=1 : db[seq] = 1
        end
    end
    return db
    
end



end
