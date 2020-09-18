
function vertex_refinement(
  cell_nodes,
  node_to_coordinates::Vector{<:Point},
  p::Polytope,
  point::Point{D}) where D

  d = farthest_axis_from_boundary(cell_nodes,node_to_coordinates,point)
  case = compute_case(cell_nodes,node_to_coordinates,p,d)
  new_cells = compute_new_cells(cell_nodes,node_to_coordinates,p,case)
  new_vertices = compute_new_vertices(cell_nodes,node_to_coordinates,p,point,d,case)
  new_cells, new_vertices
end

function edge_refinement(
  K,
  X::Vector{<:Point},
  p::Polytope,
  e::Segment,
  directions)

  plane = compute_plane_from_edge(K,X,p,e,directions)
  case = compute_case(K,X,p,plane,directions)
  Tnew = compute_new_cells(K,X,p,case)
  Xnew = compute_new_vertices!(Tnew,K,X,p,plane,case)
  delete_empty_cells!(Tnew,p)
  Tnew,Xnew
end

function facet_refinement(
  K,
  X::Vector{<:Point},
  p::Polytope,
  facets::Vector{<:Integer},
  f)

  levelsets = [ CellMeshes.Plane(center(f[facet]),normal(f[facet])) for facet in facets ]
  mesh = CellMeshes.CellMesh(X,K,p)
  CellMeshes.compute_cell_mesh!(mesh,levelsets)

  Xnew = CellMeshes.get_vertex_coordinates(mesh)
  Tnew = CellMeshes.get_cell_to_vertices(mesh)
  cell_to_io = CellMeshes.get_cell_to_inout(mesh)

  update_connectivities!(Tnew,K,X,p)
  update_vertex_coordinates!(Xnew,p)

  Tnew,Xnew,cell_to_io
end
## Helpers

function compute_case(K,X,p::Polytope,d::Integer)
  @assert is_n_cube(p)
  case = 0
  for node in 1:num_vertices(p)
    if (node-1) & (1<<(d-1)) ≠ 0
      case |= (1<<(node-1))
    end
  end
  case + 1
end


function update_connectivities!(Tnew,K,X::Vector{<:Point},p::Polytope)
  for (i,Knew) in enumerate(Tnew), (j,node) in enumerate(Knew)
    if node ≤ num_vertices(p)
      Tnew[i,j] = K[node]
    else
      Tnew[i,j] = node - num_vertices(p) + length(X)
    end
  end
  Tnew
end

function update_vertex_coordinates!(Xnew::Vector{<:Point},p::Polytope)
  for _ in 1:num_vertices(p)
    popfirst!(Xnew)
  end
  Xnew
end

function project_node(K,X::Vector{<:Point},p::Polytope,node::Integer,ref_ds::Tuple)
  @assert is_n_cube(p)
  n = node
  for d in ref_ds
    n = ( (n-1) & ~(1<<(d-1)) ) + 1
  end
  n
end

function _get_direction(v::VectorValue)
  @assert norm(v) == 1
  @assert maximum(abs(v)) == 1
  findfirst( i -> abs(i) == 1, Tuple(v) )
end

function _reference_facet(K,X,p,v)
  @assert is_n_cube(p)
  d = _get_direction(v)
  for facet in 1:num_facets(p)
    facet_nodes = get_face_vertices(p,num_dims(p)-1)[facet]
    pd = X[K[facet_nodes[1]]][d]
    next_facet = false
    for node in facet_nodes
      if X[K[node]][d] ≠ pd
        next_facet = true
        break
      end
    end
    if !next_facet
      return facet
    end
  end
  @assert false
end

function _get_direction(K,X,p,v)
  facet0 = _reference_facet(K,X,p,v)
  _get_direction(get_facet_normals(p)[facet0])
end

function reference_directions(K,X,p::Polytope,vs::NTuple{N}) where N
  ntuple( i -> _get_direction(K,X,p,vs[i]), Val{N}() )
end

function compute_case(K,X,p,plane,vs)
  case = 0
  ref_ds = reference_directions(K,X,p,vs)
  for node in 1:num_vertices(p)
    n = project_node(K,X,p,node,ref_ds)
    point = X[K[n]]
    dist = signed_distance(point,plane)
    if dist > 0
      case |= (1<<(node-1))
    end
  end
  case += 1
  @assert is_case_possible(num_dims(p),case)
  case
