#
function read_stl(filename::String)
  F = _file_format(filename)
  mesh = load(File(F,filename))
  vertex_to_coordinates = MeshIO.decompose(MeshIO.Point3,mesh)
  facet_to_vertices = MeshIO.decompose(MeshIO.TriangleFace,mesh)
  vertex_to_normals = MeshIO.decompose_normals(mesh)
  vertex_to_coordinates = Vector{Point{3,Float64}}( vertex_to_coordinates )
  facet_to_vertices = Table( Vector{Vector{Int}}( facet_to_vertices ) )
  vertex_to_normals = Vector{VectorValue{3,Float64}}( vertex_to_normals )
  facet_to_normals = vertex_to_normals[1:3:end]
  vertex_to_coordinates,facet_to_vertices,facet_to_normals
end

function _file_format(filename)
  ext =  lowercase(last(splitext(filename)))
  stl,obj = ".stl",".obj"
  ext == stl && _is_ascii(filename) && return format"STL_ASCII"
  ext == stl && _is_binary(filename) && return format"STL_BINARY"
  ext == obj && return format"OBJ"
  msg = "Invalid file format: $filename"
  @unreachable msg
end

function _get_encoding(filename)
  cmd = `file --mime-encoding $filename`
  read(cmd,String)
end

_is_binary(filename) = contains(_get_encoding(filename),"binary")

_is_ascii(filename) = contains(_get_encoding(filename),"ascii")


function Base.convert(::Type{Point{D,T}},x::MeshIO.Point{D}) where {D,T} 
  Point{D,T}(x.data)
end

function Base.convert(::Type{VectorValue{D,T}},x::MeshIO.Normal{D})  where {D,T}
  VectorValue{D,T}(x.data)
end

function Base.convert(::Type{Vector{T}},x::MeshIO.TriangleFace) where T
  convert.(T,collect(x))
end

function compute_stl_model(
  cell_to_vertices::Table,
  vertex_to_coordinates::Vector{<:Point{D}}) where D

  p = Polytope( tfill(TET_AXIS,Val{D-1}()) )
  compute_model(cell_to_vertices,vertex_to_coordinates,p)
end

function compute_model(
  cell_to_vertices::Table,
  vertex_to_coordinates::Vector{<:Point},
  p::Polytope)

  grid = compute_grid(cell_to_vertices,vertex_to_coordinates,p)
  UnstructuredDiscreteModel(grid)
end

function compute_grid(
  cell_to_nodes::AbstractArray,
  node_to_coordinates::Vector{<:Point},
  p::Polytope)

  T = Table(cell_to_nodes)
  X = node_to_coordinates
  reffes = [LagrangianRefFE(p)]
  cell_types = fill(1,length(T))
  UnstructuredGrid(X,T,reffes,cell_types)
end

function get_dface(stl::DiscreteModel,iface::Integer,::Val{d}) where d
  @notimplementedif length( get_polytopes(stl) ) ≠ 1 
  @notimplementedif !is_simplex( get_polytopes(stl)[1] )
  0 < iface ≤ num_faces(stl,d) || 
    throw(AssertionError(
      "get_dface() :: access at $d-face $iface of $(num_faces(stl,d))"))
  stl_topology = get_grid_topology(stl)
  face_vertices = get_faces(stl_topology,d,0)[iface]
  X = get_vertex_coordinates(stl_topology)
  v = ntuple( i -> X[face_vertices[i]], Val{d+1}() )
  simplex_face(v)
end 

function get_vertex(stl::DiscreteModel,vertex::Integer) 
  get_vertex_coordinates(get_grid_topology(stl))[vertex]
end

function get_edge(stl::DiscreteModel,edge::Integer)
  get_dface(stl,edge,Val{1}())
end

function get_facet(stl::DiscreteModel{Dc},facet::Integer) where Dc
  get_dface(stl,facet,Val{Dc-1}())
end

function get_cell(stl::DiscreteModel{Dc},cell::Integer) where Dc
  get_dface(stl,cell,Val{Dc}())
end

function merge_and_collapse(stl::DiscreteModel;atol=10*eps(Float32,stl))
  stl = merge_nodes(stl;atol)
  collapse_small_facets!(stl;atol)
  merge_nodes(stl;atol)
end

