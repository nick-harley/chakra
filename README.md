# Multiple Viewpoint Representation

- Options

  - Option{T}
  - some{T}:
  - none{T}:
  - omap{T}: (A->B) -> Option{A} -> Option{B}
  - ojoin{T}: Option{Option{T}} -> Option{T}
  - oret{T}: T -> Option{T}
  - obind{T} : Option{A} -> (A->Option{B}) -> Option{B} = x,f -> (omap f . join) x

- Sequences
  
  - Sequence
  
  - sempt : Sequence
  - scons : Obj -> Sequence -> Sequence
  - shead : Sequence -> Option{Obj}
  - stail : Sequence -> Sequence #should this be partial???

- Viewpoints
  
  - Viewpoint{T}
  
  - Atomic{T} <: Type{T} -> Symbol -> Viewpoint{T}
  - Linked{T1,T2} <: Viewpoint{T1} -> Viewpoint{T2} -> Viewpoint{T1xT2}
  - Derived{T1,T2} <: Viewpoint{T1} -> (T1->T2) -> Viewpoint{T2}
  - Delayed{T} <: Viewpoint{T} -> Int -> Viewpoint{T}
  - Threaded{T} <: Viewpoint{T} -> Viewpoint{Bool} -> Viewpoint{T}
    
  - vapply{T} : Viewpoint{T} -> Sequence -> T
  - vtype{T} : Viewpoint{T} -> Type{T}
  - vmap{T} : Viewpoint{T} -> Sequence -> List{T}
  - delayseq{T} : Sequence -> Option{Sequence}

- Context Models
  
  - Model{T} 
  
  - mempt{T} : Model{T}
  - madd{T} : Vector{T} -> Model{T} -> Model{T}
  - 
