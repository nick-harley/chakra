module Models

using Chakra
export NGram, NGramModel, HGramModel, Predictor, AtomicPredictor, CombinedPredictor, Distribution, ml, ppm, information_content, mean_information_content, entropy, max_entropy, relative_entropy, redundancy, Backoff, Interpolated, A, B, C, D, AX

# Helper function to avoid 0/0 = NaN
non_nan(a,b) = b == 0 ? 0 : a / b

# Type of NGrams
struct NGram{T,S,n}
    next::T
    context::Vector{S}
    NGram(nxt::T,ctx::Vector{S}) where {T,S} = new{T,S,length(ctx)+1}(nxt,ctx)
    NGram(s::Vector{Tuple{T,S}}) where {T,S} = isempty(s) ? error("Cannot construct 0-gram.") : NGram(hd(s)[1],map(x->x[2],tl(s)))
end

order(g::NGram{T,S,n}) where {T,S,n} = n
tovec(g::NGram{T,S,n}) where {T,S,n} =  [g.next,g.context...]
topair(g::NGram{T,S,n}) where {T,S,n} = (g.next,g.context)
trim(s::Vector,l::Int) = length(s) <= l ? s : s[1:l]
trim(g::NGram{T,S,n},l::Int) where {T,S,n} = n<=l ? g : NGram(g.next,trim(g.context,l-1))

# Generate NGrams from a sequence
generate_ngrams(s::Vector{Tuple{T,S}},n::Int) where {T,S} = map(i->NGram(s[i:i+n]),1:length(s)-n)
generate_ngrams(s::Vector{T},n::Int) where T = map(i->NGram(s[i],s[i+1:i+n-1]),1:length(s)-n)
generate_hgrams(s::Vector{Tuple{T,S}},h::Int) where {T,S} = vcat(map(n->generate_ngrams(s,n),1:h)...)
generate_hgrams(s::Vector{T},h::Int) where T = vcat(map(n->generate_ngrams(s,n),1:h)...)

# Abstract type of models
abstract type Model{T,S,n} end

# Type of n-gram models of type T
struct NGramModel{T,S,n} <: Model{T,S,n}
    db::Dict{Tuple{T,Vector{S}},Int}
    elems::Set{T}
    function NGramModel(gs::Vector{NGram{T,S,n}}) where {T,S,n}
        db = Dict{Tuple{T,Vector{S}},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,topair.(gs))
        return new{T,S,n}(db,Set(map(g->g.next,gs)))
    end
    NGramModel(s::Vector,n::Int) = NGramModel(generate_ngrams(s,n))
end

# Type of HGram models
struct HGramModel{T,S,h} <: Model{T,S,h}
    db::Dict{Tuple{T,Vector{S}},Int}
    elems::Set{T}
    function HGramModel(gs::Vector{NGram{T,S}}) where {T,S}
        h = max(order.(gs)...)
        db = Dict{Tuple{T,Vector{S}},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,topair.(gs))
        return new{T,S,h}(db,Set(map(g->g.next,gs)))
    end
    HGramModel(s::Vector{T},h::Int) where T = HGramModel(generate_hgrams(s,h))
end

order(::Model{T,S,n}) where {T,S,n} = n

# The number of times an ngram has occurred in a model
c(g::NGram{T,S,n},m::NGramModel{T,S,n}) where {T,S,n} = Base.get(m.db,topair(g),0)
c(g::NGram{T,S},m::HGramModel{T,S,h}) where {T,S,h} = (g=trim(g,h);Base.get(m.db,topair(g),0))
c(nxt::T,ctx::Vector{T},m::Model{S,T}) where {S,T} = c(NGram(nxt,ctx),m)

# The number of occurrences of the context ctx followed by any symbol
sumc(ctx::Vector{S},m::Model{T,S}) where {T,S} = sum(map(e->c(NGram(e,ctx),m),collect(m.elems)))

# Number of occurences of g in m plus an initial count k
count(g::NGram{T,S},m::Model{T,S},k::Number) where {T,S} = (x=c(g,m); x>0 ? x+k : 0)

