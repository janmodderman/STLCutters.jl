struct GridapBoundingBox{D,T}
  pmin::Gridap.Point{D,T}
  pmax::Gridap.Point{D,T}
end

struct STLGeometry <: Geometry
  tree::Leaf{Tuple{T,String,B}} where {T<:STL,B<:GridapBoundingBox} 
end

function STLGeometry(stl::STL;name="stl")
  box = convert( GridapBoundingBox, BoundingBox(stl) )
  tree = Leaf( ( stl, name, box ) ) 
  STLGeometry( tree )
end

function STLGeometry(filename::String;name="stl")
  stl = STL(filename)
  STLGeometry(stl,name=name)
end

get_tree(geo::STLGeometry) = geo.tree

get_stl(geo::STLGeometry) = geo.tree.data[1]

function compatible_geometries(a::STLGeometry,b::STLGeometry)
  a,b
end

function similar_geometry(a::STLGeometry,tree::Leaf)
  STLGeometry(tree)
end
  
function STLCutters.surface(a::STLGeometry)
  stl = get_stl(a)
  surface( SurfaceMesh(stl) )
end

function Base.convert(::Type{T},a::BoundingBox) where T<:GridapBoundingBox
  pmin = convert(Gridap.Point,a.pmin)
  pmax = convert(Gridap.Point,a.pmax)
  T(pmin,pmax)
end

function Base.:*(α::Real,box::GridapBoundingBox)
  sizes = box.pmax-box.pmin
  Δ = ((α-1)/2)*sizes
  GridapBoundingBox(box.pmin-Δ,box.pmax+Δ)
end

