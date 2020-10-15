module SurfaceRefinementTests

using Test
using Gridap
using STLCutters


using STLCutters: compute_stl_model
using STLCutters: refine_stl_face
using STLCutters: compute_face_to_cells
using STLCutters: refine_surface 
using STLCutters: read_stl
using STLCutters: merge_nodes 
using STLCutters: get_bounding_box 

using STLCutters: surface
using STLCutters: surfaces


stl_vertices = [
  Point(-0.5,0.5),
  Point(0.5,0.5) ]
stl_faces = Table([[1,2]])
stl = compute_stl_model(stl_faces,stl_vertices)
origin = Point(0,0)
sizes = (1,1)
partition = (1,1)
grid = CartesianGrid(origin,sizes,partition)
T,X = refine_stl_face(grid,1,stl,3)
@test length(T) == 1

origin = Point(0,0)
sizes = (0.5,0.5)
partition = (2,2)
grid = CartesianGrid(origin,sizes,partition)
stl_vertices = [
  Point(0.0,0.5),
  Point(1.0,0.5)]
stl_faces = Table([[1,2]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_stlf]
#writevtk(get_grid(_stl),"surface",cellfields=fields)
@test surface(_stl) ≈ surface(stl)

origin = Point(0,0)
sizes = (0.1,0.1)
partition = (10,10)
grid = CartesianGrid(origin,sizes,partition)
stl_vertices = [
  Point(0.0,0.5),
  Point(0.1,0.8),
  Point(0.4,0.4),
  Point(0.7,0.7),
  Point(0.8,0.3),
  Point(1.0,0.3) ]
stl_faces = Table([[1,2],[2,3],[3,4],[4,5],[5,6]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_stlf]
#writevtk(get_grid(_stl),"surface",cellfields=fields)
@test surface(_stl) ≈ surface(stl)

stl_vertices = [
  Point(-0.5,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,-0.5,0.5) ]
stl_faces = Table([[1,2,3]])
stl = compute_stl_model(stl_faces,stl_vertices)
origin = Point(0,0,0)
sizes = (1,1,1)
partition = (1,1,1)
grid = CartesianGrid(origin,sizes,partition)
T,X = refine_stl_face(grid,1,stl,7)

origin = Point(0,0,0)
sizes = (0.25,0.25,0.25)
partition = (4,4,4)
grid = CartesianGrid(origin,sizes,partition)
stl_vertices = [
  Point(0.1,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,0.1,0.5) ]
stl_faces = Table([[1,2,3]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_f = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_f]
#writevtk(get_grid(_stl),"surface",cellfields=fields)


origin = Point(0,0,0)
sizes = (0.2,0.2,0.2)
partition = (3,3,3)
grid = CartesianGrid(origin,sizes,partition)

stl_vertices = [
  Point(0.1,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,0.1,0.5) ]
stl_faces = Table([[1,2,3]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_f = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)




stl_vertices = [
  Point(0.0,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,0.0,0.5) ]
stl_faces = Table([[1,2,3]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)

stl_vertices = [
  Point(0.0,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,0.0,0.5),
  Point(0.0,0.0,0.0) ]
stl_faces = Table([[1,2,3],[1,3,4]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)
surfs = surfaces(stl,num_cells(stl),1:num_cells(stl))
_surfs = surfaces(_stl,num_cells(stl),f_to_stlf) 
@test all( surfs .≈ _surfs )

stl_vertices = [
  Point(0.0,0.5,0.5),
  Point(0.5,0.5,0.5),
  Point(0.5,0.0,0.5),
  Point(0.1,0.1,0.0) ]
stl_faces = Table([[1,2,3],[1,3,4]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)
surfs = surfaces(stl,num_cells(stl),1:num_cells(stl))
_surfs = surfaces(_stl,num_cells(stl),f_to_stlf) 
@test all( surfs .≈ _surfs )
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_stlf]
#writevtk(get_grid(_stl),"surface",cellfields=fields)

origin = Point(0,0,0)
sizes = (1.0,1.0,1.0)
partition = (2,2,2)
grid = CartesianGrid(origin,sizes,partition)
stl_vertices = [
  Point(1.5,0.5,1.5),
  Point(0.3,0.0,0.5),
  Point(0.7,0.0,0.5) ]
stl_faces = Table([[1,2,3]])
stl = compute_stl_model(stl_faces,stl_vertices)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_stlf]
#writevtk(get_grid(_stl),"surface",cellfields=fields)
@test surface(_stl) ≈ surface(stl)
surfs = surfaces(stl,num_cells(stl),1:num_cells(stl))
_surfs = surfaces(_stl,num_cells(stl),f_to_stlf) 
@test all( surfs .≈ _surfs )



X,T,N = read_stl(joinpath(@__DIR__,"data/cube.stl"))
stl = compute_stl_model(T,X)
stl = merge_nodes(stl)
n = 10
δ = 0.2
pmin,pmax = get_bounding_box(stl)
diagonal = pmax-pmin
origin = pmin - diagonal*δ
sizes = Tuple( diagonal*(1+2δ)/n )
partion = (n,n,n)
grid = CartesianGrid(origin,sizes,partion)
_stl,f_to_bgcell,f_to_stlf = refine_surface(grid,stl)
@test surface(_stl) ≈ surface(stl)
surfs = surfaces(stl,num_cells(stl),1:num_cells(stl))
_surfs = surfaces(_stl,num_cells(stl),f_to_stlf) 
@test all( surfs .≈ _surfs )
#writevtk(grid,"bg_mesh")
#fields = ["bgcell"=>f_to_bgcell,"stlfacet"=>f_to_stlf]
#writevtk(get_grid(_stl),"surface",cellfields=fields)

end # module
