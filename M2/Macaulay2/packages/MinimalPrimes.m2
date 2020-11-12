---------------------------------------------------------------------------
-- PURPOSE : Computation of minimal primes, and related functions
--
-- UPDATE HISTORY : created July 25, 2011 at the IMA M2 workshop as PD.m2
--                  renamed  Oct  7, 2014 to MinimalPrimes.m2
--                  updated July 26, 2019 at the IMA M2/Sage workshop
--                  updated  Nov 12, 2020 to use hooks
--
-- TODO : 1. move documentation to this package and complete
--        2. move tests to this package
--           test trivial ideals, cases that shouldn't work
--           funny gradings, quotient rings, etc.
--        3. turn strategies into hooks
--        4. which symbols need to be exported
---------------------------------------------------------------------------
newPackage(
    "MinimalPrimes",
    Version => "0.10",
    Date => "November 12, 2020",
    Headline => "minimal primes of an ideal",
    Authors => {
	{Name => "Frank Moore",    Email => "moorewf@wfu.edu",       HomePage => "https://users.wfu.edu/moorewf"},
	{Name => "Mike Stillman",  Email => "mike@math.cornell.edu", HomePage => "https://www.math.cornell.edu/~mike"},
	{Name => "Franziska Hinkelmann"},
	{Name => "Mahrud Sayrafi", Email => "mahrud@umn.edu",        HomePage => "https://math.umn.edu/~mahrud"}},
    Keywords => {"Commutative Algebra"},
    PackageImports => { "Elimination" },
    AuxiliaryFiles => true,
    DebuggingMode => true
    )

-- TODO: The following functions are used in tests.m2
-- They should be removed from the export list upon release
--  radicalContainment, factors, findNonMemberIndex,

-- MES notes 26 July 2019, flight back from IMA 2019 M2/Sage workshop
-- Overall structure of the algorithm.

-- idea is that we want to use some heuristics to split the ideal I
-- into a list of ideals such that: WRITE DOWN THE INVARIANT HERE
-- (The plan is that radical(I) = intersection of all ideals collected so far.).
-- We first make a simplification:
-- I is an ideal in a (flattened) polynomial ring.
--   Perhaps the invariant data should contain the list of computed annotated ideals, AND a
--   way to get back to the ring of I.
-- DESIRE: if the computation is interrupted, partial results can be viewed, and the computation
--   can be restarted.

-- TODO to get this into the system:
-- minprimes: installs itself into decompose. DONE
--   minprimes should stash its answer DONE
--             should work for quotients DONE
--             should give errors for general situations DONE?
--             what about over ZZ?
--             absolute case?
--             factorization over towers?
--  a better inductive system?

-- Mike and Frank talking 10/9/2014
-- to do:
-- .  The function 'factors' needs documentation and tests.
--    In fact, it is failing in some cases (e.g. when 'factor' returns a factor not in the polynomial ring)
-- .  Document minprimes, something about the strategies
-- .  Export only the symbols we want

export { "minprimes" }

exportFrom_Core { "decompose", "isPrime", "minimalPrimes" }

importFrom_Core { "raw", "rawCharSeries", "rawGBContains" }

-*------------------------------------------------------------------
-- Can we use these as keys to a ring's HashTable without exporting them?
-- It seems awkward to have to export these:
  toAmbientField, fromAmbientField
--- annotated ideal keys
  AnnotatedIdeal, Linears, NonzeroDivisors, Inverted, FiberInfo, LexGBOverBase, nzds
--- Splitting options. Should we be exporting these?
-- Are we going to be allowing the user to split (annotated) ideals using these options?
  Birational, -- Strategy option for splitIdeal.  Exported now for simplicity
  IndependentSet, SplitTower, LexGBSplit, Factorization,
  DecomposeMonomials, Trim, CharacteristicSets, Minprimes, Squarefree
-*------------------------------------------------------------------

protect symbol Legacy
protect symbol IndependentSet
protect symbol Trim
protect symbol Birational
protect symbol Linears
protect symbol DecomposeMonomials
protect symbol Factorization
protect symbol SplitTower
protect symbol CharacteristicSets

protect symbol Inverted
protect symbol LexGBOverBase
protect symbol NonzeroDivisors
protect symbol LexGBSplit
protect symbol Squarefree  -- MES todo: this is never being set but is being tested.

protect symbol toAmbientField
protect symbol fromAmbientField

--------------------------------------------------------------------
-- Support routines
--------------------------------------------------------------------