function collapse_small_facets!(stl::DiscreteModel;atol)
  D = num_dims(stl)
  stl_topo = get_grid_topology(stl)
  for f in 1:num_cells(stl)
    for v in get_faces(stl_topo,D,0)[f]
      vertex = get_vertex_coordinates(stl_topo)[v]
      for e in get_faces(stl_topo,D,D-1)[f]
        v ∉ get_faces(stl_topo,D-1,0)[e] || continue
        edge = get_facet(stl,e)
        if distance(vertex,edge) < atol
          _vertex = projection(vertex,edge)
          get_vertex_coordinates(stl_topo)[v] = _vertex
        end
      end
    end
  end
  stl
end

function merge_nodes(stl::DiscreteModel;atol=10*eps(Float32,stl))
  X,T = delete_repeated_vertices(get_grid(stl);atol)
  compute_stl_model(T,X)
end

function delete_repeated_vertices(stl::Grid;atol)
  group_to_vertices =  _group_vertices(stl;atol=atol*10)
  vertices_map = collect(1:num_nodes(stl))
  for _vertices in group_to_vertices
    for i in 1:length(_vertices), j in i+1:length(_vertices)
      vi = get_node_coordinates(stl)[_vertices[i]]
      vj = get_node_coordinates(stl)[_vertices[j]]
      if vertices_map[_vertices[i]] == _vertices[i] && 
         vertices_map[_vertices[j]] == _vertices[j]

        if distance(vi,vj) < atol
          vertices_map[_vertices[j]] = vertices_map[_vertices[i]]
        end
      end
    end
  end
  u = unique(vertices_map)
  m = vertices_map .== 1:length(vertices_map)
  m = cumsum(m) .* m
  vertices_map = m[vertices_map]
  X = get_node_coordinates(stl)[u]
  T = get_cell_node_ids(stl)
  T = map( i -> vertices_map[i], T )
  filter!(f->length(f)==_num_uniques(f),T)
  T = Table(T)
  X,T
end

function _num_uniques(a::AbstractArray)
  c = 0
  for i in 1:length(a)
    if a[i] ∉ view(a,1:i-1)
      c += 1
    end
  end
  c
end

function _group_vertices(stl::Grid{Dc,D};atol) where {Dc,D}
  min_length = _compute_min_length(stl;atol)
  num_digits = -Int(floor(log10(min_length)))
  pmin, pmax = get_bounding_box(stl)
  cells = NTuple{D,Int}[]
  vertices = Int[]
  m = CartesianIndices( tfill(2,Val{D}()) )
  for (iv,v) in enumerate(get_node_coordinates(stl))
    p = v-pmin
    for i in m
      f = d -> i.I[d] == 1 ? floor(p[d],digits=num_digits) : ceil(p[d],digits=num_digits)
      c = ntuple( f, Val{D}() )
      c = Int.(round.(exp10(num_digits).*c)).+1
      push!(cells,c)
      push!(vertices,iv)
    end
  end
  u = unique(cells)
  dict = Dict( zip(u,1:length(u)) )
  cells = map( i -> dict[i], cells )
  cell_to_vertices = [ Int[] for _ in 1:maximum(cells) ]
  for (cell,vertex) in zip(cells,vertices)
    push!(cell_to_vertices[cell],vertex)
  end
  cell_to_vertices
end

function get_bounding_box(mesh::Grid)
  pmin = get_node_coordinates(mesh)[1]
  pmax = get_node_coordinates(mesh)[1]
  for vertex in get_node_coordinates(mesh)
    pmin = Point(min.(Tuple(pmin),Tuple(vertex)))
    pmax = Point(max.(Tuple(pmax),Tuple(vertex)))
  end
  pmin,pmax
end

function _compute_min_length(mesh::Grid;atol)
  min_length = Inf
  for nodes in get_cell_node_ids(mesh)
    for i in 1:length(nodes), j in i+1:length(nodes)
      vi = get_node_coordinates(mesh)[nodes[i]]
      vj = get_node_coordinates(mesh)[nodes[j]]
      dist = distance(vi,vj)
      if dist < min_length && dist > atol
        min_length = dist
      end
    end
  end
  min_length
end

is_water_tight(model::DiscreteModel) = is_water_tight(get_grid_topology(model))

is_open_surface(model::DiscreteModel) = is_open_surface(get_grid_topology(model))

function is_water_tight(top::GridTopology{Dc,Dp}) where {Dc,Dp}
  Dc == Dp - 1 || error("The Geometry is not a surface")
  c_to_f = get_faces(top,Dc-1,Dc)
  maximum(length,c_to_f) == minimum(length,c_to_f) == 2
end

function is_surface(::GridTopology{Dc,Dp}) where {Dc,Dp}
  Dc == Dp-1
end

