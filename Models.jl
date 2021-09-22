module Models

using Chakra, Viewpoints
export NGram, NGramModel, HGramModel, Predictor, Distribution, ml, ppm, ngram, information_content, entropy, Backoff, Interpolated, A, B, C, D, AX 


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
    order = n-1

    for i in 1:length(s)-order
        append!(ngrams,[ngram(s[i:i+order])])
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

# Number of occurences of g in m plus k
count(g::NGram,m::Model,k::Number=0) = ( c = Base.get(m.db,tovec(g),0) ; c == 0 ? 0 : c+k )

# Number of unique symbols in sequence s
tcount(s::Vector{T}) where T = length(Set(s))

# Number of occurrences of e in s
tcount(s::Vector{T},e::T) where T = Base.count(i->i==e,s)

# Sum over a the occurrences of (a,g.context) in m plus k
sumcount(g::NGram{T,n},m::Model{T},a::Set{T},k::Number=0) where {T,n} = sum(map(e->count(ngram([e,g.context...]),m,k),collect(a)))

# The symbols in s which occur exactly n times
occ(s::Vector{T},n::Int) where T = tcount(s[findall(x->x==n,map(x->tcount(s,x),s))])

# MAXIMUM LIKELIHOOD

function ml(g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n}
    ctx_count = sumcount(g,m,a)
    ctx_count == 0 ? 0.0 : count(g,m) / ctx_count
end

ml(nxt::T,ctx::Vector{T},m::Model{T},a::Set{T}) where T = ml(ngram([nxt,ctx...]),m,a)
ml(nxt::T,m::Model{T},a::Set{T}) where T = ml(ngram([nxt]),m,a)


# SMOOTHING

abstract type Escape end

struct A <: Escape end
struct B <: Escape end
struct C <: Escape end
struct D <: Escape end
struct AX <: Escape end

abstract type Smoothing end

struct Interpolated <: Smoothing end
struct Backoff <: Smoothing end


# ALPHA AND LAMBDA

## Backoff Smoothing

lambda(::Backoff,::A,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = 1 / sumcount(g,m,a,1)
alpha(::Backoff,::A,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = count(g,m,0) / sumcount(g,m,a,1)

lambda(::Backoff,::B,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = tcount(g.context)/sumcount(g,m,a)
alpha(::Backoff,::B,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = count(g,m,-1)/sumcount(g,m,a)

lambda(::Backoff,::C,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = (t=tcount(g.context); t/sumcount(g,m,a,t))
alpha(::Backoff,::C,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = count(g,m) / sumcount(g,m,a,tcount(g.context))

lambda(::Backoff,::D,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = 0.5*tcount(g.context) / sumcount(g,m,a)
alpha(::Backoff,::D,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = count(g,m,-0.5) / sumcount(g,m,a)
                                                   
lambda(::Backoff,::AX,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = (t=occ(g.context,1)+1; t/(sumcount(g,m,a,t+1)))
alpha(::Backoff,::AX,g::NGram{T,n},m::Model{T},a::Set{T}) where {T,n} = count(g,m)/(sumcount(g,m,a,occ(g.context,1)+1))

## Interpolated Smoothing

lambda(smth::Interpolated,esc::A,g,m,a) = sumcount(g,m,a,0.0) / (sumcount(g,m,a,0.0)+1)
alpha(smth::Interpolated,esc::A,g,m,a) = lambda(smth,esc,g,m,a)*(count(g,m,0.0)/sumcount(g,m,a,0.0))

lambda(smth::Interpolated,esc::B,g,m,a) = sumcount(g,m,a,-1.0) / (sumcount(g,m,a,-1.0)+tcount(g.context))
alpha(smth::Interpolated,esc::B,g,m,a) = lambda(smth,esc,g,m,a)*(count(g,m,-1.0)/sumcount(g,m,a,-1.0))
                                                                 
lambda(smth::Interpolated,esc::C,g,m,a) = sumcount(g,m,a,0.0) / (sumcount(g,m,a,0.0)+tcount(g.context))
alpha(smth::Interpolated,esc::C,g,m,a) = lambda(smth,esc,g,m,a)*(count(g,m,0.0)/sumcount(g,m,a,0.0))

lambda(smth::Interpolated,esc::D,g,m,a) = sumcount(g,m,a,-0.5) / (sumcount(g,m,a,-0.5)+(tcount(g.context)/2))
alpha(smth::Interpolated,esc::D,g,m,a) = lambda(smth,esc,g,m,a)*(count(g,m,-0.5)/sumcount(g,m,a,-0.5))
                                                                 
lambda(smth::Interpolated,esc::AX,g,m,a) = sumcount(g,m,a) / (sumcount(g,m,a)+occ(g.context,1))
alpha(smth::Interpolated,esc::AX,g,m,a) = lambda(smth,esc,g,m,a)*(count(g,m,0.0)/sumcount(g,m,a,0.0))

# BACKOFF PPM
                                                           
function ppm(smth::Backoff,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}

    if count(g,m) == 0
        if n == 1
            return 1/length(a)
        else
            g2 = NGram{T,n-1}(g.next,g.context[1:length(g.context)-1])
            return lambda(smth,esc,g,m,a)*ppm(smth,esc,g2,m,a,esc)
        end
    end

    return alpha(smth,esc,g,m,a)
    
end

ppm(smth::Backoff,esc::Escape,nxt::T,ctx::Vector{T},m::HGramModel{T,h},a::Set{T}) where {T,h} = ppm(smth,esc,ngram([nxt,ctx...]),m,a)
ppm(smth::Backoff,esc::Escape,nxt::T,m::HGramModel{T,h},a::Set) where {T,h} = ppm(smth,esc,ngram([nxt]),m,a)

# INTERPOLATED PPM

function ppm(smth::Interpolated,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}
    if n==1
        return 1 / (length(a) + 1 + tcount(T[]))
    end

    lam = lambda(smth,esc,g,m,a)
    gam = 1 - lam
    g2 = NGram{T,n-1}(g.next,g.context[1:length(g.context)-1])
    
    return alpha(smth,esc,g,m,a) + (gam * ppm(smth,esc,g2,m,a))
    
end

ppm(smth::Interpolated,esc::Escape,nxt::T,ctx::Vector{T},m::Model{T},a::Set{T}) where T = ppm(smth,esc,ngram([nxt,ctx...]),m,a)

ppm(smth::Interpolated,esc::Escape,nxt::T,m::Model{T},a::Set{T}) where T = ppm(smth,esc,ngram([nxt]),m,a)

struct Predictor{T}
    smoothing::Smoothing
    escape::Escape
    model::Model{T}
    alphabet::Set{T}
end

(p::Predictor{T})(g::NGram{T,n}) where {T,n} = ppm(p.smoothing,p.escape,g,p.model,p.alphabet)

struct Distribution{T}
    predictor::Predictor{T}
    context::Vector{T}
end

(d::Distribution{T})(x::T) where T = d.predictor(ngram(T[x,d.context...]))

information_content(nxt::T,d::Distribution{T}) where T = -log(2,d(nxt))
information_content(g::NGram{T,n},p::Predictor{T}) where {T,n} = information_content(g.next,Distribution(p,g.context))

entropy(d::Distribution{T}) where T = sum(map(e->d(e)*information_content(e,d),collect(d.predictor.alphabet)))
entropy(s::Vector{T},p::Predictor{T}) where T = entropy(Distribution(p,s))


end




