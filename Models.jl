module Models

using Chakra, Viewpoints
export NGram, NGramModel, HGramModel, Predictor, AtomicPredictor, CombinedPredictor, Distribution, ml, ppm, information_content, entropy, max_entropy, relative_entropy, redundancy, Backoff, Interpolated, A, B, C, D, AX 

# Type of NGrams
struct NGram{T,n}
    next::T
    context::Vector{T}
    NGram(nxt::T,ctx::Vector{T}) where T = new{T,length(ctx)+1}(nxt,ctx)
    NGram(nxt::T) where T = new{T,1}(nxt,T[])
    NGram(s::Vector{T}) where T = isempty(s) ? error("Cannot construct 0-gram.") : NGram(hd(s),tl(s))
end

order(g::NGram{T,n}) where {T,n} = n
tovec(ng::NGram{T,n}) where {T,n} =  [ng.next,ng.context...]
trim(g::NGram{T,n},l::Int) where {T,n} = n<=l ? g : NGram(tovec(g)[1:l])


# Generate NGrams from a sequence
generate_ngrams(s::Vector{T},n::Int) where T = map(i->NGram(s[i:i+n-1]),1:length(s)-n)
generate_hgrams(s::Vector{T},h::Int) where T = vcat(map(n->map(i->NGram(s[i:i+n-1]),1:length(s)-n),1:h)...)

# Abstract type of models
abstract type Model{T,n} end

# Type of n-gram models of type T
struct NGramModel{T,n} <: Model{T,n}
    db::Dict{Vector{T},Int}
    elems::Set{T}
    function NGramModel(gs::Vector{NGram{T,n}}) where {T,n}
        db = Dict{Vector{T},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,tovec.(gs))
        return new{T,n}(db,Set(vcat(tovec.(gs)...)))
    end
    function NGramModel(s::Vector{T},n::Int) where T
        db = Dict{Vector{T},Int}()
        ngrams = map(tovec,generate_ngrams(s,n))
        map(g -> haskey(db,g) ? db[g] += 1 : db[g] = 1, seqs)
        elems = Set(s)
        return new{T,n}(db,elems)
    end
    NGramModel(ss::Vector{Vector{T}},n::Int) where T = NGramModel(vcat(map(s->generate_ngrams(s,n),ss)...))
end

# Type of HGram models
struct HGramModel{T,h} <: Model{T,h}
    db::Dict{Vector{T},Int}
    elems::Set{T}
    function HGramModel(gs::Vector{NGram{T}}) where T
        h = max(order.(gs))
        db = Dict{Vector{T},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,tovec.(gs))
        return new{T,h}(db,Set(vcat(tovec.(gs)...)))
    end
    function HGramModel(s::Vector{T},h::Int) where T
        db = Dict{Vector{T},Int}()
        hgrams = map(tovec,generate_hgrams(s,h))
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1, hgrams)
        elems = Set(s)
        return new{T,h}(db,Set(s))
    end
    HGramModel(ss::Vector{Vector{T}},n::Int) where T = HGramModel(vcat(map(s->generate_hgrams(s,n),ss)...))
end

struct UHGramModel{T,h} <: Model{T,h}
    db::Dict{Vector{T},Int}
    elems::Set{T}
    function UHGramModel(gs::Vector{NGram{T}}) where T
        h = max(order.(gs))
        db = Dict{Vector{T},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,tovec.(gs))
        return new{T,h}(db,Set(vcat(tovec.(gs)...)))
    end 
    function UHGramModel(s::Vector{T}) where T
        db = Dict{Vector{T},Int}()
        hgrams = map(tovec,generate_hgrams(s,length(s)))
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1, hgrams)
        elems = Set(s)
        return new{T,length(s)}(db,Set(s))
    end
    function UHGramModel(ss::Vector{Vector{T}}) where T
        h = max(length.(ss))
        UHGramModel(vcat(map(s->generate_hgrams(s,length(s)),ss)...))
    end
end

order(::Model{T,n}) where {T,n} = n

# Number of occurences of g in m plus k
count(g::NGram{T,n},m::NGramModel{T,n},k::Number=0) where {T,n} = (c=Base.get(m.db,tovec(g),0); c>0 ? c+k : 0)
count(g::NGram{T,n},m::HGramModel{T,h},k::Number=0) where {T,n,h} = n<=h ? (c=Base.get(m.db,tovec(g),0); c>0 ? c+k : 0) : error("$h gram model does not include $n grams.")

# Number of unique symbols that have occured in context ctx
tcount(ctx::Vector{T},m::Model{T}) where T = sum(map(e->haskey(m.db,[e,ctx...]) ? 1 : 0,collect(m.elems)))

