using PyCall
using LinearAlgebra

scipy_spatial = pyimport("scipy.spatial")


include("simplex_mesh.jl")

include("reference_cell.jl")

function printvector(io::IO,varname::String,range::UnitRange)
  @assert range[1] > 0
  data  = join([ "[], " for i in 1:range[1]-1 ])
  data *= join([ "$(replace( varname, '#' => "$i" )), " for i in range ] )
  vector_name = replace(varname, '#' => "D" )
  println(io,"const D_to_$(vector_name) = [ $data ]");println(io)
end

function printvector(io::IO,varname::String,range::UnitRange,t::Type)
  @assert range[1] > 0
  empty_t = "$(string(t))(undef$(join([",0" for n in 1:ndims(t)])))"
  data  = join([ "$empty_t, " for i in 1:range[1]-1 ])
  data *= join([ "$(replace( varname, '#' => "$i" )), " for i in range ] )
  vector_name = replace(varname, '#' => "D" )
  println(io,"const D_to_$(vector_name) = $(string(t))[ $data ]");println(io)
end

dir = @__DIR__

## Print table includer
filename = joinpath(dir,"LookupCutTables.jl")
main_f = open(filename,"w")

header = 
"#
#  This file includes: Look-up tables for cuts
#
#  Please do not modify it by hand:
#    code automatically generated by $(basename(@__FILE__))
#
"
println(main_f, header )

println(main_f, "const _empty_matrix = Array{Int64}(undef,0,0)" ); println(main_f)


## Print tables to cut TETn by adding a vertix on one dface ∀ d ∈ [1,n]
raw_prefix = "cut_TYPE#"

for ctype in (TetCell,HexCell)

hash_prefix = replace( raw_prefix, "TYPE" => ctype )

filename = joinpath(dir,"$( replace(hash_prefix, '#' => "" ) )_tables.jl")
f = open(filename,"w")
println(main_f, "include(\"$(basename(filename))\")" ); println(main_f); 

header = 
"#
# Cut $(uppercase(ctype)) tables 
#  Please do not modify it by hand:
#    code automatically generated by $(basename(@__FILE__))
#
"
println(f, header )

dim_range = 1:4

for num_dims in dim_range

  cell = RefCell(ctype,num_dims)

  prefix = replace( hash_prefix, '#' => num_dims )
  println(f,"## Combinations for $(uppercase(prefix))"); println(f)

  global_x = Array{Float64,2}[]
  global_nf_to_mf = NFaceToMFace[]
  global_nf_to_nF = Vector{Vector{Int}}[]
  global_c2f_orientation = Array{Int,2}[]
  cut_dface_to_case = [ zeros(Int,num_dfaces(cell,d)) for d in 1:num_dims ]
  count = 0
  for d in 1:ndims(cell)
    for i in 1:num_dfaces(cell,d)
      x = [ cell.coordinates dface_center(cell,d,i) ]
      nf_to_mf = compute_mesh( x )
      nf_to_nF = compute_face_to_initial_face(cell,nf_to_mf,d,i)
      c2f_orientation = compute_cell_to_facet_orientation(x,nf_to_mf)
      count += 1

      cut_dface_to_case[d][i] = count 
      push!( global_x, x )
      push!( global_nf_to_mf, nf_to_mf )
      push!( global_nf_to_nF, nf_to_nF )
      push!( global_c2f_orientation, c2f_orientation )
    end
  end
  print(f, "const d_to_dface_to_case_for_$prefix = " ); println(f, cut_dface_to_case ); println(f)
  print(f, "const case_to_m_n_to_mface_to_nfaces_for_$prefix = " ); println(f, global_nf_to_mf ); println(f)
  print(f, "const case_to_d_to_subdface_to_dface_for_$prefix = " ); println(f, global_nf_to_nF ); println(f)
  print(f, "const case_to_cell_lfacet_to_orientation_for_$prefix  = " ); println(f, global_c2f_orientation ); println(f)