# The sum over e \in a of occurrence of (e|g.context) plus an initial count k
sumcount(ctx::Vector{S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = sum(map(e->count(NGram(e,ctx),m,k),collect(a)))

# The set of symbols that have occured in context ctx
symset(ctx::Vector{S},m::Model{T,S}) where {T,S} = Set(vcat(map(e->c(e,ctx,m)>0 ? [e] : [],collect(m.elems))...))

# The number of symbols that have occurred in context ctx
symcount(ctx::Vector{S},m::Model{T,S}) where {T,S} = length(symset(ctx,m))

# The set of symbols that have occurred n times in context ctx
nsymset(n::Int,ctx::Vector{S},m::Model{T,S}) where {T,S} = Set(vcat(map(e->c(e,ctx,m)==n ? [e] : [],collect(m.elems))...))

# The number of symbols which have occured n times in s
nsymcount(n::Int,ctx::Vector{S},m::Model{T,S}) where {T,S} = length(nsymset(n,ctx,m))

# Maximum Likelihood
ml(g::NGram{T,S},m::Model{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m),sumc(g.context,m))
ml(nxt::T,ctx::Vector{S},m::Model{T,S},a::Set{T}) where {T,S} = ml(NGram(nxt,ctx),m,a)
ml(nxt::T,m::Model{T,S},a::Set{T}) where {T,S} = ml(NGram(nxt,S[]),m,a)

# Maximum likelihood with initial count k
ml(g::NGram{T,S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = non_nan(count(g,m,k),sumcount(g.context,m,a,k))
ml(nxt::T,ctx::Vector{S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = ml(NGram(nxt,ctx),m,a,k)
ml(nxt::T,m::Model{T,S},a::Set{T},k::Number) where {T,S} = ml(NGram(nxt,S[]),m,a,k)

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

# Prediction Probability, Alpha

## Backoff
alpha(::Backoff,::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m),sumc(g.context,m)+length(a))
alpha(::Backoff,::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m)-1,sumc(g.context,m))
alpha(::Backoff,::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m),sumc(g.context,m)+length(a)*symcount(g.context,m)) ## CHECK BRACKETS
alpha(::Backoff,::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m)-0.5,sumc(g.context,m))
alpha(::Backoff,::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=nsymcount(1,g.context,m)+1; non_nan(c(g,m,0),sumc(g.context,m)+length(a)*t)) ## CHECK BRACKETS

## Interpolated
alpha(smth::Interpolated,esc::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)
alpha(smth::Interpolated,esc::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,-1)
alpha(smth::Interpolated,esc::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)
alpha(smth::Interpolated,esc::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,-0.5)
alpha(smth::Interpolated,esc::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)

# Escape Probability, Gamma

## Backoff smoothing
gamma(::Backoff,::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(1,sumc(g.context,m)+length(a))
gamma(::Backoff,::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(symcount(g.context,m),sumc(g.context,m))
gamma(::Backoff,::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=symcount(g.context,m);non_nan(t,sumc(g.context,m)+length(a)*t))
gamma(::Backoff,::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(0.5*symcount(g.context,m),sumc(g.context,m))
gamma(::Backoff,::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=nsymcount(1,g.context,m)+1; t/sumc(g.context,m)+length(a)*t)

## Interpolated Smoothing
gamma(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = 1 - lambda(esc,g,m,a)

lambda(esc::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0) + 1))
lambda(esc::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,-1),sumcount(g.context,m,a,-1)+symcount(g.context,m))
lambda(esc::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0)+symcount(g.context,m)))
lambda(esc::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,-0.5),(sumcount(g.context,m,a,-0.5)+(symcount(g.context,m)/2)))
lambda(esc::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0)+nsymcount(1,g.context,m)))


# Backoff PPM
function ppm(smth::Backoff,esc::Escape,g::NGram{T,S},m::HGramModel{T,S,h},a::Set{T}) where {T,S,h}
    g = trim(g,h)
    n = order(g)
    
    if c(g,m) > 0
        return alpha(smth,esc,g,m,a)
    end
    
    if n==1
        return 1/(length(a)+1)
        #return gamma(smth,esc,g,m,a)/(length(a)+1-symcount(T[],m))
    end

    gam = gamma(smth,esc,g,m,a)

    gam == 0 ? ppm(smth,esc,trim(g,n-1),m,a) : gam * ppm(smth,esc,trim(g,n-1),m,a)
    
end

# Interpolated PPM
function ppm(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S,h},a::Set{T}) where {T,S,h}
    g = trim(g,h) 
    n = order(g)

    if n==1
        return alpha(smth,esc,g,m,a) + gamma(smth,esc,g,m,a)/(length(a)+1-symcount(T[],m))
    end

    return alpha(smth,esc,g,m,a) + (gamma(smth,esc,g,m,a)*ppm(smth,esc,trim(g,n-1),m,a))
end

ppm(smth::Smoothing,esc::Escape,nxt::T,ctx::Vector{S},m::HGramModel{T,S},a::Set{T}) where {T,S} = ppm(smth,esc,NGram(nxt,ctx),m,a)
ppm(smth::Smoothing,esc::Escape,nxt::T,m::HGramModel{T,S},a::Set) where {T,S} = ppm(smth,esc,NGram(nxt,S[]),m,a)

# The probability of a sequence of ts occuring in the context of a sequence of ss
function seq_ppm(smth::Smoothing,esc::Escape,s::Vector{Tuple{T,S}},m::HGramModel{T,S},a::Set{T}) where {T,S}
    ngrams = map(i->trim(NGram(s[i:length(s)]),h),1:length(s))
    predictions = map(g->ppm(smth,esc,g,m,a),ngrams)
    return prod(predictions)