-- TODO: is this used anywhere?
USEMGB = false;
--if USEMGB then needsPackage "MGBInterface";
MGB = I -> flatten entries if USEMGB then groebnerBasis(I, Strategy=>"MGB") else gens gb I

-- TODO: what does factors G do? is this a better strategy for saturate?
mySat = (J, G) -> (for f in last \ factors G do J = saturate(J, f); J)

load "./MinimalPrimes/AnnotatedIdeal.m2"
load "./MinimalPrimes/PDState.m2"
load "./MinimalPrimes/splitIdeals.m2"
load "./MinimalPrimes/factorTower.m2"

-- Redundancy control:
-- find, if any, an element of I which is NOT in the ideal J.
-- returns the index x of that element, if any, else returns -1.
findNonMemberIndex = method()
findNonMemberIndex(Ideal, Ideal) := (I, J) -> rawGBContains(raw gb J, raw generators I)

-- The following function removes any elements which are larger than another one.
-- Each should be tagged with its codimension.  For each pair (L_i, L_j), check containment of GB's
selectMinimalIdeals = L -> (
    L = L / (i -> (codim i, flatten entries gens gb i)) // sort / last / ideal;
    ML := new MutableList from L;
    for i from 0 to #ML - 1 list (
        if ML#i === null then continue;
        for j from i + 1 to #ML - 1 do (
            if ML#j === null then continue;
            if findNonMemberIndex(ML#i, ML#j) === -1 then ML#j = null);
        ML#i))

--------------------------------------------------------------------
-- decompose, minimalPrimes, and minprimes
--------------------------------------------------------------------

minimalPrimesOptions = {
    Verbosity              => 0,
    Strategy               => "Birational", -- if null, calls older minprimesWorker code
    CodimensionLimit       => null, -- only find minimal primes of codim <= this bound
    "IdealSoFar"           => null, -- used in inductive setting
    "RadicalSoFar"         => null, -- used in inductive setting
    "CheckPrimeOnly"       => false,
    "SquarefreeFactorSize" => 1
    }

-- currently defined in m2/factor.m2, to be moved here eventually
decompose     Ideal :=
minimalPrimes Ideal := minimalPrimesOptions >> opts -> (cacheValue symbol minimalPrimes) (I ->
    if opts.Strategy === "Legacy" then legacyMinimalPrimes I else minprimes(I, opts, Verbosity => 0))

decompose     MonomialIdeal :=
minimalPrimes MonomialIdeal := {} >> opts -> (cacheValue symbol minimalPrimes) (I ->
    monomialIdeal \ if (minI := dual radical I) == 1 then { 0_(ring I) } else support \ minI_*)

---------------------------------
--- minprimes strategies
---------------------------------
-- TODO: turn into hooks
strat0 = ({Linear, DecomposeMonomials}, infinity)
strat1 = ({Linear, DecomposeMonomials, (Factorization, 3)}, infinity)
BirationalStrat = ({strat1, (Birational, infinity)}, infinity)
NoBirationalStrat = strat1
stratEnd = {(IndependentSet, infinity), SplitTower, CharacteristicSets}

getMinPrimesStrategy = strat -> (
    -- input: string: String
    -- output: is a strategy list/sequence, etc for use with minprimes
    -- MES
    if not instance(strat, String) then return strat;
    if strat === "Legacy"       then Legacy            else
    if strat === "NoBirational" then NoBirationalStrat else
    if strat === "Birational"   then BirationalStrat   else
    error("unknown strategy: " | strat))

minprimes = method(Options => minimalPrimesOptions)
minprimes Ideal := opts -> J -> (
    -- returns a list of ideals, the minimal primes of I
    A := ring J;
    (I, F) := flattenRing J; -- the ring map is not needed
    R := ring I;
    if I == 0 then return {if A === R then I else ideal map(A^1, A^0, 0)};
    if not isPolynomialRing R then error "expected ideal in a polynomial ring or a quotient of one";
    if not isCommutative R    then error "expected commutative polynomial ring";
    if (kk := coefficientRing R) =!= QQ
    and not instance(kk, QuotientRing)
    and not instance(kk, GaloisField)
    then error "expected base field to be QQ or ZZ/p or GF(q)";
    -- the map back to A, TODO: why not use F?
    psi := if R === A then identity else J -> (
	phi := map(A, R, generators(A, CoefficientRing => kk));
	trim phi J);
    -- note: at this point, R is the ring of I, and R is a polynomial ring over a prime field
    C := minprimesWithStrategy(I,
	Verbosity              => opts#Verbosity,
	Strategy               => getMinPrimesStrategy opts#Strategy,
	CodimensionLimit       => opts.CodimensionLimit,
	"SquarefreeFactorSize" => opts#"SquarefreeFactorSize"
	);
    C / psi)

minprimesWithStrategy = method(Options => options splitIdeals)
minprimesWithStrategy Ideal := opts -> I -> (
    newstrat := {opts.Strategy, stratEnd};
    if opts.CodimensionLimit === null
    then opts = opts ++ {CodimensionLimit => numgens I};
    pdState := createPDState(I);
    opts = opts ++ {"PDState" => pdState};
    M := splitIdeals({annotatedIdeal(I, {}, {}, {})}, newstrat, opts);
    -- if just a primality/primary check, then return result.
    -- should we cache what we have done somewhere?
    if opts#"CheckPrimeOnly" then return pdState#"isPrime";
    numRawPrimes := numPrimesInPDState pdState;
    --M = select(M, i -> codimLowerBound i <= opts#"CodimensionLimit");
    --(M1,M2) := separatePrime(M);
    if #M > 0 then (
         ( << "warning: ideal did not split completely: " << #M << " did not split!" << endl;);
         error "answer not complete";
         );
    if opts#Verbosity>=2 then (
       << "Converting annotated ideals to ideals and selecting minimal primes..." << flush;
    );
    answer := timing(selectMinimalIdeals \\ getPrimesInPDState pdState);
    if opts#Verbosity>=2 then (
       << " Time taken : " << answer#0 << endl;
       if #(answer#1) < numRawPrimes then (
            << "#minprimes=" << #(answer#1) << " #computed=" << numPrimesInPDState pdState << endl;
            );
    );
    answer#1)

-- This function is called from minimalPrimes/decompose
--   under an option Strategy=>"Legacy".
--   'minimalPrimes' is responsible for stashing the value under the
--   cache value 'minimalPrimes'.
legacyMinimalPrimes = I -> (
          -- I: Ideal
          -- result: list of prime ideals.
          if not instance(I, Ideal) then error "expected an ideal";
	  R := ring I;
	  (I',F) := flattenRing I; -- F is not needed
	  A := ring I';
	  G := map(R, A, generators(R, CoefficientRing => coefficientRing A));
	  --I = trim I';
	  I = I';
	  if not isPolynomialRing A then error "expected ideal in a polynomial ring or a quotient of one";
	  if not isCommutative A then
	    error "expected commutative polynomial ring";
	  kk := coefficientRing A;
	  if kk =!= QQ and not instance(kk,QuotientRing) then
	    error "expected base field to be QQ or ZZ/p";
	  if I == 0 then return {if A === R then I else ideal map(R^1,R^0,0)};
	  if debugLevel > 0 then homog := isHomogeneous I;
	  ics := irreducibleCharacteristicSeries I;
	  if debugLevel > 0 and homog then (
	       if not all(ics#0, isHomogeneous) then error "minimalPrimes: irreducibleCharacteristicSeries destroyed homogeneity";
	       );
	  -- remove any elements which have numgens > numgens I (Krull's Hauptidealsatz)
	  ngens := numgens I;
	  ics0 := select(ics#0, CS -> numgens source CS <= ngens);
	  Psi := apply(ics0, CS -> (
		    chk := topCoefficients CS;
		    chk = chk#1;  -- just keep the coefficients
		    chk = first entries chk;
		    iniCS := select(chk, i -> # support i > 0); -- this is bad if degrees are 0: degree i =!= {0});
		    if gbTrace >= 1 then << "saturating with " << iniCS << endl;
		    CS = ideal CS;
		    --<< "saturating " << CS << " with respect to " << iniCS << endl;
		    -- warning: over ZZ saturate does unexpected things.
		    scan(iniCS, a -> CS = saturate(CS, a, Strategy=>Eliminate));
     --	       scan(iniCS, a -> CS = saturate(CS, a));
		    --<< "result is " << CS << endl;
		    CS));
	  Psi = select(Psi, I -> I != 1);
	  Psi = new MutableList from Psi;
	  p := #Psi;
	  scan(0 .. p-1, i -> if Psi#i =!= null then
	       scan(i+1 .. p-1, j ->
		    if Psi#i =!= null and Psi#j =!= null then
		    if isSubset(Psi#i, Psi#j) then Psi#j = null else
		    if isSubset(Psi#j, Psi#i) then Psi#i = null));
	  Psi = toList select(Psi,i -> i =!= null);
	  components := apply(Psi, p -> ics#1 p);
	  if A =!= R then (
	       components = apply(components, P -> trim(G P));
	       );
	  components
	  )

--------------------------------------------------------------------
----- Development section
--------------------------------------------------------------------
-- TODO: where should these go? Reduce redundancy

------------------------------
--- isPrime ------------------
------------------------------
-- TODO: replace with isPrime
isPrime' = method(
    Options => {
	Verbosity              => 0,
	Strategy               => BirationalStrat,
	"SquarefreeFactorSize" => 1
	})
isPrime' Ideal := opts -> I -> ( C := minprimes(I, opts ++ {"CheckPrimeOnly" => true}); #C === 1 and C#0 == I )

------------------------------
-- Radical containment -------
------------------------------

-- helper function for 'radicalContainment'
radFcn = (cacheValue "RadicalContainmentFunction") (I -> (
    R := ring I;
    n := numgens R;
    S := (coefficientRing R) (monoid[Variables => n + 1, MonomialSize => 16]);
    mapto := map(S, R, submatrix(vars S, {0..n-1}));
    I = mapto I;
    -- here is a GB of I!
    A := S/I;
    g -> (g1 := promote(mapto g, A); g1 == 0 or ideal(g1 * A_n - 1) == 1)))

radicalContainment = method()
-- Returns true if g is in the radical of I.
-- Assumption: I is in a monomial order for which you are happy to compute GB's.
radicalContainment(RingElement, Ideal) := (g, I) -> (radFcn I) g
-- Returns the first index i such that I_i is not in the radical of J,
-- and null, if none
-- another way to do something almost identical: select(1, I_*, radFcn J)
radicalContainment(Ideal, Ideal)       := (I, J) -> (rad := radFcn J; position(I_*, g -> not rad g))

----------------------------------------------
-- Factorization and fraction field helper routines
----------------------------------------------

-- setAmbientField:
--   input: KR, a ring of the form kk(t)[u] (t and u sets of variables)
--          RU, kk[u,t] (with some monomial ordering)
--   consequence: sets information in KR so that
--     'factors' and 'numerator', 'denominator' work for elemnts of KR
--     sets KR.toAmbientField, KR.fromAmbientField
setAmbientField = method()
setAmbientField(Ring, Ring) := (KR, RU) -> (
    -- KR should be of the form kk(t)[u]
    -- RU should be kk[u, t], with some monomial ordering
    KR.toAmbientField = map(frac RU,KR);
    KR.fromAmbientField = (f) -> (if ring f === frac RU then f = numerator f; (map(KR,RU)) f);
    numerator KR := (f) -> numerator KR.toAmbientField f;
    denominator KR := (f) -> denominator KR.toAmbientField f;
    )

-- needs documentation
factors = method()
factors RingElement := (F) -> (
    R := ring F;
    if F == 0 then return {(1,F)};
    facs := if R.?toAmbientField then (
        F = R.toAmbientField F;
        RU := ring numerator F;
        numerator factor F
        )
    else if isPolynomialRing R and instance(coefficientRing R, FractionField) then (
        KK := coefficientRing R;
        A := last KK.baseRings;
        RU = (coefficientRing A) (monoid[generators R, generators KK, MonomialOrder=>Lex]);
        setAmbientField(R, RU);
        F = R.toAmbientField F;
        numerator factor F
        )
    else if instance(R, FractionField) then (
        -- What to return in this case?
        -- WORKING ON THIS MES
        error "still need to handle FractionField case";
        )
    else (
        RU = ring F;
        factor F
        );
    facs = facs//toList/toList; -- elements of facs: {factor, multiplicity}
    facs = select(facs, z -> ring first z === RU);
    facs = apply(#facs, i -> (facs#i#1, (1/leadCoefficient facs#i#0) * facs#i#0 ));
    facs = select(facs, (n,f) -> # support f =!= 0);
    if R.?toAmbientField then apply(facs, (r,g) -> (r, R.fromAmbientField g)) else facs
    )

makeFiberRings = method()
makeFiberRings List       :=  basevars    -> (
    if #basevars =!= 0 then makeFiberRings(basevars, ring (basevars#0))
    else error "Expected at least one variable in the base")
makeFiberRings(List,Ring) := (basevars,R) -> (
    -- basevars: a list, possibly empty, of variables in the ring R.
    -- R: a flattened polynomial ring.
    -- result: (S, SF):
    --   S = R, but with a new monomial order.  S = kk[fibervars, basevars, Lex in fiber vars]
    --   SF = frac(kk[basevars])[fibervars, MonomialOrder=>Lex]
    -- warning: if R is already in Lex order, a new ring is currently created.  This behavior may change.
    -- consequences:
    --   In the cache of S:
    --     StoSF: S --> SF.
    --     SFtoS: SF --> S
    --     StoR: S --> R
    --     RtoS: R --> S
    --   Additionally:
    --     numerator(f in SF) gives element in S.
    --     denominator(f in SF) gives an element in S, although it will be in kk[basevars].
    --     factors(f in a ring)
    --   In the (mutable hash table of) SF:
    --     toAmbientField: SF -> frac S
    --     fromAmbientField(f in frac S) = (numerator f, which is in S), but mapped into SF.
    --
    -- Really, these are the rings we want?
    -- S = kk[fibervars, basevars]
    -- SF = kk(basevars)[fibervars]
    -- frac S
    -- A = kk[basevars] -- obtained via 'ambient coefficientRing SF'
    -- KA = frac(kk(basevars)) -- obtained via 'coefficientRing SF'
   local S;
   if #basevars == 0 then (
        -- in this case, we are not inverting any variables.  So, S = SF, and S just has the lex
        -- order.
        S = newRing(R, MonomialOrder=>Lex);
        S#cache = new CacheTable;
        S.cache#"RtoS" = map(S,R,sub(vars R,S));
        S.cache#"StoR" = map(R,S,sub(vars S,R));
        S.cache#"StoSF" = identity;
        S.cache#"SFtoS" = identity;
        numerator S := identity;
        (S,S)
   )
   else
   (
      if any(basevars, x -> ring x =!= R) then error "expected all base variables to have the same ring";
      allVars := set gens R;
      fiberVars := rsort toList(allVars - set basevars);
      basevars = rsort basevars;
      S = (coefficientRing R) monoid([fiberVars,basevars,MonomialOrder=>Lex]);
          --MonomialOrder=>{#fiberVars,#basevars}]);
      KK := frac((coefficientRing R)(monoid [basevars]));
      SF := KK (monoid[fiberVars, MonomialOrder=>Lex]);
      S#cache = new CacheTable;
      S.cache#"StoSF" = map(SF,S,sub(vars S,SF));
      S.cache#"SFtoS" = map(S,SF,sub(vars SF,S));
      S.cache#"StoR" = map(R,S,sub(vars S,R));
      S.cache#"RtoS" = map(S,R,sub(vars R,S));
      setAmbientField(SF, S);
      (S, SF)
   )
)

--------------------------------------------------------------------
----- Tests section
--------------------------------------------------------------------

load "./MinimalPrimes/tests.m2"

--------------------------------------------------------------------
----- Documentation section
--------------------------------------------------------------------

beginDocumentation()
load "./MinimalPrimes/doc.m2"

end--

restart
debugLevel = 1
debug needsPackage "MinimalPrimes"

R1 = QQ[d, f, j, k, m, r, t, A, D, G, I, K];
I1 = ideal ( I*K-K^2, r*G-G^2, A*D-D^2, j^2-j*t, d*f-f^2, d*f*j*k - m*r, A*D - G*I*K);
time minprimes(I1, CodimensionLimit=>6, Verbosity=>2)
#(minprimes I1)
#(oldMinPrimes I1)
time minprimes(I1, CodimensionLimit=>7, Verbosity=>2)
time minprimes(I1, CodimensionLimit=>6, Verbosity=>2);

restart
needsPackage "MinimalPrimes"
check MinimalPrimes

R1 = QQ[d, f, j, k, m, r, t, A, D, G, I, K];
I1 = ideal ( I*K-K^2, r*G-G^2, A*D-D^2, j^2-j*t, d*f-f^2, d*f*j*k - m*r, A*D - G*I*K);
-- C = doSplitIdeal(I1, Verbosity=>2)
time minprimes(I1, CodimensionLimit=>6, Verbosity=>2)
C = time minprimes I1
C = time minprimes(I1, Strategy=>"NoBirational", Verbosity=>2)
C = time minprimes(I1, Strategy=>"NoBirationa", Verbosity=>2)

R1 = QQ[a,b,c]
I1 = ideal(a^2-3, b^2-3)
C = doSplitIdeal(I1, Verbosity=>2)
minprimes(I1, Verbosity=>2)

kk = ZZ/7
R = kk[x,y,t]
I = ideal {x^7-t^2,y^7-t^2}
minprimes I
C = doSplitIdeal(I, Verbosity=>2)
