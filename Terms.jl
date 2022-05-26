module Terms

export Term, Variable, Set, Prop, Type, Lambda, Product, Application
export freeVars, isFreeIn, subst, unfold, beta, type, equiv
export Var, Pi, Fun, App, Arrow
export Init, Assume, Define, Check, Unfold, Eval



# TERMS



abstract type Term end



# SORTS



abstract type Sort <: Term end

struct Set <: Sort end

struct Prop <: Sort end

struct Type{u} <: Sort
    Type(u::Int) = u < 1 ? error("Type universe must be greater than 0.") : new{u}()
end

universe(::Set) = 0
universe(::Prop) = 0
universe(::Type{u}) where u = u



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
end



# LAMBDA



struct Lambda <: Term
    binder::Binder
    domain::Term
    body::Term
    Lambda(T::Term,u::Term) = new(dontcare,T,u)
    Lambda(x::DontCare,T::Term,u::Term) = new(x,T,u)
    Lambda(x::Variable,T::Term,u::Term) = !isFreeIn(x,u) ? new(dontcare,T,u) : new(x,T,u)
end



# APPLICATION



struct Application <: Term
    head::Term
    argument::Term
end



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
        s = type(T,G)
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        return new(x,T,G)
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
        if !equiv(T,body_type)
            Errors.incorrect_type(t,body_type,T)
        end
        return new(x,t,T,G)
    end
end

struct LocalAssumption <: Context
    var::Variable
    type::Term
    rest::Context
    function LocalAssumption(x::Variable,T::Term,G::Context)
        s = type(T,G) 
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        return new(x,T,G)
    end
    function LocalAssumption(::DontCare,T::Term,G::Context)
        s = type(T,G) 
        if !(s isa Sort)
            Errors.sort_expected(T,s)
        end
        return G
    end
end



# OPERATIONS ON CONTEXTS



Base.getindex(G::EmptyContext,x::Variable) = x
Base.getindex(G::Union{Assumption,LocalAssumption},x::Variable) = x == G.var ? x : Base.getindex(G.rest,x)
Base.getindex(G::Definition,x::Variable) = x == G.var ? G.body : Base.getindex(G.rest,x)

declares(::EmptyContext,x::Variable) = false
declares(G::Assumption,x::Variable) = x == G.var ? true : declares(G.rest,x)
declares(G::Definition,x::Variable) = x == G.var ? true : declares(G.rest,x)

assume(x::Variable,T::Term,G::Context) = Assumption(x,T,G)

define(x::Variable,t::Term,T::Term,G::Context) = Definition(x,t,T,G)
define(x::Variable,t::Term,G::Context) = define(x,t,type(t,G),G)

assumeLocal(x::Binder,T::Term,G::Context) = LocalAssumption(x,T,G)



# GET ALL VARIABLES (UNBOUND OR BOUND) IN A TERM



getVars(::EmptyContext) = Base.Set{Variable}()
getVars(G::Union{Assumption,Definition,LocalAssumption}) = Base.Set{Variable}([G.var,getVars(G.rest)...])
getVars(t::Variable) = Base.Set{Variable}([t])
getVars(t::Sort) = Base.Set{Variable}()
getVars(::DontCare) = Base.Set{Variable}()
getVars(t::Product) = union(getVars(t.binder), getVars(t.domain), getVars(t.codomain))
getVars(t::Lambda) = union(getVars(t.binder), getVars(t.domain), getVars(t.body))
getVars(t::Application) = union(getVars(t.head), getVars(t.argument))
getVars(xs::Union{Term,Context}...) = union(getVars.(xs)...)



# CREATING FRESH VARIABLES



getFreshVar(vs::Base.Set{Variable}) = begin
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



# ALPHA RENAMING OF TERMS



alphaRename(t::Lambda,x::Variable) = begin
    if x == t.binder
        return t
    end
    if x in freeVars(t.body)
        Errors.variable_capture(x,t)
    end
    return Lambda(x,t.domain,subst(x,t.binder,t.body))
