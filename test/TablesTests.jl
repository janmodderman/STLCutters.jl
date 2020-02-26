module TablesTests

using STLCutter
using Test

data = [ 1, 2, 3, 4, 7 ]
rows = [ 2, 4, 1, 3, 2 ]
n = 5

t1 = Table(data,rows,n)

@test t1[1,1] == 3
@test t1[2,1] == 1
@test t1[2,2] == 7
@test length(t1) == n
@test length(t1,1) == 1
@test length(t1,2) == 2
@test length(t1,5) == 0

data = [ 3, 1, 7, 4, 2 ]
ptrs = [ 1, 2, 4, 5, 6, 6 ]

t2 = Table(data,ptrs)

@test t2[1,1] == 3
@test t2[2,1] == 1
@test t2[2,2] == 7
@test length(t2) == n
@test length(t2,1) == 1
@test length(t2,2) == 2
@test length(t2,5) == 0

@test t1 == t2

data = [ [3], [1,7], [4], [2], Int[] ]

t3 = Table(data)

@test t1 == t2 == t3

t = t1

push!(t,[1,2,3])
@test length(t) == n+1
@test length(t,n+1) == 3

@test isactive(t,2)

remove!(t,2)
@test !isactive(t,2)

compact!(t)
@test length(t) == n
@test length(t,2) == 1
@test t[2,1] == 4





#vectors = [[1,3],[3,4,5],[2,3,1],[1,]]
#
#table = TableOfVectors(vectors)
#
#faces_to_vertices = TableOfVectors(vectors)
#nfaces = length(faces_to_vertices)
#cache = table_cache(faces_to_vertices)
#for face in 1:nfaces
#  vertices = getlist!(cache,faces_to_vertices,face)
#  @test vertices == vectors[face]
#end
#@test nfaces == length(vectors)
#
#t = TableOfVectors(Int,5,0)
#
#@test length(t) == 5
#@test length(getlist(t,1)) == 0
#
#t = TableOfVectors(Int,5,2)
#
#@test getlist(t,1) == [0,0]


end # module
