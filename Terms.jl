module Terms

export Term, Variable, Set, Prop, Type, Lambda, Product, Application, EmptyContext, subst, unfold, beta, type, equiv, assume, Assume, define, Define, Var, Pi, Fun, App


# TERMS



abstract type Term end



# SORTS



abstract type Sort <: Term end

struct Set <: Sort end

struct Prop <: Sort end

struct Type <: Sort
    u::Int
    Type(u::Int) = u <= 0 ? Set() : new(u)
end

universe(::Set) = 0
universe(::Prop) = 0
universe(T::Type) = T.u



# DONTCARE



struct DontCare end
dontcare = DontCare()



# VARIABLES



RESERVED_IDS = Symbol[:_, :Set, :Prop]

struct Variable <: Term
    ident::Symbol
    Variable(x::Symbol) = x in RESERVED_IDS ? error("Invalid variable identifier: $x is a reserved identifier.") : new(x)
end



# BINDERS



Binder = Union{Variable,DontCare}



# PRODUCTS



struct Product <: Term
    binder::Binder
    domain::Term
    codomain::Term
    Product(T::Term,U::Term) = new(dontcare,T,U)
    Product(x::DontCare,T::Term,U::Term) = new(x,T,U)
    Product(x::Variable,T::Term,U::Term) = !isFreeIn(x,U) ? new(dontcare,T,U) : new(x,T,U)
    Product(x::Symbol,T::Term,U::Term) = x == :_ ? new(dontcare,T,U) : Product(Variable(x),T,U)
end



# LAMBDA



struct Lambda <: Term
    binder::Binder
    domain::Term
    body::Term
    Lambda(T::Term,u::Term) = new(dontcare,T,u)
    Lambda(x::DontCare,T::Term,u::Term) = new(x,T,u)
    Lambda(x::Variable,T::Term,u::Term) = !isFreeIn(x,u) ? new(dontcare,T,u) : new(x,T,u)
    Lambda(x::Symbol,T::Term,u::Term) = x==:_ ? new(dontcare,T,u) : Lambda(Variable(x),T,u)
end



# APPLICATION



struct Application <: Term
    head::Term
    argument::Term
end



# TERM INTERFACE



Exp = Union{Term,Symbol}
Binding = Tuple{Union{Symbol,Variable},Exp}

parse(x::Symbol) = Variable(x)
parse(t::Term) = t

Var(x::Symbol) = parse(x)

function Pi(xs::Union{Binding,Exp}...)
    if length(xs) == 0
        error("Expected terms.")
    elseif length(xs) == 1 && xs[1] isa Exp
        return parse(xs[1])
    elseif xs[1] isa Binding
        return Product(parse(xs[1][1]),parse(xs[1][2]),Pi(xs[2:end]...))
    elseif xs[1] isa Exp
        return Product(dontcare,parse(xs[1]),Pi(xs[2:end]...))
    end
    error("Cannot construct product type from $xs.")
end

function Fun(xs::Union{Binding,Exp}...)
    if length(xs) == 0
        error("Expected terms.")
    elseif length(xs) == 1 && xs[1] isa Exp
        return parse(xs[1])
    elseif xs[1] isa Binding
        return Lambda(parse(xs[1][1]),parse(xs[1][2]),Fun(xs[2:end]...))
    elseif xs[1] isa Exp
        return Lambda(dontcare,parse(xs[1]),Fun(xs[2:end]...))
    end
    error("Cannot construct lambda abstraction from $xs.")
end

function App(xs::Exp...)
    if length(xs) == 0
        error("Expected terms.")
    elseif length(xs) == 1
        return parse(xs[1])
    elseif length(xs) == 2
        return Application(parse(xs[1]),parse(xs[2]))
    else
        return App(Application(parse(xs[1]),parse(xs[2])),xs[3:end]...)
    end
    error("Cannot construct application.")
end

(f::Symbol)(xs::Exp...) = App(f,xs...)
(f::Term)(xs::Exp...) = App(f,xs...) 



# CONTEXTS



abstract type Context end

struct EmptyContext <: Context end

struct Assumption <: Context
    var::Variable
    type::Term
    rest::Context
    function Assumption(x::Variable,T::Term,G::Context)
        if declares(G,x)
            Errors.already_exists(x)
        end
        s = beta(type(T,G),G)
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        new(x,T,G)
    end
