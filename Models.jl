module Models

using Chakra, Viewpoints
export NGram, NGramModel, HGramModel, ml, ppm, ngram


struct NGram{T,n}
    next::T
    context::Vector{T}
    NGram{T,n}(nxt::T,ctx::Vector{T}) where {T,n} = length(ctx) != n-1 ? error("Context wrong length.") : new{T,n}(nxt,ctx)
    NGram{T,n}(s::Vector{T}) where {T,n} = NGram{T,n}(hd(s),tl(s))
end

ngram(s::Vector{T}) where T = isempty(s) ? error("Can't have a 0 gram.") : NGram{T,length(s)}(s)
tovec(ng::NGram{T,n}) where {T,n} =  [ng.next,ng.context...]

function generate_ngrams(s::Vector{T},n::Int) where T

    ngrams = NGram{T,n}[]

    for i in 1:length(s)-n+1
        append!(ngrams,[NGram{T,n}(s[i:i+n-1])])
    end

    return ngrams

end

abstract type Model{T} end

struct NGramModel{T,n} <: Model{T}
    db::Dict{Vector{T},Int}
    elems::Set{T}
    function NGramModel{T,n}(ngrams::Vector{NGram{T,n}}) where {T,n}
        db = Dict{Vector{T},Int}()
        seqs = map(tovec,ngrams)
        map(s -> haskey(db,s) ? db[s] += 1 : db[s] = 1, seqs)
        elems = Set(vcat(seqs...))
        new{T,n}(db,elems)
    end
    NGramModel{T,n}(s::Vector{T}) where {T,n} = NGramModel{T,n}(generate_ngrams(s,n))
end

struct HGramModel{T,h} <: Model{T}
    db::Dict{Vector{T},Int}
    elems::Set{T}
    function HGramModel{T,h}(s::Vector{T}) where {T,h}
        db = Dict{Vector{T},Int}()
        for n in 1:h
            ngmod = NGramModel{T,n}(s)
            db = merge(db,ngmod.db)
        end
        return new{T,h}(db,Set(s))
    end
end

count(ng::NGram{T,n},m::Model{T}) where {T,n} = ( s = tovec(ng) ; haskey(m.db,s) ? m.db[s] : 0 )
ctxcount(ng::NGram{T,n},m::Model{T}) where {T,n}= sum(map(e -> count(NGram{T,n}(e,ng.context),m), collect(m.elems)))

# MAXIMUM LIKELIHOOD

function ml(ng::NGram{T,n},m::Model{T}) where {T,n}
    seq_count = count(ng,m)
    ctx_count = ctxcount(ng,m)
    ctx_count == 0 ? 0.0 : seq_count / ctx_count
end

ml(s::Vector{T},m::Model{T}) where T = ml(ngram(s),m)
ml(nxt::T,m::Model{T}) where T = ml(ngram([nxt]),m)
ml(nxt::T,ctx::Vector{T},m::Model{T}) where T = ml(ngram([nxt,ctx...]),m)

# LAMBDA

lambda(ng::NGram{T,n},m::Model{S}) where {S,T<:S,n} = 1 / (ctxcount(ng,m) + 1)

# 

function ppm(ng::NGram{T,n},m::HGramModel{S,h}) where {S,T<:S,n,h}

    if h < n
        error("Cannot predict $n gram from $h gram model.")
    end
    
    if n == 1
        return ml(ng,m) + 1/(length(m.elems))
    end

    ctx2 = ng.context[1:length(ng.context)-1]
    return ml(ng,m) + lambda(ng,m) * ppm(NGram{T,n-1}(ng.next,ctx2),m)
    
    
end

ppm(nxt::T,m::HGramModel{T,h}) where {T,h} = ppm(ngram([nxt]),m)
ppm(nxt::T,ctx::Vector{T},m::HGramModel{T,h}) where {T,h} = ppm(ngram([nxt,ctx...]),m)
ppm(s::Vector{T},m::HGramModel{T,h}) where {T,h} = ppm(ngram(s),m)

end




