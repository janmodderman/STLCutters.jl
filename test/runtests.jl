module STLCutterTests

using Test

@testset "MutableVectorValues" begin include("MutableVectorValuesTests.jl") end

@testset "VectorValues" begin include("VectorValuesTests.jl") end

@testset "Points" begin include("PointsTests.jl") end

@testset "SegmentsTests" begin include("SegmentsTests.jl") end

@testset "TrianglesTests" begin include("TrianglesTests.jl") end

@testset "TetrahedronsTests" begin include("TetrahedronsTests.jl") end

@testset "BoundingBoxesTests" begin include("BoundingBoxesTests.jl") end

@testset "TablesTests" begin include("TablesTests.jl") end

@testset "STLs" begin include("STLsTests.jl") end

@testset "ConformingSTLs" begin include("ConformingSTLsTests.jl") end

@testset "BulkMeshesTests" begin include("BulkMeshesTests.jl") end

end # module
