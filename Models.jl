module Models

using Chakra
export NGram, NGramModel, HGramModel, Predictor, AtomicPredictor, CombinedPredictor, Distribution, ml, ppm, information_content, mean_information_content, entropy, max_entropy, relative_entropy, Backoff, Interpolated, A, B, C, D, AX

# Helper function to avoid 0/0 = NaN
non_nan(a,b) = b == 0 ? 0 : a / b



# NGRAMS



struct NGram{T,S,n}
    next::T
    context::Vector{S}
    NGram(nxt::T,ctx::Vector{S}) where {T,S} = new{T,S,length(ctx)+1}(nxt,ctx)
    NGram(s::Vector{Tuple{T,S}}) where {T,S} = isempty(s) ? error("Cannot construct 0-gram.") : NGram(s[1][1],map(x->x[2],s[2:end]))
end

Base.length(g::NGram{T,S,n}) where {T,S,n} = n
order(g::NGram) = length(g) - 1
topair(g::NGram{T,S,n}) where {T,S,n} = (g.next,g.context)
trim(s::Vector,l::Int) = l >= 0 ? (length(s) <= l ? s : s[1:l]) : error("l must be greater than 0.")
trim(g::NGram{T,S,n},l::Int) where {T,S,n} = n<=l ? g : NGram(g.next,trim(g.context,l-1))
next_type(::NGram{T,S,n}) where {T,S,n} = S
context_type(::NGram{T,S,n}) where {T,S,n} = T


# Generate NGrams from a vector

generate_ngrams(s::Vector{Tuple{T,S}},n::Int) where {T,S} = map(i->NGram(s[i:i+n]),1:length(s)-n)
generate_ngrams(s::Vector{T},n::Int) where T = map(i->NGram(s[i],s[i+1:i+n-1]),1:length(s)-n)

generate_hgrams(s::Vector{Tuple{T,S}},h::Int) where {T,S} = vcat(map(n->generate_ngrams(s,n),1:h)...)
generate_hgrams(s::Vector{T},h::Int) where T = vcat(map(n->generate_ngrams(s,n),1:h)...)

# Generate the sequence of maximal HGrams from a vector

hgram_sequence(s::Vector{Tuple{T,S}}) where {T,S} = map(i->NGram(s[i:end]),1:length(s))
hgram_sequence(s::Vector{T}) where T = hgram_sequence(collect(zip(s,s)))


# MODELS



abstract type Model{T,S,n} end

next_type(::Model{T,S,n}) where {T,S,n} = S
context_type(::Model{T,S,n}) where {T,S,n} = T
order(::Model{T,S,n}) where {T,S,n} = n-1



# N-GRAM MODEL



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



# H-GRAM MODEL



struct HGramModel{T,S,h} <: Model{T,S,h}
    db::Dict{Tuple{T,Vector{S}},Int}
    elems::Set{T}
    function HGramModel(gs::Vector{NGram{T,S}}) where {T,S}
        h = max(length.(gs)...)
        db = Dict{Tuple{T,Vector{S}},Int}()
        map(g->haskey(db,g) ? db[g] += 1 : db[g] = 1,topair.(gs))
        return new{T,S,h}(db,Set(map(g->g.next,gs)))
    end
    HGramModel(s::Vector,h::Int) = HGramModel(generate_hgrams(s,h))
end

(m::HGramModel)(xs...) = ml(xs..., m)




# COUNT: The number of times an NGram has occured in a model
c(g::NGram{T,S,n},m::NGramModel{T,S,n}) where {T,S,n} = Base.get(m.db,topair(g),0)
c(g::NGram{T,S},m::HGramModel{T,S,h}) where {T,S,h} = (g=trim(g,h);Base.get(m.db,topair(g),0))
c(nxt::T,ctx::Vector{T},m::Model{S,T}) where {S,T} = c(NGram(nxt,ctx),m)



