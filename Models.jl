module Models

using Chakra, Viewpoints
export NGram, NGramModel, HGramModel, Predictor, Distribution, ml, ppm, ngram, information_content, entropy, entropy_max, redundancy, Backoff, Interpolated, A, B, C, D, AX 

# Type of NGrams
struct NGram{T,n}
    next::T
    context::Vector{T}
    NGram{T,n}(nxt::T,ctx::Vector{T}) where {T,n} = length(ctx) != n-1 ? error("Context wrong length.") : new{T,n}(nxt,ctx)
    NGram{T,n}(s::Vector{T}) where {T,n} = NGram{T,n}(hd(s),tl(s))
end

# Construct an NGram from a sequence
ngram(s::Vector{T}) where T = isempty(s) ? error("Can't have a 0 gram.") : NGram{T,length(s)}(s)
# Construct a sequence fron an NGram
tovec(ng::NGram{T,n}) where {T,n} =  [ng.next,ng.context...]

# Generate NGrams from a sequence
function generate_ngrams(s::Vector{T},n::Int)::Vector{NGram{T,n}} where T

    ngrams = NGram{T,n}[]
    order = n-1

    for i in 1:length(s)-order
        append!(ngrams,[ngram(s[i:i+order])])
    end

    return ngrams

end

# Abstract type of models
abstract type Model{T,n} end

# Type of n-gram models of type T
struct NGramModel{T,n} <: Model{T,n}
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

# Type of HGram models
struct HGramModel{T,h} <: Model{T,h}
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
count(g::NGram{T,n},m::NGramModel{T,n},k::Number=0) where {T,n} = (c=Base.get(m.db,tovec(g),0); c>0 ? c+k : 0)
count(g::NGram{T,n},m::HGramModel{T,h},k::Number=0) where {T,n,h} = n<=h ? (c=Base.get(m.db,tovec(g),0); c>0 ? c+k : 0) : error("$h gram model does not include $n grams.")

# Number of unique symbols in sequence s
tcount(s::Vector{T}) where T = length(Set(s))

# Number of occurrences of e in s
tcount(s::Vector{T},e::T) where T = Base.count(i->i==e,s)

# Sum over e in a of count(e|g.context)+k
sumcount(g::NGram{T},m::Model{T},a::Set{T},k::Number=0) where T = sum(map(e->count(ngram([e,g.context...]),m,k),collect(a)))

# Symbols in s which occur exactly n times in s
occ(s::Vector{T},n::Int) where T = tcount(s[findall(x->x==n,map(x->tcount(s,x),s))])

# Maximum Likelihood
function ml(g::NGram{T},m::Model{T},a::Set{T},k::Number=0) where T
    ctx_count = sumcount(g,m,a,k)
    ctx_count == 0 ? 0.0 : count(g,m,k) / ctx_count
end

ml(nxt::T,ctx::Vector{T},m::Model{T},a::Set{T}) where T = ml(ngram([nxt,ctx...]),m,a)
ml(nxt::T,m::Model{T},a::Set{T}) where T = ml(ngram([nxt]),m,a)


# Abstract type of smoothing escape methods
abstract type Escape end

# Concrete types for smoothing escape methods
struct A <: Escape end
struct B <: Escape end
struct C <: Escape end
struct D <: Escape end
struct AX <: Escape end

# Abstract type of smoothing method
abstract type Smoothing end

# Concrete types of smoothing methods
struct Interpolated <: Smoothing end
struct Backoff <: Smoothing end


# ALPHA AND LAMBDA
function alpha(smth::Smoothing,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} end 
function lambda(smth::Smoothing,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} end

## Backoff Smoothing

lambda(::Backoff,::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = 1 / (sumcount(g,m,a)+length(a))
alpha(::Backoff,::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = count(g,m,0) / (sumcount(g,m,a)+length(a))

lambda(::Backoff,::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = tcount(g.context)/sumcount(g,m,a)
alpha(::Backoff,::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (count(g,m)-1)/sumcount(g,m,a)

lambda(::Backoff,::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=tcount(g.context);t/(sumcount(g,m,a)+length(a)*t))
alpha(::Backoff,::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = count(g,m)/(sumcount(g,m,a)+(length(a)*tcount(g.context)))

lambda(::Backoff,::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (0.5*tcount(g.context))/sumcount(g,m,a)
alpha(::Backoff,::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (count(g,m)-0.5)/sumcount(g,m,a)

lambda(::Backoff,::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=occ(g.context,1)+1; t/(sumcount(g,m,a)+(length(a)*t)))
alpha(::Backoff,::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=occ(g.context,1)+1;count(g,m)/(sumcount(g,m,a)+(length(a)*t)))

## Interpolated Smoothing

lambda(smth::Interpolated,esc::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a) / (sumcount(g,m,a)+1)
alpha(smth::Interpolated,esc::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(smth,esc,g,m,a)*ml(g,m,a)

lambda(smth::Interpolated,esc::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,-1.0) / (sumcount(g,m,a,-1.0)+tcount(g.context))
alpha(smth::Interpolated,esc::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(smth,esc,g,m,a)*ml(g,m,a,-1)

lambda(smth::Interpolated,esc::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,0.0) / (sumcount(g,m,a,0.0)+tcount(g.context))
alpha(smth::Interpolated,esc::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(smth,esc,g,m,a)*ml(g,m,a,0.0)

lambda(smth::Interpolated,esc::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,-0.5) / (sumcount(g,m,a,-0.5)+(tcount(g.context)/2))
alpha(smth::Interpolated,esc::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(smth,esc,g,m,a)*ml(g,m,a,-0.5)

lambda(smth::Interpolated,esc::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a) / (sumcount(g,m,a)+occ(g.context,1))
alpha(smth::Interpolated,esc::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(smth,esc,g,m,a)*ml(g,m,a)

# BACKOFF PPM

function ppm(smth::Backoff,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}
    order = n-1
    if n>h
        error("Cannot predict $n gram from $h gram model.")
    end
    
    if count(g,m) == 0
        if order == 0
            return 1/length(a)
        else
            g2 = NGram{T,order}(g.next,g.context[1:order-1])
            return lambda(smth,esc,g,m,a)*ppm(smth,esc,g2,m,a)
        end
    end

    return alpha(smth,esc,g,m,a)
    
end

# INTERPOLATED PPM

function ppm(smth::Interpolated,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}
    order = n-1
    if n>h
        error("Cannot predict $n gram from $h gram model.")
    end

    if order==0
        return 1 / (length(a) + 1 + tcount(T[]))
    end

    lam = lambda(smth,esc,g,m,a)
    gam = 1 - lam
    g2 = NGram{T,order}(g.next,g.context[1:order-1])
    return alpha(smth,esc,g,m,a) + (gam * ppm(smth,esc,g2,m,a))    
end

ppm(smth::Smoothing,esc::Escape,nxt::T,ctx::Vector{T},m::HGramModel{T,h},a::Set{T}) where {T,h} = ppm(smth,esc,ngram([nxt,ctx...]),m,a)
ppm(smth::Smoothing,esc::Escape,nxt::T,m::HGramModel{T,h},a::Set) where {T,h} = ppm(smth,esc,ngram([nxt]),m,a)

struct Predictor{T}
    smoothing::Smoothing
    escape::Escape
    model::Model{T,n} where n
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

entropy_max(d::Distribution{T}) where T = log(2,length(d.predictor.alphabet))

redundancy(d::Distribution{T}) where T = 1 - (entropy(d)/entropy_max(d))

end