function is_open_surface(top::GridTopology{Dc}) where Dc
  is_surface(top) || return false
  l = length.( get_faces(top,Dc-1,Dc) )
  (1 ≤ maximum(l) ≤ 2) && (1 ≤ minimum(l) ≤ 2)
end

function have_intersection(
  grid::Grid,
  cell::Integer,
  m::DiscreteModel,
  face::Integer
  ;atol=nothing)

  dispatch_face(have_intersection,grid,cell,m,face,atol=atol)
end

function is_on_boundary(
  grid::Grid,
  cell::Integer,
  m::DiscreteModel,
  face::Integer
  ;atol::Real)

  dispatch_face(is_on_boundary,grid,cell,m,face,atol=atol)
end

function get_bounding_box(m::DiscreteModel,face::Integer)
  dispatch_face(get_bounding_box,m,face)
end


function dispatch_face(fun,grid::Grid,cell::Integer,args...;kargs...)
  c = get_cell(grid,cell)
  dispatch_face(fun,c,args...;kargs...)
end

function dispatch_face(fun,a,b::DiscreteModel,face::Integer;kargs...)
  topo = get_grid_topology(b)
  d = get_facedims(topo)[face]
  dface = face - get_dimrange(topo,d)[1] + 1
  dispatch_face(fun,a,b,d,dface;kargs...)
end

function dispatch_face(fun,a::DiscreteModel,face::Integer;kargs...)
  topo = get_grid_topology(a)
  d = get_facedims(topo)[face]
  dface = face - get_dimrange(topo,d)[1] + 1
  dispatch_face(fun,a,d,dface;kargs...)
end

@generated(
function dispatch_face(
  fun,a,b::DiscreteModel{D},d::Integer,df::Integer;kargs...) where D

  str = ""
  for d in 0:D
    str *= "if d == $d \n"
    str *= "  f$d =  get_dface(b,df,Val{$d}()) \n"
    str *= "  fun(a,f$d;kargs...) \n"
    str *= "else"
  end
  str *= "\n  @notimplemented \nend"
  Meta.parse(str)
end
)

@generated(
function dispatch_face(
  fun,a::DiscreteModel{D},d::Integer,df::Integer;kargs...) where D

  str = ""
  for d in 0:D
    str *= "if d == $d \n"
    str *= "  f$d =  get_dface(a,df,Val{$d}()) \n"
    str *= "  fun(f$d;kargs...) \n"
    str *= "else"
  end
  str *= "\n  @notimplemented \nend"
  Meta.parse(str)
end
)

function get_bounding_box(grid::CartesianGrid)
  desc = get_cartesian_descriptor(grid)
  pmin = desc.origin
  pmax = desc.origin + VectorValue(desc.partition .* desc.sizes)
  pmin,pmax
end

function measure(a::CartesianGrid)
  pmin,pmax = get_bounding_box(a)
  measure(pmin,pmax)
end

function measure(a::Grid)
  m = 0.0
  for i in 1:num_cells(a)
    c = get_cell(a,i)
    m += measure(c)
  end
  m
end

function measures(a::Grid,num::Integer,map)
  m = zeros(num)
  for i in 1:num_cells(a)
    c = get_cell(a,i)
    m[map[i]] += measure(c)
  end
  m
end

function measures(a::CartesianGrid{D,T,typeof(identity)}) where {D,T}
  cell_vol = prod( get_cartesian_descriptor(a).sizes )
  fill(cell_vol,num_cells(a))
end

function measures(a::Grid)
  measures(a,num_cells(a),1:num_cells(a))
end

volume(a::Grid{D,D},args...) where D = measure(a,args...)

volumes(a::Grid{D,D},args...) where D = measures(a,args...)

function surface(a::Grid{Df,Dp},args...) where {Df,Dp}
  @notimplementedif Df ≠ Dp-1
  measure(a,args...)
end

function surfaces(a::Grid{Df,Dp},args...) where {Df,Dp}
  @notimplementedif Df ≠ Dp-1
  measures(a,args...)
end

surface(a::DiscreteModel) = surface(get_grid(a))

surfaces(a::DiscreteModel,args...) = surfaces(get_grid(a),args...)

function measure(a::Grid,mask)
  m = 0.0
  p = get_polytope(only(get_reffes(a)))
  T = get_cell_node_ids(a)
  X = get_node_coordinates(a)
  c = array_cache(T)
  for i in 1:num_cells(a)
    if mask[i]
      f = get_cell!(c,T,X,p,i)
      m += measure(f)
    end
  end
  m
end
 