# SUMC: The number of occurrences of the context ctx followed by any symbol
sumc(ctx::Vector{S},m::Model{T,S}) where {T,S} = sum(map(e->c(NGram(e,ctx),m),collect(m.elems)))



# COUNT: Number of occurences of g in m plus an initial count k
count(g::NGram{T,S},m::Model{T,S},k::Number) where {T,S} = (x=c(g,m); x>0 ? x+k : 0)



# SUMCOUNT: The sum over e \in a of occurrence of (e|g.context) plus an initial count k
sumcount(ctx::Vector{S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = sum(map(e->count(NGram(e,ctx),m,k),collect(a)))



# SYMSET: The set of symbols that have occured in context ctx
symset(ctx::Vector{S},m::Model{T,S}) where {T,S} = Set(vcat(map(e->c(e,ctx,m)>0 ? [e] : [],collect(m.elems))...))



# SYMCOUNT: The number of symbols that have occurred in context ctx
symcount(ctx::Vector{S},m::Model{T,S}) where {T,S} = length(symset(ctx,m))



# NSYMSET: The set of symbols that have occurred n times in context ctx
nsymset(n::Int,ctx::Vector{S},m::Model{T,S}) where {T,S} = Set(vcat(map(e->c(e,ctx,m)==n ? [e] : [],collect(m.elems))...))



# NSYMCOUNT: The number of symbols which have occured n times in s
nsymcount(n::Int,ctx::Vector{S},m::Model{T,S}) where {T,S} = length(nsymset(n,ctx,m))



# ML: Maximum Likelihood
ml(g::NGram{T,S},m::Model{T,S}) where {T,S} = non_nan(c(g,m),sumc(g.context,m))
ml(nxt::T,ctx::Vector{S},m::Model{T,S}) where {T,S} = ml(NGram(nxt,ctx),m)
ml(nxt::T,m::Model{T,S}) where {T,S} = ml(NGram(nxt,S[]),m)

# Maximum likelihood with initial count k
ml(g::NGram{T,S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = non_nan(count(g,m,k),sumcount(g.context,m,a,k))
ml(nxt::T,ctx::Vector{S},m::Model{T,S},a::Set{T},k::Number) where {T,S} = ml(NGram(nxt,ctx),m,a,k)
ml(nxt::T,m::Model{T,S},a::Set{T},k::Number) where {T,S} = ml(NGram(nxt,S[]),m,a,k)



# PREDICTION



# ESCAPE:

# Abstract type of smoothing escape methods
abstract type Escape end

# Concrete types for smoothing escape methods
struct A <: Escape end
struct B <: Escape end
struct C <: Escape end
struct D <: Escape end
struct AX <: Escape end

# SMOOTHING:

# Abstract type of smoothing method
abstract type Smoothing end

# Concrete types of smoothing methods
struct Interpolated <: Smoothing end
struct Backoff <: Smoothing end



# ALPHA: Prediction Probability



## Alpha for backoff smoothing
alpha(::Backoff,::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m),sumc(g.context,m)+length(a))
alpha(::Backoff,::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m)-1,sumc(g.context,m))
alpha(::Backoff,::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m),sumc(g.context,m)+length(a)*symcount(g.context,m)) ## CHECK BRACKETS
alpha(::Backoff,::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(c(g,m)-0.5,sumc(g.context,m))
alpha(::Backoff,::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=nsymcount(1,g.context,m)+1; non_nan(c(g,m,0),sumc(g.context,m)+length(a)*t)) ## CHECK BRACKETS

## Alpha for interpolated smoothing
alpha(smth::Interpolated,esc::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)
alpha(smth::Interpolated,esc::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,-1)
alpha(smth::Interpolated,esc::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)
alpha(smth::Interpolated,esc::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,-0.5)
alpha(smth::Interpolated,esc::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = lambda(esc,g,m,a)*ml(g,m,a,0)



# GAMMA: Escape probability



## gamma for backoff smoothing
gamma(::Backoff,::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(1,sumc(g.context,m)+length(a))
gamma(::Backoff,::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(symcount(g.context,m),sumc(g.context,m))
gamma(::Backoff,::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=symcount(g.context,m);non_nan(t,sumc(g.context,m)+length(a)*t))
gamma(::Backoff,::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(0.5*symcount(g.context,m),sumc(g.context,m))
gamma(::Backoff,::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = (t=nsymcount(1,g.context,m)+1; t/sumc(g.context,m)+length(a)*t)

## gamma for interpolated Smoothing
gamma(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = 1 - lambda(esc,g,m,a)

lambda(esc::A,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0) + 1))
lambda(esc::B,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,-1),sumcount(g.context,m,a,-1)+symcount(g.context,m))
lambda(esc::C,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0)+symcount(g.context,m)))
lambda(esc::D,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,-0.5),(sumcount(g.context,m,a,-0.5)+(symcount(g.context,m)/2)))
lambda(esc::AX,g::NGram{T,S},m::HGramModel{T,S},a::Set{T}) where {T,S} = non_nan(sumcount(g.context,m,a,0),(sumcount(g.context,m,a,0)+nsymcount(1,g.context,m)))



# PPM: PREDICTION BY PARTIAL MATCH



struct PPMModel{T,S,h} <: Model{T,S,h}
    smoothing::Smoothing
    escape::Escape
    model::HGramModel{T,S,h}
    alphabet::Set{T}
    PPMModel(smth::Smoothing,esc::Escape,m::HGramModel{T,S,h},a::Set{T}) where {T,S,h} = new{T,S,h}(smth,esc,m,a)
    PPMModel(smth::Smoothing,esc::Escape,m::HGramModel{T,S,h}) where {T,S,h} = PPMModel(smth,esc,m,m.elems)
end

(m::PPMModel)(g::NGram) = ppm(m.smoothing,m.escape,g,m.model,m.alphabet)


# Backoff PPM
function ppm(smth::Backoff,esc::Escape,g::NGram{T,S},m::HGramModel{T,S,h},a::Set{T}) where {T,S,h}
    g = trim(g,h)
    n = length(g)
    
    if c(g,m) > 0
        return alpha(smth,esc,g,m,a)
    end
    
    if n==1
        return 1/(length(a)+1) #1/(length(a)+1-symcount(T[],m))
    end

    gam = gamma(smth,esc,g,m,a)

    # WHEN MIGHT GAMMA BE ZERO?
    gam == 0 ? ppm(smth,esc,trim(g,n-1),m,a) : gam * ppm(smth,esc,trim(g,n-1),m,a)
end

# Interpolated PPM
function ppm(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S,h},a::Set{T}) where {T,S,h}
    g = trim(g,h)
    n = length(g)

    if n==1
        # SHOULD THAT GAMMA BE THERE?
        return alpha(smth,esc,g,m,a) + gamma(smth,esc,g,m,a)/(length(a)+1-symcount(T[],m))
    end
    return alpha(smth,esc,g,m,a) + (gamma(smth,esc,g,m,a)*ppm(smth,esc,trim(g,n-1),m,a))
end

ppm(smth::Smoothing,esc::Escape,nxt::T,ctx::Vector{S},m::HGramModel{T,S},a::Set{T}) where {T,S} = ppm(smth,esc,NGram(nxt,ctx),m,a)
ppm(smth::Smoothing,esc::Escape,nxt::T,m::HGramModel{T,S},a::Set) where {T,S} = ppm(smth,esc,NGram(nxt,S[]),m,a)



# PPM*
# IS THIS CORRECT???



struct PPMSModel{T,S,h} <: Model{T,S,h}
    smoothing::Smoothing
    escape::Escape
    model::HGramModel{T,S,h}
    alphabet::Set{T}
    PPMSModel(smth::Smoothing,esc::Escape,m::HGramModel{T,S,h},a::Set{T}) where {T,S,h} = new{T,S,h}(smth,esc,m,a)
    PPMSModel(smth::Smoothing,esc::Escape,m::HGramModel{T,S,h}) where {T,S,h} = PPMSModel(smth,esc,m,m.elems)
end

(m::PPMSModel)(g::NGram) = ppm_star(m.smoothing,m.escape,g,m.model,m.alphabet)


function ppm_star(smth::Interpolated,esc::Escape,g::NGram{T,S},m::HGramModel{T,S,h},a::Set{T}) where {T,S,h}
    seq = trim(g,h)
    n = length(seq)
    ngrams = map(i->trim(seq,i),1:n)
    contexts = map(g->g.context,ngrams)
    context_symcounts = map(ctx->symcount(ctx,m),contexts)
    deterministic_contexts = findall(context_symcounts .== 1)
    if !isempty(deterministic_contexts)
        smallest_deterministic_context = ngrams[deterministic_contexts[1]]
        return ppm(smth,esc,smallest_deterministic_context,m,a)
    end
    symbol_counts = map(i->symcount(contexts[i],m),1:n)
    matching_contexts = findall(symbol_counts .> 0)
    largest_matching_context = last(matching_contexts)
    return ppm(smth,esc,gs[largest_matching_context],m,a)
end



# HYBRID MODELS



struct HybridModel{T,S,h} <: Model{T,S,h}
    models::Vector{Model{T}}
    bias::Int
    function HybridModel(ms::Vector{Model{T}},b::Int) where T
        ctx_types = context_type.(ms)
        h = max(order.(ms)) + 1
        new{T,Tuple{ms...},h}(ms,b)
    end
end

function (m::HybridModel{T,S,h})(g::NGram{T,S}) where {T,S,h}
    nxt = g.next
    ctx = g.context
    models = m.models
    b = m.bias
    predictions = map(mi -> mi(g),models)
    distributions = map(Distribution(m,ctx),models)
    weights = map(d->weight(d,b),distributions)
    return sum(weights.*predictions) / sum(weights)
end



# The probability of a sequence of ts occuring in the context of a sequence of ss
predict_sequence(m::Model{T,S,h},s::Vector{Tuple{T,S}}) where {T,S,h} = prod(m.(hgram_sequence(s)))

alphabet(m::NGramModel) = m.elems
alphabet(m::HGramModel) = m.elems
alphabet(m::PPMModel) = alphabet(m.model)
alphabet(m::PPMSModel) = alphabet(m.model)
alphabet(m::HybridModel) = union(alphabet.(m.models)...)

# DISTRIBUTION



struct Distribution{T}
    model::Model{T}
    context::Vector
    Distribution(m::Model{T,S,n},ctx::Vector{S}) where {T,S,n} = new{T}(m,ctx)
end

(d::Distribution{T})(x::T) where T = d.model(NGram(x,d.context))

alphabet(d::Distribution) = alphabet(d.model)

information_content(g::NGram{T,S},m::Model{T,S}) where {T,S} = -log(2,m(g))
information_content(nxt,ctx::Vector,m::Model) = information_content(NGram(nxt,ctx),m)
information_content(nxt,d::Distribution) = information_content(NGram(nxt,d.context),d.model)
information_content(d::Distribution) = (x) -> information_content(x,d)

mean_information_content(s::Vector,m::Model) =
sum(map(g->information_content(g,m),hgram_sequence(s)))/length(s)

function entropy(d::Distribution)
    a = alphabet(d)
    predictions = map(d,collect(a))
    print(predictions)
    ics = map(information_content(d),collect(a))
    print(ics)
    return sum(predictions.*ics)
end

max_entropy(d::Distribution) = log(2,length(alphabet(d)))

relative_entropy(d::Distribution) = (hm=max_entropy(d); hm>0 ? entropy(d) / hm : 1 )

weight(d::Distribution,b::Int) = relative_entropy(d) ^ (-b)

end