end

function compute_new_cells(K,X,p,case)
  cell_to_lnodes = get_connectivities_from_case(num_dims(p),case)
  Tnew = deepcopy(cell_to_lnodes)
  for (icell,cell) in enumerate(Tnew)
    for (inode,lnode) in enumerate(cell)
      if lnode > num_vertices(p)
        node = length(X) + lnode - num_vertices(p)
      else
        node = K[lnode]
      end
      Tnew[icell][inode] = node
    end
  end
  Tnew
end

function compute_new_vertices(K,X,p::Polytope,point::Point,d::Integer,case::Integer)
  v_to_cv = get_vertex_to_cell_vertices_from_case(num_dims(p),case)
  vertices = zeros(eltype(X),length(v_to_cv)-num_vertices(p))
  ivertex = 0
  for i in num_vertices(p)+1:length(v_to_cv)
    nodes = v_to_cv[i]
    @assert length(nodes) == 2    
    p1 = X[K[nodes[1]]]
    p2 = X[K[nodes[2]]]

    v = i - num_vertices(p)
    vertex = Base.setindex(p1,point[d],d)
    vertices[v] = vertex
  end
  vertices
end

function compute_new_vertices!(T,K,X,p,plane,case)
  v_to_cv = get_vertex_to_cell_vertices_from_case(num_dims(p),case)
  vertices = eltype(X)[]
  ivertex = 0
  for i in num_vertices(p)+1:length(v_to_cv)
    nodes = v_to_cv[i]
    @assert length(nodes) == 2    
    p1 = X[K[nodes[1]]]
    p2 = X[K[nodes[2]]]
    d1 = signed_distance(p1,plane)
    d2 = signed_distance(p2,plane)

    if abs(d1) < TOL || abs(d2) < TOL
      if abs(d1) < abs(d2)
        new_node = K[nodes[1]]
      else
        new_node = K[nodes[2]]
      end
      old_node = length(X)+ivertex+1
      update_connectivities!(T,old_node=>new_node)
    else
      α = abs(d1) / (abs(d1)+abs(d2))
      vertex = p1 + (p2-p1)*α
      push!(vertices,vertex)
      ivertex += 1
    end
  end
  vertices
end

function update_connectivities!(T,node_to_node::Pair)
  old_node,new_node = node_to_node
  for (icell,cell) in enumerate(T), (inode,node) in enumerate(cell)
    if node == old_node
      T[icell][inode] = new_node
    elseif node > old_node
      T[icell][inode] -= 1
    end
  end
end

function delete_empty_cells!(T,p)
  icell = 1
  while icell ≤ length(T)
    cell = T[icell]
    if is_cell_empty(cell,p)
      deleteat!(T,icell)
    else
      icell += 1
    end
  end
end

function is_face_empty(K,p::Polytope,face::Integer)
  num_facets = 0
  d = get_facedims(p)[face]
  dface = face - get_dimrange(p,d)[1] + 1
  nfaces = get_faces(p,d,d-1)[dface]
  for nface in nfaces
    if d-1 == 1
      edge = nface
      if !is_edge_empty(K,p,edge)
        num_facets += 1
      end
    else
      if !is_face_empty(K,p,get_dimrange(p,d-1)[nface])
        num_facets += 1
      end
    end
  end
  num_facets < d+1
end

function is_edge_empty(K,p,edge)
  nodes = get_face_vertices(p,1)[edge]
  K[nodes[1]] == K[nodes[2]]
end

function is_cell_empty(K,p)
  face = num_faces(p)
  is_face_empty(K,p,face)
end

function compute_new_cells(
  cell_nodes::Vector{<:Integer},
  node_to_coordinates::Vector{<:Point},
  reffe::ReferenceFE)

  grid, gface_to_rface = compute_linear_grid_and_facemap(reffe)
  num_nodes_per_cell = length(cell_nodes)
  num_nodes = length(node_to_coordinates)
  new_cells = Vector{Int}[]
  for lcell in 1:num_cells(grid)
    new_cell = fill(UNSET,num_nodes_per_cell)
    for lnode in 1:num_nodes_per_cell
      gnode = get_cell_nodes(grid)[lcell][lnode] 
      face = gface_to_rface[gnode]
      rnode = get_face_own_nodes(reffe)[face][1]
      if rnode ≤ num_nodes_per_cell
        n = cell_nodes[rnode]
      else
        n = rnode - num_nodes_per_cell + num_nodes
      end
      new_cell[lnode] = n
    end
    push!(new_cells,new_cell)
  end
  new_cells
