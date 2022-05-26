module NGrams

export NGram, NGramTally
export ngram, next, context, trim
export c, incrementtally, maketally, updatetally

#struct NGram{S,T,n}
#    context::Vector{S}
#    next::T
#    NGram(ctx::Vector{S},nxt::T) where {S,T} = begin
#        new{S,T,length(ctx)+1}(ctx,nxt)
#    end
#end

NGram{S,T} = Pair{SubArray{S, 1, Vector{S}, Tuple{UnitRange{Int64}}, true},T}

function ngram(ctx::SubArray{S, 1, Vector{S}, Tuple{UnitRange{Int64}}, true},nxt::T) where {S,T}
    return NGram{S,T}(ctx,nxt)
end

next(g::NGram) = g[2]
context(g::NGram) = g[1]

Base.length(g::NGram) = length(context(g))+1
@views trim(v::Vector,l::Int) = l < length(v) ? v[end-l+1:end] : v
@views trim(v::SubArray{S, 1, Vector{S}, Tuple{UnitRange{Int64}}, true},l::Int) where S = l < length(v) ? v[end-l+1:end] : v
trim(g::NGram,l::Int) = ngram(trim(context(g),l-1),next(g))

NGramTally{S,T} = Dict{Vector{S},Vector{T}}


using DataStructures

function c(g::NGram{S,T},tally::NGramTally{S,T}) where {S,T}
    counter(Base.get(tally,context(g),[]))[next(g)]
end

function incrementtally(tally::NGramTally{S,T},g::NGram{S,T}) where {S,T}
    nxt = next(g)
    ctx = context(g)
    haskey(tally,ctx) ? push!(tally[ctx],nxt) : tally[ctx] = [nxt]
    return tally
end

function maketally(gs::Vector{NGram{S,T}}) where {S,T}
    tally = NGramTally{S,T}()
    for g in gs
        incrementtally(tally,g)
    end
    return tally
end

function updatetally(tally::NGramTally{S,T},g::NGram{S,T}) where {S,T}
    for l in 1:length(g)
        incrementtally(tally,trim(g,l))
    end
    return tally
end



# end of module
end