end

struct Definition <: Context
    var::Variable
    body::Term
    type::Term
    rest::Context
    function Definition(x::Variable,t::Term,T::Term,G::Context)
        if declares(G,x)
            Errors.already_exists(x)
        end
        body_type = type(t,G)
        if T != body_type
            Errors.incorrect_type(t,body_type,T)
        end
        new(x,t,T,G)
    end
end

struct LocalAssumption <: Context
    var::Variable
    type::Term
    rest::Context
    function LocalAssumption(x::Variable,T::Term,G::Context)
        s = beta(type(T,G),G)
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        new(x,T,G)
    end
    function LocalAssumption(::DontCare,T::Term,G::Context)
        s = beta(type(T,G),G)
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        return G
    end
end

Base.getindex(G::EmptyContext,x::Variable) = x
Base.getindex(G::Assumption,x::Variable) = x == G.var ? x : Base.getindex(G.rest,x)
Base.getindex(G::Definition,x::Variable) = x == G.var ? G.body : Base.getindex(G.rest,x)

declares(::EmptyContext,x::Variable) = false
declares(G::Assumption,x::Variable) = x == G.var ? true : declares(G.rest,x)
declares(G::Definition,x::Variable) = x == G.var ? true : declares(G.rest,x)

assume(x::Variable,T::Term,G::Context) = Assumption(x,T,G)
assume(x::Symbol,E::Exp,G::Context) = Assumption(Variable(x),parse(E),G)

define(x::Variable,t::Term,T::Term,G::Context) = Definition(x,t,T,G)
define(x::Variable,t::Term,G::Context) = define(x,t,type(t,G),G)
define(x::Symbol,e::Exp,E::Exp,G::Context) = define(Variable(x),parse(e),parse(E),G)
define(x::Symbol,e::Exp,G::Context) = define(Variable(x),parse(e),G)

assumeLocal(x::Variable,T::Term,G::Context) = LocalAssumption(x,T,G)
assumeLocal(::DontCare,T::Term,G::Context) = (x = getFreshVar(G,T); assume(x,T,G))

macro Init()
    esc(:(G = EmptyContext()))
end

macro Assume(x,t)
    esc(:(G = Terms.assume($x,$t,G)))
end

macro Define(x,t)
    esc(:(G = Terms.define($x,$t,G)))
end

macro Define(x,t,T)
    esc(:(G = Terms.define($x,$t,$T,G)))
end



getVars(::EmptyContext) = Base.Set{Variable}()
getVars(G::Union{Assumption,Definition}) = push!(getVars(G.rest),G.var)
getVars(t::Variable) = Base.Set{Variable}([t])
getVars(t::Sort) = Base.Set{Variable}()
getVars(::DontCare) = Base.Set{Variable}()
getVars(t::Product) = union(getVars(t.binder), getVars(t.domain), getVars(t.codomain))
getVars(t::Lambda) = union(getVars(t.binder), getVars(t.domain), getVars(t.body))
getVars(t::Application) = union(getVars(t.head), getVars(t.argument))
getVars(xs::Union{Term,Context}...) = union(getVars.(xs)...)


function getFreshVar(vs::Base.Set{Variable})
    xs = map(v->v.ident,collect(vs))
    i = 0
    x = Symbol("v$i")
    while x in xs
        i += 1
        x = Symbol("v$i")
    end
    return Variable(x)
end

getFreshVar(xs::Union{Term,Context}...) = getFreshVar(getVars(xs...))

function alphaRename(t::Lambda,x::Variable)
    if x == t.binder
        return t
    end
    if x in freeVars(t.body)
        error("Cannot alpha rename: The variable $x occurs free in $t. alphaRename($t,$x) results in variable capture.")
    end
    return Lambda(x,t.domain,subst(x,t.binder,t.body))
end
function alphaRename(t::Product,x::Variable)
    if x == t.binder
        return t
    end
    if x in freeVars(t.codomain)
        error("Cannot alpha rename: The variable $x occurs free in $t. alphaRename($t,$x) results in variable capture.")
    end
    return Product(x,t.domain,subst(x,t.binder,t.codomain))