end
alphaRename(t::Product,x::Variable) = begin
    if x == t.binder
        return t
    end
    if x in freeVars(t.codomain)
        Errors.variable_capture(x,t)
    end
    return Product(x,t.domain,subst(x,t.binder,t.codomain))
end

alphaRename(t::Lambda,xs::Base.Set{Variable}) = begin
    x = getFreshVar(xs)
    Lambda(x,t.domain,subst(x,t.binder,t.body))
end

alphaRename(t::Product,xs::Base.Set{Variable}) = begin
    x = getFreshVar(xs)
    return Product(x,t.domain,subst(x,t.binder,t.codomain))
end

alphaRename(t::Term,G::Context) = begin
    alphaRename(t,getVars(t,G))
end



# GET THE SET OF FREE VARIABLES IN A TERM



freeVars(t::Sort,bvs::Base.Set{Variable}) = Base.Set{Variable}()

freeVars(t::Variable,bvs::Base.Set{Variable}) = t in bvs ? Base.Set{Variable}() : Base.Set{Variable}([t])

freeVars(t::Product,bvs::Base.Set{Variable}) = begin
    bvs2 = Base.Set{Variable}([bvs...])
    if t.binder isa Variable
        bvs2 = Base.Set{Variable}([t.binder,bvs2...])
    end

    return union(freeVars(t.domain,bvs),freeVars(t.codomain,bvs2))
end

freeVars(t::Lambda,bvs::Base.Set{Variable}) = begin
    bvs2 = Base.Set{Variable}([bvs...])
    if t.binder isa Variable
        bvs2 = Base.Set{Variable}([t.binder,bvs2...])
    end
    return union(freeVars(t.domain,bvs),freeVars(t.body,bvs2))
end

freeVars(t::Application,bvs::Base.Set{Variable}) = union(freeVars(t.head,bvs),freeVars(t.argument,bvs))

freeVars(t) = freeVars(t,Base.Set{Variable}())



# TEST IF VARIABLE IS FREE IN A TERM



isFreeIn(x::Variable,t::Term) = x in freeVars(t)

isFreeIn(::DontCare,t::Term) = false



# CAPTURE AVOIDING SUBSTITUTION: SUBST



subst(m::Term,::DontCare,t::Term) = t

subst(m::Term,x::Variable,t::Sort) = t

subst(m::Term,x::Variable,t::Variable) = t == x ? m : t

subst(m::Term,x::Variable,t::Lambda) = begin
    if t.binder == x
        return Lambda(t.binder,subst(m,x,t.domain),t.body)
    end
    if t.binder in freeVars(m)
        t_alpha = alphaRename(t,getVars(t,m,x))
        return Lambda(t_alpha.binder,subst(m,x,t_alpha.domain),subst(m,x,t_alpha.body))
    end
    return Lambda(t.binder,subst(m,x,t.domain),subst(m,x,t.body))
end

subst(m::Term,x::Variable,t::Product) = begin
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



# DELTA REDUCTION: UNFOLD



unfold(x::Variable,G::Context,bvs::Base.Set{Variable}) = begin
    if x in bvs
        return x
    end

    t = G[x]
    
    if x == t
        return t
    end
    
    return unfold(t,G)
end

unfold(x::Sort,G::Context,bvs::Base.Set{Variable}) = x

unfold(t::Lambda,G::Context,bvs::Base.Set{Variable}) = begin
    if t.binder isa Variable
        bvs_ex = Base.Set{Variable}([t.binder,bvs...])
        return Lambda(t.binder,unfold(t.domain,G,bvs),unfold(t.body,G,bvs_ex))
    end

    return Lambda(t.binder,unfold(t.domain,G,bvs),unfold(t.body,G,bvs))
end

unfold(t::Product,G::Context,bvs::Base.Set{Variable}) = begin
    if t.binder isa Variable
        bvs_ex = Base.Set{Variable}([t.binder,bvs...])
        return Product(t.binder,unfold(t.domain,G,bvs),unfold(t.codomain,G,bvs_ex))
    end

    return Product(t.binder,unfold(t.domain,G,bvs),unfold(t.codomain,G,bvs))