end

println(f, "## Summary:" ); println(f)
printvector(f, "d_to_dface_to_case_for_$hash_prefix", dim_range )
printvector(f, "case_to_m_n_to_mface_to_nfaces_for_$hash_prefix", dim_range )
printvector(f, "case_to_d_to_subdface_to_dface_for_$hash_prefix", dim_range )
printvector(f, "case_to_cell_lfacet_to_orientation_for_$hash_prefix", dim_range )
close(f)
end


## Print tables to split HEXn into TETn

filename = joinpath(dir,"hex_to_tet_tables.jl")
f = open(filename,"w")
println(main_f, "include(\"$(basename(filename))\")" ); println(main_f);

header = 
"#
# Split HEX into TETs tables 
#  Please do not modify it by hand:
#    code automatically generated by $(basename(@__FILE__))
#
"
println(f, header )

T_nf_to_mf = Type 
T_nf_to_nF = Type
T_c2f_orientation = Type

dim_range = 2:4
for num_dims in dim_range 
  global T_nf_to_mf, T_nf_to_nF, T_c2f_orientation
  prefix = "hex$(num_dims)_to_tet$(num_dims)"
  cell = RefCell(HexCell,num_dims)
  println(f,"## Connectivities for $prefix"); println(f)

  x = cell.coordinates
  nf_to_mf = compute_mesh( x )
  nf_to_v = nf_to_mf[0:end-1,0]
  v_to_nF = [ dual_map( dface_to_vertices(cell,d) ) for d in 0:ndims(cell)-1 ]
  nf_to_nF = compute_face_to_initial_face(v_to_nF,nf_to_v)
  c2f_orientation = compute_cell_to_facet_orientation(x,nf_to_mf)

  print(f, "const m_n_to_mface_to_nfaces_for_$prefix = " ); println(f, nf_to_mf ); println(f);
  print(f, "const d_to_subdface_to_dface_for_$prefix = " ); println(f, nf_to_nF ); println(f);
  print(f, "const cell_lfacet_to_orientation_for_$prefix  = " ); println(f, c2f_orientation ); println(f);
  
  T_nf_to_mf = typeof( get_m_of_v_of_v(nf_to_mf) ) 
  T_nf_to_nF = typeof( nf_to_nF )
  T_c2f_orientation = typeof(c2f_orientation)
end


println(f, "## Summary:" ); println(f)
printvector(f, "m_n_to_mface_to_nfaces_for_hex#_to_tet#", dim_range, T_nf_to_mf )
printvector(f, "d_to_subdface_to_dface_for_hex#_to_tet#", dim_range, T_nf_to_nF )
printvector(f, "cell_lfacet_to_orientation_for_hex#_to_tet#", dim_range, T_c2f_orientation ) 
close(f)


filename = joinpath(dir,"reference_cell_tables.jl")
f = open(filename,"w")

println(main_f, "include(\"$(basename(filename))\")" ); println(main_f);

header = 
"#
# Reference TET & HEX cells 
#  Please do not modify it by hand:
#    code automatically generated by $(basename(@__FILE__))
#
"
println(f, header )

dim_range = 1:4
for ctype in (TetCell,HexCell)
  @assert dim_range[1] == 1 && step(dim_range) == 1
  cells = [ RefCell(ctype,d) for d in dim_range ]
  coordinates = [ cells[d].coordinates for d in dim_range ]
  df_to_vs = [ cells[d].dface_to_vertices[2:d] for d in dim_range ]
  df_to_vs = [ [ [ f[:,i] for i in 1:size(f,2) ] for f in df_to_v ] for df_to_v in df_to_vs ]
  print(f,"const D_to_reference_coordinates_for_$ctype = "); println(f,coordinates); println(f)
  print(f,"const D_to_d_to_dface_to_vertices_for_$ctype = "); println(f,df_to_vs); println(f)
end
close(f)



close(main_f)