end
alphaRename(t::Lambda,xs::Base.Set{Variable}) = (x = getFreshVar(xs); Lambda(x,t.domain,subst(x,t.binder,t.body)))
alphaRename(t::Product,xs::Base.Set{Variable}) = (x = getFreshVar(xs); Product(x,t.domain,subst(x,t.binder,t.codomain)))
alphaRename(t::Term,G::Context) = alphaRename(t,getVars(t,G))




# FREE VARIABLES



freeVars(t::Sort,bvs::Vector{Variable}) = Variable[]
freeVars(t::Variable,bvs::Vector{Variable}) = t in bvs ? Variable[] : [t]
freeVars(t::Product,bvs::Vector{Variable}) = ( t.binder isa DontCare ? bvs2 = bvs : bvs2 = [t.binder,bvs...]; vcat(freeVars(t.domain,bvs),freeVars(t.codomain,bvs2)))
freeVars(t::Lambda,bvs::Vector{Variable}) = ( t.binder isa DontCare ? bvs2 = bvs : bvs2 = [t.binder,bvs...]; vcat(freeVars(t.domain,bvs),freeVars(t.body,bvs2)))
freeVars(t::Application,bvs::Vector{Variable}) = vcat(freeVars(t.head,bvs),freeVars(t.argument,bvs))
freeVars(t::Term) = freeVars(t,Variable[])

isFreeIn(x::Variable,t::Term) = x in freeVars(t)
isFreeIn(::DontCare,t::Term) = false



# subst: CAPTURE AVOIDING SUBSTITUTION



subst(m::Term,x::Variable,t::Sort) = t
subst(m::Term,::DontCare,t::Term) = t
subst(m::Term,x::Variable,t::Variable) = t == x ? m : t
function subst(m::Term,x::Variable,t::Lambda,)
    if t.binder == x
        return Lambda(t.binder,subst(m,x,t.domain),t.body)
    end
    if t.binder in freeVars(m)
        t_alpha = alphaRename(t,getVars(t,m,x))
        return Lambda(t_alpha.binder,subst(m,x,t_alpha.domain),subst(m,x,t_alpha.body))
    end
    return Lambda(t.binder,subst(m,x,t.domain),subst(m,x,t.body))
end
function subst(m::Term,x::Variable,t::Product)
    if t.binder == x
        return Product(t.binder,subst(m,x,t.domain),t.codomain)
    end
    if t.binder in freeVars(m)
        t_alpha = alphaRename(t,getVars(t,m,x))
        return Product(t_alpha.binder,subst(m,x,t_alpha.domain),subst(m,x,t_alpha.codomain))
    end
    Product(t.binder,subst(m,x,t.domain),subst(m,x,t.codomain))

end
subst(m::Term,x::Variable,t::Application) = Application(subst(m,x,t.head),subst(m,x,t.argument))



# unfold: DELTA REDUCTION



unfold(t::Term,G::Context) = t
unfold(x::Variable,G::Context) = G[x]
unfold(x::Symbol,G::Context) = unfold(Variable(x),G)
unfold(t::Lambda,G::Context) = Lambda(t.binder,unfold(t.domain,G),unfold(t.body,G))
unfold(t::Product,G::Context) = Product(t.binder,unfold(t.domain,G),unfold(t.codomain,G))
unfold(t::Application,G::Context) = Application(unfold(t.head,G),unfold(t.argument,G))




# BETA REDUCTION OF TERMS



beta(t::Term,G::Context) = unfold(t,G)
beta(t::Lambda,G::Context) = Lambda(t.binder,beta(t.domain,G),beta(t.body,G))
beta(t::Product,G::Context) = Product(t.binder,beta(t.domain,G),beta(t.codomain,G))
function beta(t::Application,G::Context)
    h = beta(t.head,G)
    a = beta(t.argument,G)
    h isa Lambda ? beta(subst(a,h.binder,h.body),G) : Application(h,a)
end



# EQUIVALENCE OF TERMS

Base.:(==)(t1::Variable,t2::Variable) = t1.ident == t2.ident
function Base.:(==)(f::Lambda,g::Lambda)
    vs = getVars(f,g)
    v = getFreshVar(vs)
    f2 = alphaRename(f,v)
    g2 = alphaRename(g,v)
    f2.domain == g2.domain && f2.body == g2.body