end

unfold(t::Application,G::Context,bvs::Base.Set{Variable}) = begin
    return Application(unfold(t.head,G,bvs),unfold(t.argument,G,bvs))
end



# BETA REDUCTION OF TERMS



beta(t::Term,G::Context,bvs) = unfold(t,G,bvs)

beta(t::Term,G::Context) = beta(t,G,Base.Set{Variable}())

beta(t::Lambda,G::Context,bvs) = begin
    if t.binder isa Variable
        bvs_ex = Base.Set{Variable}([t.binder,bvs...])
        return Lambda(t.binder,beta(t.domain,G,bvs),beta(t.body,G,bvs_ex))
    end
    
    return Lambda(t.binder,beta(t.domain,G,bvs),beta(t.body,G,bvs))
    
end

beta(t::Product,G::Context,bvs) = begin
    if t.binder isa Variable
        bvs_ex = Base.Set{Variable}([t.binder,bvs...])
        return Product(t.binder,beta(t.domain,G,bvs),beta(t.codomain,G,bvs_ex))
    end

    return Product(t.binder,beta(t.domain,G,bvs),beta(t.codomain,G,bvs))

end

beta(t::Application,G::Context,bvs) = begin
    h = beta(t.head,G,bvs)
    a = beta(t.argument,G,bvs)
    h isa Lambda ? beta(subst(a,h.binder,h.body),G,bvs) : Application(h,a)
end



# EQUIVALENCE OF TERMS



Base.:(==)(f::Lambda,g::Lambda) = begin
    vs = getVars(f,g)
    v = getFreshVar(vs)
    f2 = alphaRename(f,v)
    g2 = alphaRename(g,v)
    f2.domain == g2.domain && f2.body == g2.body
end

Base.:(==)(T::Product,U::Product) = begin
    vs = getVars(T,U)
    v = getFreshVar(vs)
    T2 = alphaRename(T,v)
    U2 = alphaRename(U,v)
    T2.domain == U2.domain && T2.codomain == U2.codomain
end

Base.:(==)(t1::Application,t2::Application) = begin
    return t1.head == t2.head && t1.argument == t2.argument
end

eta_expansion(x,y) = begin
    if !(y isa Lambda)
        return x == y
    end

    if y.binder isa DontCare
        return false
    end

    return eta_expansion(Application(x,y.binder),y.body)
end

equiv(t1::Term,t2::Term,G::Context=EmptyContext()) = begin
    x = beta(t1,G)
    y = beta(t2,G)

    if x == y
        return true
    end
    
    xT = beta(type(x,G),G)
    yT = beta(type(y,G),G)

    if xT == yT && xT isa Product
        if eta_expansion(x,y)
            return true
        end
        if eta_expansion(y,x)
            return true
        end
    end

    return false
    
end

# COMPUTE TYPE OF A TERM



type(t::Sort,::Context) = begin
    return Type(universe(t)+1)
end

type(t::Variable,::EmptyContext) = begin
    Errors.unknown_reference(t)
end

type(t::Variable,G::Union{Assumption,Definition,LocalAssumption}) = begin
    return t == G.var ? G.type : type(t,G.rest)
end

type(t::Lambda,G::Context) = begin
    t2 = t
    if t.binder in getVars(G)
        t2 = alphaRename(t,G)
    end
    Gex = assumeLocal(t2.binder,t2.domain,G)
    body_type = type(t2.body,Gex)
    return Product(t2.binder,t2.domain,body_type)
end

type(t::Product,G::Context) = begin
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

type(t::Application,G::Context) = begin
    head_type = beta(type(t.head,G),G)

    arg_type = beta(type(t.argument,G),G)

    if !(head_type isa Product)
        Errors.illegal_application(t.head,head_type,t.argument,arg_type)
    end

    if head_type.domain != arg_type
        Errors.incorrect_type(t.argument,arg_type,head_type.domain)
    end

    return subst(t.argument,head_type.binder,head_type.codomain)
end



# PRINTING TERMS AND CONTEXTS



toString(::Set) = "Set"