end

# ppm*
# IS THIS CORRECT???
function ppms(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S}
    g = trim(g,order(m))
    n = order(g)
    gs = map(i->trim(g,i),1:n)
    ctxs = map(g->g.context,gs)
    is = findall(map(ctx->symcount(ctx,m)==1,ctxs))
    if !isempty(is)
        smallest_deterministic_context = gs[is[1]]
        return ppm(smth,esc,smallest_deterministic_context,m,a)
    end
    tcs = map(i->symcount(ctxs[i],m),1:n)
    matching_ctxs = findall(tc->tc > 0,tcs)
    largest_matching_context = last(matching_ctxs)
    return ppm(smth,esc,gs[largest_matching_context],m,a)
end

# The probability of a sequence of ts occuring in the context of a sequence of ss using ppm*
function seq_ppms(smth::Smoothing,esc::Escape,s::Vector{Tuple{T,S}},m::HGramModel{T,S},a::Set{T}) where {T,S}
    ngrams = map(i->trim(NGram(s[i:length(s)]),h),1:length(s))
    predictions = map(g->ppm_star(smth,esc,g,m,a),ngrams)
    return prod(predictions)
end


# PREDICTOR

abstract type Predictor{T,S} end

struct AtomicPredictor{T,S} <: Predictor{T,S}
    smoothing::Smoothing
    escape::Escape
    model::Model{T,S}
    alphabet::Set{T}
    AtomicPredictor(smth::Smoothing,esc::Escape,m::Model{T,S},a::Set{T}) where {T,S} = new{T,S}(smth,esc,m,a)
    AtomicPredictor(smth::Smoothing,esc::Escape,m::Model{T,S}) where {T,S} = AtomicPredictor(smth,esc,m,m.elems)
end

struct CombinedPredictor{T,S} <: Predictor{T,S}
    predictors::Vector{Predictor{T,S}}
    bias::Int
end

# DISTRIBUTION

struct Distribution{T,S}
    predictor::Predictor{T,S}
    context::Vector{S}
end

(p::AtomicPredictor{T,S})(g::NGram{T,S}) where {T,S} = ppm(p.smoothing,p.escape,g,p.model,p.alphabet)

function (p::CombinedPredictor{T,S})(g::NGram{T,S}) where {T,S}
    distributions = map(pm->Distribution(pm,g.context),p.predictors)
    predictions = map(d->d(g.next),distributions)
    weights = map(d->weight(d,p.bias),distributions)
    return sum(weights .* predictions)/sum(weights)
end

function (d::Distribution{T,S})(x::T) where {T,S}
    g = trim(NGram(x,d.context),order(d.predictor.model))
    d.predictor(g)
end

alphabet(p::AtomicPredictor)= p.alphabet
alphabet(p::CombinedPredictor) = union(alphabet.(p.predictors)...)
alphabet(d::Distribution) = alphabet(d.predictor)

information_content(g::NGram{T,S},p::Predictor{T,S}) where {T,S} = -log(2,p(g))
information_content(p::Predictor) = (g::NGram) -> information_content(g,p)
information_content(nxt::T,d::Distribution{T}) where T = information_content(NGram(nxt,d.context),d.predictor)

function mean_information_content(s::Vector{Tuple{T,S}},p::Predictor{T,S}) where {T,S}
    h = order(p.model)
    ngrams = map(i->trim(NGram(s[i:length(s)]),h),1:length(s))
    ics = map(g->ppm(p.smoothing,p.escape,g,p.model,p.alphabet),ngrams)
    return sum(ics)/length(s)
end
mean_information_content(s::Vector{T},p::Predictor{T,T}) where T = mean_information_content(collect(zip(s,s)),p)

function entropy(ctx::Vector{S},p::Predictor{T,S}) where {T,S}
    ngrams = map(e->NGram(e,ctx),collect(alphabet(p)))
    predictions = map(p,ngrams)
    ics = map(information_content(p),ngrams)
    return sum(predictions.*ics)
end

entropy(d::Distribution) = entropy(d.context,d.predictor)

max_entropy(p::Predictor) = log(2,length(alphabet(p)))
max_entropy(d::Distribution) = max_entropy(d.predictor)

redundancy(ctx::Vector{S},p::Predictor{T,S}) where {T,S} = 1 - (entropy(ctx,p)/max_entropy(p))
redundancy(d::Distribution) = redundancy(d.context,d.predictor)

relative_entropy(ctx::Vector{S},p::Predictor{T,S}) where {T,S} = (hm=max_entropy(p); hm>0 ? entropy(ctx,p) / hm : 1 )
relative_entropy(d::Distribution) = relative_entropy(d.context,d.predictor)

weight(ctx::Vector{S},p::Predictor{T,S},b::Int) where {T,S} = relative_entropy(ctx,p) ^ (-b)
weight(d::Distribution,b::Int) = weight(d.context,d.predictor,b)

end