end
function Base.:(==)(T::Product,U::Product)
    vs = getVars(T,U)
    v = getFreshVar(vs)
    T2 = alphaRename(T,v)
    U2 = alphaRename(U,v)
    T2.domain == U2.domain && T2.codomain == U2.codomain
end


equiv(t1,t2,G) = beta(t1,G) == beta(t2,G)
equiv(t1,t2) = equiv(t1,t2,EmptyContext())



# COMPUTE TYPE OF A TERM



function type(t::Sort,::Context)
    Type(universe(t)+1)
end
function type(t::Variable,::EmptyContext)
    Errors.unknown_reference(t)
end
function type(t::Variable,G::Union{Assumption,Definition,LocalAssumption})
    t == G.var ? G.type : type(t,G.rest)
end
function type(x::Symbol,G::Context)
    type(Variable(x),G)
end
function type(t::Lambda,G::Context)
    t2 = t
    if t.binder in getVars(G)
        t2 = alphaRename(t,G)
    end
    Gex = assumeLocal(t2.binder,t2.domain,G)
    body_type = type(t2.body,Gex)
    return Product(t2.binder,t2.domain,body_type)
end
function type(t::Product,G::Context)
    t2 = t
    if t.binder in getVars(G)
        t2 = alphaRename(t,G)
    end
    Gex = assumeLocal(t2.binder,t2.domain,G)
    dom_type = beta(type(t2.domain,G),G)
    cod_type = beta(type(t2.codomain,Gex),Gex)
    if cod_type isa Prop
        return Prop()
    elseif cod_type isa Set && (dom_type isa Union{Prop,Set})
        return Set()
    elseif cod_type isa Type
        return Type(max(universe(dom_type),universe(cod_type)))
    else
        Errors.sort_expected(t.codomain,cod_type)
    end
end
function type(t::Application,G::Context)
    head_type = type(t.head,G)
    arg_type = type(t.argument,G)

    if !(head_type isa Product)
        Errors.illegal_application(t.head,head_type,t.argument,arg_type)
    end
    if head_type.domain != arg_type
        Errors.incorrect_type(t.argument,arg_type,head_type.domain)
    end
    return subst(t.argument,head_type.binder,head_type.codomain)
end



# ERROR MESSAGES



module Errors
    illegal_application(f,T,t,U) = error("Illegal application (Non-functional construction):\nThe expression $f of type $T cannot be applied to the term $t : $U.\n")
    incorrect_type(t,T,U) = error("The term $t has type $T while it is expected to have type $U.\n")
    sort_expected(t,T) = error("The type of $t is $T but it is expected to be Type(i).\n")
    unknown_reference(ref) = error("Reference $ref was not found in the current environment.\n")
    already_exists(id) = error("$id already exists.\n")
end



# PRINTING



toString(::Set) = "Set"
toString(::Prop) = "Prop"
toString(x::Type) = (u = x.u; "Type($u)")
toString(x::Variable) = (id = x.ident; "$id")
toString(::DontCare) = "_"
function toString(f::Lambda)
    x = f.binder
    T = f.domain
    u = f.body
    xs = toString(x)
    Ts = toString(T)
    us = toString(u)
    if u isa Lambda
        return "\u03BB("*xs*":"*Ts*")"*us[3:end]
    end
    return "\u03BB("*xs*":"*Ts*")."*us
end
function toString(p::Product)
    x = p.binder
    T = p.domain
    U = p.codomain
    xs = toString(x)
    Ts = toString(T)
    Us = toString(U)

    if x isa DontCare
        return T isa Product ? "("*Ts*") -> "*Us : Ts*" -> "*Us
    end
    if U isa Product && U.binder isa Variable
        return "\u220F("*xs*":"*Ts*")"*Us[4:end]
    end
    return "\u220F("*xs*":"*Ts*")."*Us
end
function toString(x::Application)
    h = x.head
    a = x.argument
    hs = toString(h)
    as = toString(a)
    if a isa Application
        as = "("*as*")"
    end
    return hs*" "*as
end
toString(::EmptyContext) = ""
toString(G::Assumption) = toString(G.rest)*toString(G.var)*" : "*toString(G.type)*"\n"
toString(G::Definition) = toString(G.rest)*toString(G.var)*" := "*toString(G.body)*" : "*toString(G.type)*"\n"

Base.show(io::IO,x::Union{Term,Context}) = print(io,toString(x))




end
