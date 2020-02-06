
struct StructuredBulkMesh{D,T}
  origin::Point{D,T}
  sizes::VectorValue{D,T}
  partition::NTuple{D,Int}
end

num_dims(::StructuredBulkMesh{D}) where D = D

function num_cells(m::StructuredBulkMesh{D}) where D
  n = 1
  for d in 1:D
    n *= m.partition[d]
  end
  n
end

function get_cell(m::StructuredBulkMesh{D},i::Integer) where D
  n_coords = int_coordinates(m,i)
  x_min = m.origin.data .+ m.sizes.data .* (n_coords.-1) ./ m.partition
  x_max = m.origin.data .+ m.sizes.data .* n_coords ./ m.partition
  HexaCell(Point(x_min),Point(x_max))
end

function find_container(m::StructuredBulkMesh{D},p::Point{D}) where D
  pn = Int.(floor.( (p.data .- m.origin.data) .* m.partition ./ m.sizes.data ))
  pn = pn .+ 1
  pn = max.(pn,1)
  pn = min.(pn,m.partition)
  get_cell_id(m,pn)
end

function int_coordinates(m::StructuredBulkMesh{D},n::Integer) where D
  n_d = mutable(VectorValue{D,Int})
  p_d = 1
  p = m.partition
  for d in 1:D
    n_d[d] = ( (n-1) ÷ p_d ) % p[d] + 1
    p_d *= p[d]
  end
  n_d.data
end

function get_cell_id(m::StructuredBulkMesh{D},n::NTuple{D,Int}) where D
  gid = 0
  p_d = 1
  for d in 1:D
    gid += (n[d]-1)*p_d
    p_d *= m.partition[d]
  end
  gid + 1
end

function cells_around(m::StructuredBulkMesh{D},bb::BoundingBox{D}) where {D}
  min_id = find_container(m,bb.pmin)
  min_int_coord = int_coordinates(m,min_id)
  min_int_coord = min_int_coord .- 1
  min_int_coord = max.(min_int_coord,1)

  max_id = find_container(m,bb.pmax)
  max_int_coord = int_coordinates(m,max_id)
  max_int_coord = max_int_coord .+ 1
  max_int_coord = min.(max_int_coord,m.partition)

  A=UnitRange.(min_int_coord,max_int_coord)
  list = Vector{Int}([])
  for i in CartesianIndices(A)
    push!(list,get_cell_id(m,i.I))
  end
  list
end

function compute_cell_to_stl_nfaces(m::StructuredBulkMesh{D},stl::ConformingSTL{D}) where D
  cell_to_stl_nfaces = TableOfVectors{Int}( [ Vector{Int}([]) for i in 1:num_cells(m) ] )
  for k in 1:num_cells(m)
    hex = get_cell(m,k)
    for stl_nface in 1:num_dfaces(stl)
      if have_intersection(hex,stl,stl_nface)
        push_to_list!(cell_to_stl_nfaces, k, stl_nface )
      end
    end
  end
  cell_to_stl_nfaces
end

function optimized_compute_cell_to_stl_nfaces(m::StructuredBulkMesh{D},stl::ConformingSTL{D}) where D
  cell_to_stl_nfaces = TableOfVectors{Int}( [ Vector{Int}([]) for i in 1:num_cells(m) ] )
  for stl_nface in 1:num_dfaces(stl)
    bb = BoundingBox(stl,stl_nface)
    for k in cells_around(m,bb)
      hex = get_cell(m,k)
      if have_intersection(hex,stl,stl_nface)
        push_to_list!(cell_to_stl_nfaces, k, stl_nface )
      end
    end
  end
  cell_to_stl_nfaces
end
