
struct STLGeometry <: CSG.Geometry
  tree::Leaf{Tuple{T,String,Nothing}} where T<:DiscreteModel
end

function STLGeometry(stl::DiscreteModel;name="stl")
  tree = Leaf( ( stl, name, nothing ) )
  STLGeometry( tree )
end

function STLGeometry(filename::String;name="stl")
  stlmodel = _to_stl_model(filename)
  STLGeometry(stlmodel,name=name)
end

get_tree(geo::STLGeometry) = geo.tree

get_stl(geo::STLGeometry) = geo.tree.data[1]

function compatible_geometries(a::STLGeometry,b::STLGeometry)
  a,b
end

function similar_geometry(a::STLGeometry,tree::Leaf)
  STLGeometry(tree)
end

get_bounding_box(a::STLGeometry) = get_bounding_box( get_stl(a) )

struct STLCutter <: Interfaces.Cutter
  options::Dict{Symbol,Any}
  STLCutter(;options...) = new(options)
end

function cut(cutter::STLCutter,background::DiscreteModel,geom::STLGeometry)
  data,bgf_to_ioc = _cut_stl(background,geom;cutter.options...)
  EmbeddedDiscretization(background, data..., geom), bgf_to_ioc, EmbeddedFacetDiscretization(background, data..., geom)
end

function cut(background::DiscreteModel,geom::STLGeometry)
  cutter = STLCutter()
  cut(cutter,background,geom)
end

function cut_facets(cutter::STLCutter,background::DiscreteModel,geom::STLGeometry)
  data,bgf_to_ioc = _cut_stl(background,geom;cutter.options...)
  EmbeddedDiscretization(background, data..., geom), bgf_to_ioc, EmbeddedFacetDiscretization(background, data..., geom)
end

function cut_facets(background::DiscreteModel,geom::STLGeometry)
  cutter = STLCutter()
  cut_facets(cutter,background,geom)
end

function _cut_stl(model::DiscreteModel,geom::STLGeometry;kwargs...)
  subcell_grid, subface_grid, labels = subtriangulate(model,geom;kwargs...)
  #TODO: extract subface_grid_io, f_to_io, f_to_bg

  inout_dict = Dict{Int8,Int8}(
    FACE_IN => IN, FACE_OUT => OUT, FACE_CUT => CUT, UNSET => OUT )

  cell_to_io = [ replace( labels.cell_to_io, inout_dict... ) ]
  cell_to_bgcell = labels.cell_to_bgcell
  cell_to_points = get_cell_node_ids( subcell_grid )
  point_to_coords = get_node_coordinates( subcell_grid )
  point_to_rcoords = send_to_ref_space(model,cell_to_bgcell,subcell_grid)
  data = cell_to_points,cell_to_bgcell,point_to_coords,point_to_rcoords
  subcells = SubCellData(data...)

  face_to_bgcell = labels.face_to_bgcell
  face_to_points = get_cell_node_ids( subface_grid )
  point_to_coords = get_node_coordinates( subface_grid )
  point_to_rcoords = send_to_ref_space(model,face_to_bgcell,subface_grid)
  face_to_normal = _normals(geom,labels.face_to_stlface)
  data = face_to_points,face_to_normal,face_to_bgcell,point_to_coords,point_to_rcoords
  subfacets = SubFacetData(data...)

  # bface_to_bgcell = labels.face_to_bgcell
  # bface_to_points = get_cell_node_ids( subface_grid_io )
  # point_to_coords = get_node_coordinates( subface_grid io)
  # point_to_rcoords = send_to_ref_space(model,f_to_bgcell,subface_grid)
  # # bface_to_normal = _normals(geom,labels.face_to_stlface) # get normals from bgfacets
  # data = face_to_points,face_to_normal,face_to_bgcell,point_to_coords,point_to_rcoords
  # bsubfacets = SubFacetData(data...)

  # struct EmbeddedFacetDiscretization{Dc,Dp,T} <: GridapType
  #   bgmodel
  #   ls_to_facet_to_inoutcut -> [bgface_to_ioc]
  #   subfacets -> bsubfacets
  #   ls_to_subfacet_to_inout -> [ f_to_io ]
  #   oid_to_ls -> oid_to_ls
  #   geo -> geom
  # end


  face_to_io = [ fill(Int8(INTERFACE),num_cells(subface_grid)) ]

  bgface_to_ioc = replace( labels.bgface_to_ioc, inout_dict... )
  bgcell_to_ioc = [ replace( labels.bgcell_to_ioc, inout_dict... ) ]

  oid_to_ls = Dict{UInt,Int}( objectid( get_stl(geom) ) => 1  )
  (bgcell_to_ioc,subcells,cell_to_io,subfacets,face_to_io,oid_to_ls),bgface_to_ioc
  #, EmbeddedFacetDiscretization data
end

function send_to_ref_space(
  model::DiscreteModel,
  cell_to_bgcell::Vector,
  subgrid::Grid)

  send_to_ref_space(get_grid(model),cell_to_bgcell,subgrid)
end

function send_to_ref_space(grid::Grid,cell_to_bgcell::Vector,subgrid::Grid)
  bgcell_map = get_cell_map(grid)
  bgcell_invmap = lazy_map(inverse_map,bgcell_map)
  cell_invmap = lazy_map(Reindex(bgcell_invmap),cell_to_bgcell)
  cell_nodes = get_cell_node_ids(subgrid)
  node_coords = get_node_coordinates(subgrid)
  node_cell = _first_inverse_index_map(cell_nodes,num_nodes(subgrid))
  node_invmap = lazy_map(Reindex(cell_invmap),node_cell)
  node_rcoords = lazy_map(evaluate,node_invmap,node_coords)
  _collect(node_rcoords)
end

function _first_inverse_index_map(a_to_b,nb)
  na = length(a_to_b)
  T = eltype(eltype(a_to_b))
  b_to_a = ones(T,nb)
  c = array_cache(a_to_b)
  for a in 1:na
    bs = getindex!(c,a_to_b,a)
    for b in bs
      b_to_a[b] = a
    end
  end
  b_to_a
end

function _normals(geom::STLGeometry,face_to_stlface)
  stl = get_stl(geom)
  cache = get_cell_cache(stl)
  N = typeof(normal(get_cell!(cache,stl,1)))
  normals = zeros(N,length(face_to_stlface))
  for (i,stlf) in enumerate( face_to_stlface )
    normals[i] = normal(get_cell!(cache,stl,stlf))
  end
  normals
end

_to_stl_model(geo::STLGeometry) = get_stl(geo)

surface(geo::STLGeometry) = surface(get_grid(get_stl(geo)))

function writevtk(geo::STLGeometry,args...;kwargs...)
  grid = get_grid(get_stl(geo))
  writevtk(grid,args...;kwargs...)
end

function check_requisites(geo::STLGeometry,bgmodel::DiscreteModel;kwargs...)
  stl = get_stl(geo)
  check_requisites(stl,bgmodel)
end

function _collect(a::LazyArray)
  c = array_cache(a)
  T = eltype(a)
  b = zeros(T,size(a))
  for i in eachindex(a)
    b[i] = getindex!(c,a,i)
  end
  b
end