end

function compute_new_vertices(
  cell_nodes::Vector{<:Integer},
  node_to_coordinates::Vector{<:Point},
  reffe::ReferenceFE,
  point::Point{D}) where D

  p = get_polytope(reffe)
  new_node_to_coordinates = Vector{typeof(point)}(undef,num_nodes(reffe)-num_vertices(p))
  for face in num_vertices(p)+1:num_faces(p)
    if length(get_face_own_nodes(reffe)[face]) > 0
      node = get_face_own_nodes(reffe)[face][1]
      vertex = compute_vertex_coordinates(cell_nodes,node_to_coordinates,p,face,point)
      new_node_to_coordinates[node-num_vertices(p)] = vertex
    end
  end
  new_node_to_coordinates
end


function compute_vertex_coordinates(
  cell_nodes,
  node_to_coordinates,
  p::Polytope{D},
  iface::Integer,
  point::Point{D}) where D

  nface = p.dface.nfaces[iface]
  dim = p.dface.dims[iface]
  node = cell_nodes[ get_faces(p)[iface][1] ]
  anchor = node_to_coordinates[ node ]
  extrusion = nface.extrusion
  vertex = anchor
  for d in 1:D
    if extrusion[d] == HEX_AXIS
      v = point[d]
      vertex = Base.setindex(vertex,v,d)
    end
  end
  vertex
end

function compute_linear_grid_and_facemap(reffe::LagrangianRefFE)
  grid = compute_linear_grid(reffe)
  desc = get_cartesian_descriptor(grid)
  model = CartesianDiscreteModel(desc)
  labels = get_face_labeling(model)
  grid_face_to_reffe_face = get_face_entity(labels)
  grid,grid_face_to_reffe_face
end

function compute_facemap(grid::CartesianGrid)
  desc = get_cartesian_descriptor(grid)
  model = CartesianDiscreteModel(desc)
  labels = get_face_labeling(model)
  grid_face_to_reffe_face = get_face_entity(labels)
  grid_face_to_reffe_face
end


Base.abs(a::VectorValue) = VectorValue( abs.(Tuple(a)) )

function get_default_directions(E,STL_edges::Vector{<:Segment{D}}) where D
  acc_v = 0
  for e in E
    edge = STL_edges[e]
    v = edge[2] - edge[1]
    acc_v += abs(v)
  end
  if D == 2
    ()
  elseif D == 3
    _,d = findmin(acc_v.data)
    v = zero( VectorValue{D,Int} )
    v = Base.setindex(v,1,d)
    (v,)
  end
end

function compute_plane_from_edge(K,X,p,e::Segment,default_directions)
  v = e[2] - e[1]
  n = orthogonal(v,default_directions...)
  if norm(n) < TOL
    v_ϵ = perturbation(K,X,p,e)
    v += v_ϵ
    n = orthogonal(v,default_directions...)
    @assert norm(n) > TOL
  end
  n /= norm(n)
  o = center(e)
  (o,n)
end

function perturbation(K,T::Vector{<:Point},p::Polytope,e::Segment)
  point = nothing
  for facet in 1:num_facets(p)
    if have_intersection(K,T,p,facet,e)
      point = intersection_point(K,T,p,facet,e)
      break
    end
  end
  @assert point !== nothing
  min_dist = Inf
  closest_facet = UNSET
  for facet in 1:num_facets(p)
    if !have_intersection(K,T,p,facet,e)
      dist = distance(K,T,p,facet,p)
      if dist < min_dist
        min_dist = dist
        closest_facet = facet
      end
    end
  end
  normal(K,T,p,closest_facet)
end

function signed_distance(point::Point,plane::Tuple{VectorValue,VectorValue})
  o,n = plane
  (point-o)⋅n
end