toString(::Prop) = "Prop"

toString(x::Type{u}) where u = "Type($u)"

toString(x::Variable) = (id = x.ident; "$id")

toString(::DontCare) = "_"

toString(f::Lambda) = begin
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

toString(p::Product) = begin
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

toString(x::Application) = begin
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



# ERROR MESSAGES



module Errors
illegal_application(f,T,t,U) = error("Illegal application (Non-functional construction):\nThe expression $f of type $T cannot be applied to the term $t : $U.\n")
incorrect_type(t,T,U) = error("The term $t has type $T while it is expected to have type $U.\n")
sort_expected(t,T) = error("The type of $t is $T but it is expected to be Type(i).\n")
unknown_reference(ref) = error("Reference $ref was not found in the current environment.\n")
already_exists(id) = error("$id already exists.\n")
variable_capture(x,t) = error("Cannot alpha rename: The variable $x occurs free in $t. alphaRename($t,$x) results in variable capture.")
end



# TERM SYNTAX INTERFACE



Exp = Union{Term,Symbol,DontCare}

function prse(e::Symbol)::Union{Term,DontCare}
    if e == :_
        DontCare()
    elseif e == :Set
        Set()
    elseif e == :Prop
        Prop()
    else
        Variable(e)
    end
end

prse(e::Union{Term,DontCare})::Union{Term,DontCare} = e


Binding = Tuple{Union{Binder,Symbol},Exp}


Var(x::Symbol) = Variable(x)

Fun(x::Exp,T::Exp,u::Exp) = Lambda(prse(x),prse(T),prse(u))

Fun(arg::Binding,xs...) = length(xs) == 1 ? Fun(arg...,xs...) : Fun(arg...,Fun(xs...))

Pi(x::Exp,T::Exp,U::Exp) = Product(prse(x),prse(T),prse(U))

Pi(A::Exp,B::Exp) = Product(DontCare(),prse(A),prse(B))

Pi(arg::Binding,xs...) = length(xs) == 1 ? Pi(arg...,xs...) : Pi(arg...,Pi(xs...))

Arrow(A::Exp,xs::Exp...) = length(xs) == 0 ? A : Pi(A,Arrow(xs...))

App(t::Exp) = prse(t)

App(f::Exp,a::Exp) = Application(prse(f),prse(a))

App(f,a,xs...) = App(App(f,a),xs...)

(f::Symbol)(xs::Exp...) = App(f,xs...)

(f::Term)(xs::Exp...) = App(f,xs...) 



# CONTEXT INTERFACE



assume(x::Exp,E::Exp,G::Context) = Assumption(prse(x),prse(E),G)

define(x::Exp,t::Exp,T::Exp,G::Context) = define(prse(x),prse(t),prse(T),G)

define(x::Exp,t::Exp,G::Context) = define(prse(x),prse(t),G)

assumeLocal(x::Exp,T::Exp,G::Context) = LocalAssumption(prse(x),prse(T),G)

type(t::Exp,G::Context) = type(prse(t),G)

unfold(x::Exp,G::Context) = unfold(prse(x),G,Base.Set{Variable}())

beta(x::Exp,G::Context) = beta(prse(x),G,Base.Set{Variable}())

equiv(x::Exp,y::Exp,G::Context) = equiv(prse(x),prse(y),G)

# MACROS 

macro Init()
    esc(:(_TOP = Terms.EmptyContext()))
end

macro Assume(x,t)
    esc(:(_TOP = Terms.assume($x,$t,_TOP)))
end

macro Define(x,t)
    esc(:(_TOP = Terms.define($x,$t,_TOP)))
end

macro Define(x,t,T)
    esc(:(_TOP = Terms.define($x,$t,$T,_TOP)))
end

macro Check(x)
    esc(:(Terms.type($x,_TOP)))
end

macro Unfold(x)
    esc(:(Terms.unfold($x,_TOP)))
end

macro Eval(x)
    esc(:(Terms.beta($x,_TOP)))
end

macro Equiv(x,y)
    esc(:(Terms.equiv($x,$y,_TOP)))
end










end
