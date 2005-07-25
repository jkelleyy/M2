--- status: done
--- author(s): dan
--- notes: 

document { 
     Key => homology,
     Headline => "general homology functor",
     "Most applications of this functor are dispatched through ", TT "HH", ".
     If it is intended that ", TT "i", " be of class ", TO "ZZ", ", 
     ", TT "M", " be of class ", TT "A", ", and ", TT "N", " be of
     class ", TT "B", ", then the method for computing ", TT "HH_i(M,N)", " can be installed with 
     code of the following form.",
     PRE "     homology(ZZ, A, B) := opts -> (i,M,N) -> ...",
     SeeAlso => {"cohomology", "HH", "ScriptedFunctor"}
     }

document {
     Key => (homology,ZZ,ChainComplexMap),
     Headline => "homology of a chain complex map",
     TT "HH_i f", " -- provides the map on the ", TT "i", "-th homology module
     by a map ", TT "f", " of chain complexes.",
     PARA,
     SeeAlso => {"homology", "HH"}
     }

document { 
     Key => (homology,ChainComplexMap),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }
document { 
     Key => (homology,ZZ,ChainComplexMap),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }
document { 
     Key => (homology,Nothing,ChainComplexMap),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }

document { 
     Key => (homology,ChainComplex),
     Headline => "homology of a chain complex",
     Usage => "HH C",
     Inputs => {
	  "C" => null
	  },
     Outputs => {
	  {"the homology of ", TT "C"}
	  },
     EXAMPLE {
	  "R = QQ[x]/x^5;",
	  "C = res coker vars R",
	  "M = HH C",
	  "prune M"
	  }
     }
document { 
     Key => (homology,ZZ,ChainComplex),
     Headline => "homology of a chain complex",
     Usage => "HH_i C",
     Inputs => {
	  "i" => null,
	  "C" => null
	  },
     Outputs => {
	  {"the homology at the i-th spot of the chain complex ", TT "C", "."}
	  },
     EXAMPLE {
	  "R = ZZ/101[x,y]",
      	  "C = chainComplex(matrix{{x,y}},matrix{{x*y},{-x^2}})",
      	  "M = HH_1 C",
      	  "prune M",
	  }
     }

TEST "
S = ZZ/101[x,y,z]
M = cokernel vars S
assert ( 0 == HH_-1 res M )
assert ( M == HH_0 res M )
assert ( 0 == HH_1 res M )
assert ( 0 == HH_2 res M )
assert ( 0 == HH_3 res M )
assert ( 0 == HH_4 res M )
"
document { 
     Key => (homology,ZZ,Sequence),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }
document { 
     Key => (homology,Matrix,Matrix),
     Headline => "homology of a pair of maps",
     Usage => "M = homology(f,g)",
     Inputs => {
	  "f" => null,
	  "g" => null
	  },
     Outputs => {
	  "M" => {"computes the homology module ", TT "(kernel f)/(image g)", "."}
	  },
     "Here ", TT "g", " and ", TT "f", " should be composable maps with ", TT "g*f", "
     equal to zero.",
     PARA {
	  "In the following example, we ensure that the source of ", TT "f", " and the target of
	  ", TT "f", " are exactly the same, taking even the degrees into account, and we ensure
	  that ", TT "f", " is homogeneous."},
     EXAMPLE {
	  "R = QQ[x]/x^5;",
	  "f = map(R^1,R^1,{{x^3}}, Degree => 3)",
	  "M = homology(f,f)",
	  "prune M"
	  }
     }
document { 
     Key => (homology,Nothing,ChainComplex),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }
document { 
     Key => (homology,Nothing,Sequence),
     Headline => "",
     Usage => "",
     Inputs => {
	  },
     Outputs => {
	  },
     Consequences => {
	  },     
     "description",
     EXAMPLE {
	  },
     Caveat => {},
     SeeAlso => {}
     }
 -- doc10.m2:731:     Key => (cohomology, ZZ, Module),
 -- doc10.m2:936:     Key => (cohomology, ZZ, SumOfTwists),
 -- doc10.m2:962:     Key => (cohomology, ZZ, CoherentSheaf),
 -- doc12.m2:1032:     Key => cohomology,
 -- doc12.m2:1045:     Key => homology,
 -- doc7.m2:1419:     Key => (homology,Matrix,Matrix),
 -- doc9.m2:771:     Key => (homology,ZZ,ChainComplex),
 -- doc9.m2:1573:     Key => (cohomology,ZZ,ChainComplex),
 -- doc9.m2:1581:     Key => (homology,ZZ,ChainComplexMap),
 -- doc9.m2:1590:     Key => (cohomology,ZZ,ChainComplexMap),
 -- doc9.m2:1599:     Key => (homology,ChainComplex),