function measure(a::CartesianGrid{D,T,typeof(identity)},mask) where {D,T}
  cell_vol = prod( get_cartesian_descriptor(a).sizes )
  cell_vol * count(mask)
end

function measure(a::Grid,cell_to_val,val)
  measure(a,lazy_map(isequal(val),cell_to_val))
end

function measure(a::Grid)
  measure(a,lazy_map(i->true,1:num_cells(a)))
end

function get_bounding_box(stl::DiscreteModel)
  vertices = get_vertex_coordinates(get_grid_topology(stl))
  pmin = pmax = vertices[1]
  for vertex in vertices
    pmin = Point( min.( Tuple(pmin), Tuple(vertex) ) )
    pmax = Point( max.( Tuple(pmax), Tuple(vertex) ) )
  end
  pmin,pmax
end

function min_height(grid::Grid)
  min_h = Inf
  for i in 1:num_cells(grid)
    cell = get_cell(grid,i)
    h = min_height(cell)
    if h < min_h
      min_h = h
    end
  end
  min_h
end

min_height(model::DiscreteModel) = min_height(get_grid(model))

function split_disconnected_parts(stl::DiscreteModel)
  Dc = num_dims(stl)
  f_to_v = get_faces(get_grid_topology(stl),Dc,0)
  v_to_f = get_faces(get_grid_topology(stl),0,Dc)
  v_to_part = fill(UNSET,num_vertices(stl))
  f_to_part = fill(UNSET,num_cells(stl))
  num_parts = 0
  stack = Int[]
  for f in 1:num_cells(stl)
    f_to_part[f] == UNSET || continue
    num_parts += 1
    f_to_part[f] = num_parts
    empty!(stack)
    push!(stack,f)
    while !isempty(stack)
      f_curr = pop!(stack)
      for v in f_to_v[f_curr]
        v_to_part[v] = num_parts
        for f_neig in v_to_f[v]
          f_curr ≠ f_neig || continue
          f_to_part[f_neig] == UNSET || continue
          f_to_part[f_neig] = num_parts
          push!(stack,f_neig)
        end
      end
    end
  end
  @assert all(!isequal(UNSET),v_to_part)
  @assert all(!isequal(UNSET),f_to_part)
  coords = get_vertex_coordinates(get_grid_topology(stl))
  stls = typeof(stl)[]
  for part in 1:num_parts
    faces = findall(isequal(part),f_to_part)
    vertices = findall(isequal(part),v_to_part)
    v_to_part_v = fill(UNSET,length(v_to_part))
    v_to_part_v[vertices] = 1:length(vertices)
    _f_to_v = Table(map(i->v_to_part_v[i],f_to_v[faces]))
    _coords = coords[vertices]
    _stl = compute_stl_model(_f_to_v,_coords)
    push!(stls,_stl)
  end
  stls
end

function save_as_stl(stl::DiscreteModel{Dc,Dp},filename) where {Dc,Dp}
  (Dc == 2 && Dp == 3 ) || error("Geometry incompatible with STL format")
  filename *= ".stl"
  file = File{format"STL_BINARY"}(filename)
  facetype = MeshIO.GLTriangleFace
  pointtype = MeshIO.Point3f0
  normaltype = MeshIO.Vec3f0
  faces = Array{facetype}(undef, num_cells(stl))
  vertices = Array{pointtype}(undef, num_cells(stl) * 3)
  normals = Array{normaltype}(undef, num_cells(stl) * 3)
  for i in 1:num_cells(stl)
    faces[i] = facetype( (i-1)*3+1,(i-1)*3+2, (i-1)*3+3 )
    n = normal(get_cell(stl,i))
    normals[ (i-1)*3+1 ] = normaltype(Tuple(n)...)
    normals[ (i-1)*3+2 ] = normals[ (i-1)*3+1 ]
    normals[ (i-1)*3+3 ] = normals[ (i-1)*3+1 ]
    coords = get_cell_coordinates(stl)[i]
    vertices[ (i-1)*3+1 ] = pointtype(Tuple(coords[1])...)
    vertices[ (i-1)*3+2 ] = pointtype(Tuple(coords[2])...)
    vertices[ (i-1)*3+3 ] = pointtype(Tuple(coords[3])...)
  end
  mesh = MeshIO.Mesh(MeshIO.meta(vertices; normals=normals), faces)
  save(file,mesh)
  filename
end

function save_as_stl(stls::Vector{<:DiscreteModel},filename)
  files = []
  for (i,stl) in enumerate(stls)
    f = save_as_stl(stl,filename*"_$i")
    push!(files,f)
  end
  files
end
