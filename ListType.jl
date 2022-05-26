module ListType
### List ###

using OptionType

export List, nil, cons, isnil, list_rec
export gethead, gettail, append, lmap, ljoin, lpush, lpop, lpeek, lpopn, lpeekn

List{T} = Vector{T}

nil(::Type{T}) where T = T[]
nil() = Any[]
cons(h,t) = [h,t...]
isnil(l::List) = isempty(l)

function list_rec(pnil,pcons::Function,x::Vector) 
    function F(l)
        isnil(l) ? pnil : pcons(l[1],l[2:end],F(l[2:end]))
    end
    return F(x)
end

function gethead(l::List{A})::Option{A} where A 
    list_rec(none,(h,t,r)->h,l)
end
function gettail(l::List{A})::List{A} where A
    list_rec(nil(A),(h,t,r)->t,l)
end
function append(l1::List{A},l2::List{A})::List{A} where A
    list_rec(l2,(h,t,r)->cons(h,r),l1)
end
function lmap(f::Function,l::List{A})::List where A
    list_rec(nil(),(h,t,r)->cons(f(h),r),l)
end
function ljoin(ll::List{List{A}})::List{A} where A
    list_rec(nil(A),(h,t,r)->append(h,r),ll)
end
function lpush(l::List{A},x::A)::List{A} where A
    list_rec(cons(x,nil(A)),(h,t,r)->cons(h,r),l)
end
function lpop(l::List{A})::List{A} where A
    list_rec(nil(A),(h,t,r)->isnil(t) ? r : cons(h,r),l)
end
function lpopn(l::List{A},n::Int)::List{A} where A
    n <= 0 ? l : lpopn(lpop(l),n-1)
end
function lpeek(l::List{A})::Option{A} where A
    list_rec(none,(h,t,r)->isnil(t) ? h : r,l)
end
function lpeekn(l::List{A},n::Int)::Option{A} where A
    lpeek(lpopn(l,n))
end


# end of module
end