# Sum over e in a of count(e|g.context)+k
sumcount(g::NGram{T},m::Model{T},a::Set{T},k::Number=0) where T = sum(map(e->count(NGram(e,g.context),m,k),collect(a)))

# Symbols in s which occur exactly n times in s
occ(ctx::Vector{T},n::Int,m::Model{T}) where T = sum(map(e->count(NGram(e,ctx),m)==n ? 1 : 0,collect(m.elems)))

# Maximum Likelihood
function ml(g::NGram{T},m::Model{T},a::Set{T},k::Number=0) where T
    ctx_count = sumcount(g,m,a,k)
    ctx_count == 0 ? 0.0 : count(g,m,k) / ctx_count
end

ml(nxt::T,ctx::Vector{T},m::Model{T},a::Set{T}) where T = ml(NGram(nxt,ctx),m,a)
ml(nxt::T,m::Model{T},a::Set{T}) where T = ml(NGram(nxt),m,a)


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


# ALPHA AND GAMMA
function alpha(smth::Smoothing,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} end 
function gamma(smth::Smoothing,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} end

## Backoff Smoothing

non_nan_frac(a,b) = b == 0 ? 0 : a / b

gamma(::Backoff,::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = 1 / (sumcount(g,m,a)+length(a))
alpha(::Backoff,::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = count(g,m,0) / (sumcount(g,m,a)+length(a))

gamma(::Backoff,::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = non_nan_frac(tcount(g.context,m),sumcount(g,m,a))
alpha(::Backoff,::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (count(g,m)-1)/sumcount(g,m,a)

gamma(::Backoff,::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=tcount(g.context,m);non_nan_frac(t,(sumcount(g,m,a)+length(a)*t)))
alpha(::Backoff,::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = count(g,m)/(sumcount(g,m,a)+(length(a)*tcount(g.context,m)))

gamma(::Backoff,::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = non_nan_frac((0.5*tcount(g.context,m)),sumcount(g,m,a))
alpha(::Backoff,::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (count(g,m)-0.5)/sumcount(g,m,a)

gamma(::Backoff,::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=occ(g.context,1,m)+1; t/(sumcount(g,m,a)+(length(a)*t)))
alpha(::Backoff,::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = (t=occ(g.context,1,m)+1;count(g,m)/(sumcount(g,m,a)+(length(a)*t)))

## Interpolated Smoothing
lambda(esc::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a) / (sumcount(g,m,a)+1)
alpha(smth::Interpolated,esc::A,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(esc,g,m,a)*ml(g,m,a)

lambda(esc::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,-1.0) / (sumcount(g,m,a,-1)+tcount(g.context,m))
alpha(smth::Interpolated,esc::B,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(esc,g,m,a)*ml(g,m,a,-1)

lambda(esc::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,0.0) / (sumcount(g,m,a,0.0)+tcount(g.context,m))
alpha(smth::Interpolated,esc::C,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(esc,g,m,a)*ml(g,m,a,0.0)

lambda(esc::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a,-0.5) / (sumcount(g,m,a,-0.5)+(tcount(g.context,m)/2))
alpha(smth::Interpolated,esc::D,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(esc,g,m,a)*ml(g,m,a,-0.5)

lambda(esc::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = sumcount(g,m,a) / (sumcount(g,m,a)+occ(g.context,1,m))
alpha(smth::Interpolated,esc::AX,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = lambda(esc,g,m,a)*ml(g,m,a)

gamma(smth::Interpolated,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h} = 1 - lambda(esc,g,m,a)

# BACKOFF PPM
function ppm(smth::Backoff,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}
    order = n-1
    if n>h
        error("Cannot predict $n gram from $h gram model.")
    end

    if count(g,m) > 0
        return alpha(smth,esc,g,m,a)
    end
    
    if order == 0
        return 1/(length(a)+1-tcount(T[],m))
    end

    g2 = NGram(g.next,g.context[1:order-1])
    
    if tcount(g.context,m) > 0
        return gamma(smth,esc,g,m,a) * ppm(smth,esc,g2,m,a)
    end
    
    return ppm(smth,esc,g2,m,a)    
end

# INTERPOLATED PPM
function ppm(smth::Interpolated,esc::Escape,g::NGram{T,n},m::HGramModel{T,h},a::Set{T}) where {T,n,h}
    order = n-1
    if n>h
        error("Cannot predict $n gram from $h gram model.")
    end

    if order==0
        return 1 / (length(a) + 1 - tcount(T[],m))
    end

    gam = gamma(smth,esc,g,m,a)
    g2 = NGram(g.next,g.context[1:order-1])
    return alpha(smth,esc,g,m,a) + (gam * ppm(smth,esc,g2,m,a))    
end


    
ppm(smth::Smoothing,esc::Escape,nxt::T,ctx::Vector{T},m::HGramModel{T,h},a::Set{T}) where {T,h} = ppm(smth,esc,NGram(nxt,ctx),m,a)
ppm(smth::Smoothing,esc::Escape,nxt::T,m::HGramModel{T,h},a::Set) where {T,h} = ppm(smth,esc,NGram(nxt),m,a)

function ppm_seq(smth::Smoothing,esc::Escape,s::Vector{T},m::HGramModel{T,h},a::Set{T}) where {T,h}
    ngrams = map(i->trim(NGram(s[i:length(s)]),h),1:length(s))
    predictions = map(g->ppm(smth,esc,g,m,a),ngrams)
    return prod(predictions)
end



function ppm_star(smth::Interpolated,esc::Escape,g::NGram{T},m::HGramModel{T},a::Set{T}) where T
    n = order(m)
    gs = map(i->trim(g,i),1:n)
    ctxs = map(g->g.context,gs)
    is = findall(map(ctx->deterministic(ctx,m),ctxs))
    if !isempty(is)
        smallest_deterministic_context = gs[is[1]]
        return ppm(smth,esc,smallest_deterministic_context,m,a)
    end
    largest_matching_context = gs[last(findall(x->x>0,map(i->tcount(ctxs[i],m),1:n)))]
    return ppm(smth,esc,largest_matching_context,m,a)
end


# PREDICTOR

abstract type Predictor{T} end

struct AtomicPredictor{T} <: Predictor{T}
    smoothing::Smoothing
    escape::Escape
    model::Model{T,n} where n
    alphabet::Set{T}
    AtomicPredictor(smth::Smoothing,esc::Escape,m::Model{T,n}) where {T,n} = new{T}(smth,esc,m,m.elems)
end

struct CombinedPredictor{T} <: Predictor{T}
    predictors::Vector{S} where S<:Predictor{T}
    bias::Int
end

struct Distribution{T}
    predictor::Predictor{T}
    context::Vector{T}
end

(p::AtomicPredictor{T})(g::NGram{T,n}) where {T,n} = ppm(p.smoothing,p.escape,g,p.model,p.alphabet)

function (p::CombinedPredictor{T})(g::NGram{T,n}) where {T,n}
    distributions = map(pm->Distribution(pm,g.context),p.predictors)
    predictions = map(d->d(g.next),distributions)
    weights = map(d->weight(d,p.bias),distributions)
    return sum(map(x->x[1]*x[2],collect(zip(weights,predictions))))/sum(weights)
end

function (d::Distribution{T})(x::T) where T
    g = trim(NGram(x,d.context),order(d.predictor.model))
    d.predictor(g)
end

alphabet(p::AtomicPredictor{T}) where T = p.alphabet
alphabet(p::CombinedPredictor{T}) where T = union(map(alphabet,p.predictors)...)
alphabet(d::Distribution{T}) where T = alphabet(d.predictor)

information_content(g::NGram{T,n},p::Predictor{T}) where {T,n} = -log(2,p(g))
information_content(p::Predictor{T}) where T = (g::NGram{T,n} where n) -> information_content(g,p)
information_content(nxt::T,d::Distribution{T}) where T = information_content(NGram(nxt,d.context),d.predictor)

function mean_information_content(s::Vector{T},p::Predictor{T}) where T
    h = order(p.model)
    ngrams = map(i->trim(NGram(s[i:length(s)]),h),1:length(s))
    ics = map(g->ppm(p.smoothing,p.escape,g,p.model,p.alphabet),ngrams)
    return sum(ics)/length(s)
end

function entropy(ctx::Vector{T},p::Predictor{T}) where {T}
    ngrams = map(e->NGram(e,ctx),collect(alphabet(p)))
    predictions = map(p,ngrams)
    ics = map(information_content(p),ngrams)
    return sum(predictions.*ics)
end

entropy(d::Distribution{T}) where T = entropy(d.context,d.predictor)

max_entropy(p::Predictor{T}) where T = log(2,length(alphabet(p)))
max_entropy(d::Distribution{T}) where T = max_entropy(d.predictor)

redundancy(ctx::Vector{T},p::Predictor{T}) where T = 1 - (entropy(ctx,p)/max_entropy(p))
redundancy(d::Distribution{T}) where T = redundancy(d.context,d.predictor)

relative_entropy(ctx::Vector{T},p::Predictor{T}) where T = (hm=max_entropy(p); hm>0 ? entropy(ctx,p) / hm : 1 )
relative_entropy(d::Distribution{T}) where T = relative_entropy(d.context,d.predictor)

weight(ctx::Vector{T},p::Predictor{T},b::Int) where T = relative_entropy(ctx,p) ^ (-b)
weight(d::Distribution{T},b::Int) where T = weight(d.context,d.predictor,b)

end




