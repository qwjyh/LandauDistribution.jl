using StaticArrays

"""
    Landau(μ,θ)

The *Landau distribution* with location `μ` and scale `θ` has probability density function

```math
p(x) = \\frac{1}{2 \\pi i} \\int_{\\mu-i\\infty}^{\\mu+i\\infty} e^{s \\log(s) + x s}\\, ds
```

```julia
Landau()       # Landau distribution with zero location and unit scale, i.e. Landau(0, 1)
Landau(u)      # Landau distribution with location u and unit scale, i.e. Landau(u, 1)
Landau(u, b)   # Landau distribution with location u ans scale b

params(d)       # Get the parameters, i.e. (u, b)
location(d)     # Get the location parameter, i.e. u
scale(d)        # Get the scale parameter, i.e. b
```

External links

* [Landau distribution on Wikipedia](http://en.wikipedia.org/wiki/Landau_distribution)

"""
struct Landau{T<:Real} <: ContinuousUnivariateDistribution
    μ::T
    θ::T
    function Landau(μ::T, θ::T; check_args=true) where {T<:Real}
        check_args && @check_args(Landau, θ > zero(θ))
        return new{T}(μ, θ)
    end
end

Landau(μ::Real, θ::Real; check_args=true) = Landau(promote(μ, θ)...; check_args=check_args)
Landau(μ::Real=0) = Landau(μ, one(μ); check_args=false)

@distr_support Landau -Inf Inf

#### Conversions
function Base.convert(::Type{Landau{T}}, μ::S, θ::S) where {T<:Real,S<:Real}
    return Landau(T(μ), T(θ))
end
function Base.convert(::Type{Landau{T}}, d::Landau{S}) where {T<:Real,S<:Real}
    return Landau(T(d.μ), T(d.θ); check_args=false)
end

#### Parameters

location(d::Landau) = d.μ
scale(d::Landau) = d.θ

params(d::Landau) = (d.μ, d.θ)
@inline partype(d::Landau{T}) where {T<:Real} = T

#### Evaluation
pdf(d::Landau, x::Real) = _landau_pdf(x, d.θ, d.μ)

cdf(d::Landau, x::Real) = _landau_cdf(x, d.θ, d.μ)

function cf(d::Landau, t::Real)
    z = t * (d.μ + d.θ * (sign(t) * im - twoinvπ * log(abs(t))))
    return iszero(t) ? cis(zero(z)) : cis(z)
end

# https://root.cern.ch/doc/v622/PdfFuncMathCore_8cxx_source.html
# x1 is the scale and x0 is the location parameter
function _landau_pdf(x, xi=1, x0=0)
    # landau pdf : algorithm from cernlib g110 denlan
    p1 = @SVector [
        0.4259894875, -0.1249762550, 0.03984243700, -0.006298287635, 0.001511162253
    ]
    q1 = @SVector [1.0, -0.3388260629, 0.09594393323, -0.01608042283, 0.003778942063]

    p2 = @SVector [
        0.1788541609, 0.1173957403, 0.01488850518, -0.001394989411, 0.0001283617211
    ]
    q2 = @SVector [1.0, 0.7428795082, 0.3153932961, 0.06694219548, 0.008790609714]

    p3 = @SVector [
        0.1788544503, 0.09359161662, 0.006325387654, 0.00006611667319, -0.000002031049101
    ]
    q3 = @SVector [1.0, 0.6097809921, 0.2560616665, 0.04746722384, 0.006957301675]

    p4 = @SVector [0.9874054407, 118.6723273, 849.2794360, -743.7792444, 427.0262186]
    q4 = @SVector [1.0, 106.8615961, 337.6496214, 2016.712389, 1597.063511]

    p5 = @SVector [1.003675074, 167.5702434, 4789.711289, 21217.86767, -22324.94910]
    q5 = @SVector [1.0, 156.9424537, 3745.310488, 9834.698876, 66924.28357]

    p6 = @SVector [1.000827619, 664.9143136, 62972.92665, 475554.6998, -5743609.109]
    q6 = @SVector [1.0, 651.4101098, 56974.73333, 165917.4725, -2815759.939]

    a1 = @SVector [0.04166666667, -0.01996527778, 0.02709538966]

    a2 = @SVector [-1.845568670, -4.284640743]

    xi <= 0 && return 0
    v = (x - x0) / xi
    u = ue = us = denlan = 0.0
    @inbounds if v < -5.5
        u = exp(v + 1.0)
        u < 1e-10 && return 0.0
        ue = exp(-1 / u)
        us = sqrt(u)
        denlan = 0.3989422803 * (ue / us) * (1 + (a1[1] + (a1[2] + a1[3] * u) * u) * u)
    elseif (v < -1)
        u = exp(-v - 1)
        denlan =
            exp(-u) *
            sqrt(u) *
            (p1[1] + (p1[2] + (p1[3] + (p1[4] + p1[5] * v) * v) * v) * v) /
            (q1[1] + (q1[2] + (q1[3] + (q1[4] + q1[5] * v) * v) * v) * v)
    elseif (v < 1)
        denlan =
            (p2[1] + (p2[2] + (p2[3] + (p2[4] + p2[5] * v) * v) * v) * v) /
            (q2[1] + (q2[2] + (q2[3] + (q2[4] + q2[5] * v) * v) * v) * v)
    elseif (v < 5)
        denlan =
            (p3[1] + (p3[2] + (p3[3] + (p3[4] + p3[5] * v) * v) * v) * v) /
            (q3[1] + (q3[2] + (q3[3] + (q3[4] + q3[5] * v) * v) * v) * v)
    elseif (v < 12)
        u = 1 / v
        denlan =
            u * u * (p4[1] + (p4[2] + (p4[3] + (p4[4] + p4[5] * u) * u) * u) * u) /
            (q4[1] + (q4[2] + (q4[3] + (q4[4] + q4[5] * u) * u) * u) * u)
    elseif (v < 50)
        u = 1 / v
        denlan =
            u * u * (p5[1] + (p5[2] + (p5[3] + (p5[4] + p5[5] * u) * u) * u) * u) /
            (q5[1] + (q5[2] + (q5[3] + (q5[4] + q5[5] * u) * u) * u) * u)
    elseif (v < 300)
        u = 1 / v
        denlan =
            u * u * (p6[1] + (p6[2] + (p6[3] + (p6[4] + p6[5] * u) * u) * u) * u) /
            (q6[1] + (q6[2] + (q6[3] + (q6[4] + q6[5] * u) * u) * u) * u)
    else
        u = 1 / (v - v * log(v) / (v + 1))
        denlan = u * u * (1 + (a2[1] + a2[2] * u) * u)
    end
    return denlan / xi
end

#https://root.cern.ch/doc/v622/ProbFuncMathCore_8cxx_source.html
# x1 is the scale and x0 is the location parameter
function _landau_cdf(x, xi=1, x0=0)
    # implementation of landau distribution (from DISLAN)
    #The algorithm was taken from the Cernlib function dislan(G110)
    #Reference: K.S.Kolbig and B.Schorr, "A program package for the Landau
    #distribution", Computer Phys.Comm., 31(1984), 97-111

    p1 = @SVector [
        0.2514091491e+0,
        -0.6250580444e-1,
        0.1458381230e-1,
        -0.2108817737e-2,
        0.7411247290e-3,
    ]
    q1 = @SVector [
        1.0, -0.5571175625e-2, 0.6225310236e-1, -0.3137378427e-2, 0.1931496439e-2
    ]

    p2 = @SVector [0.2868328584e+0, 0.3564363231e+0, 0.1523518695e+0, 0.2251304883e-1]
    q2 = @SVector [1.0, 0.6191136137e+0, 0.1720721448e+0, 0.2278594771e-1]

    p3 = @SVector [0.2868329066e+0, 0.3003828436e+0, 0.9950951941e-1, 0.8733827185e-2]
    q3 = @SVector [1.0, 0.4237190502e+0, 0.1095631512e+0, 0.8693851567e-2]

    p4 = @SVector [0.1000351630e+1, 0.4503592498e+1, 0.1085883880e+2, 0.7536052269e+1]
    q4 = @SVector [1.0, 0.5539969678e+1, 0.1933581111e+2, 0.2721321508e+2]

    p5 = @SVector [0.1000006517e+1, 0.4909414111e+2, 0.8505544753e+2, 0.1532153455e+3]
    q5 = @SVector [1.0, 0.5009928881e+2, 0.1399819104e+3, 0.4200002909e+3]

    p6 = @SVector [0.1000000983e+1, 0.1329868456e+3, 0.9162149244e+3, -0.9605054274e+3]
    q6 = @SVector [1.0, 0.1339887843e+3, 0.1055990413e+4, 0.5532224619e+3]

    a1 = @SVector [0, -0.4583333333e+0, 0.6675347222e+0, -0.1641741416e+1]
    a2 = @SVector [0, 1.0, -0.4227843351e+0, -0.2043403138e+1]

    v = (x - x0) / xi

    @inbounds if (v < -5.5)
        u = exp(v + 1)
        lan =
            0.3989422803 *
            exp(-1.0 / u) *
            sqrt(u) *
            (1 + (a1[2] + (a1[3] + a1[4] * u) * u) * u)
    elseif (v < -1)
        u = exp(-v - 1)
        lan =
            (exp(-u) / sqrt(u)) *
            (p1[1] + (p1[2] + (p1[3] + (p1[4] + p1[5] * v) * v) * v) * v) /
            (q1[1] + (q1[2] + (q1[3] + (q1[4] + q1[5] * v) * v) * v) * v)
    elseif (v < 1)
        lan =
            (p2[1] + (p2[2] + (p2[3] + p2[4] * v) * v) * v) /
            (q2[1] + (q2[2] + (q2[3] + q2[4] * v) * v) * v)
    elseif (v < 4)
        lan =
            (p3[1] + (p3[2] + (p3[3] + p3[4] * v) * v) * v) /
            (q3[1] + (q3[2] + (q3[3] + q3[4] * v) * v) * v)
    elseif (v < 12)
        u = 1.0 / v
        lan =
            (p4[1] + (p4[2] + (p4[3] + p4[4] * u) * u) * u) /
            (q4[1] + (q4[2] + (q4[3] + q4[4] * u) * u) * u)
    elseif (v < 50)
        u = 1.0 / v
        lan =
            (p5[1] + (p5[2] + (p5[3] + p5[4] * u) * u) * u) /
            (q5[1] + (q5[2] + (q5[3] + q5[4] * u) * u) * u)
    elseif (v < 300)
        u = 1.0 / v
        lan =
            (p6[1] + (p6[2] + (p6[3] + p6[4] * u) * u) * u) /
            (q6[1] + (q6[2] + (q6[3] + q6[4] * u) * u) * u)
    else
        u = 1.0 / (v - v * log(v) / (v + 1))
        lan = 1 - (a2[2] + (a2[3] + a2[4] * u) * u) * u
    end
    return lan
end

#### Sampling
# adapted from https://root.cern/root/html524/src/TRandom.cxx.html#332
function rand(rng::AbstractRNG, d::Landau)
    f = [
       0.       , 0.       , 0.       ,0.        ,0.        ,-2.244733,
      -2.204365,-2.168163,-2.135219,-2.104898,-2.076740,-2.050397,
      -2.025605,-2.002150,-1.979866,-1.958612,-1.938275,-1.918760,
      -1.899984,-1.881879,-1.864385,-1.847451,-1.831030,-1.815083,
      -1.799574,-1.784473,-1.769751,-1.755383,-1.741346,-1.727620,
      -1.714187,-1.701029,-1.688130,-1.675477,-1.663057,-1.650858,
      -1.638868,-1.627078,-1.615477,-1.604058,-1.592811,-1.581729,
      -1.570806,-1.560034,-1.549407,-1.538919,-1.528565,-1.518339,
      -1.508237,-1.498254,-1.488386,-1.478628,-1.468976,-1.459428,
      -1.449979,-1.440626,-1.431365,-1.422195,-1.413111,-1.404112,
      -1.395194,-1.386356,-1.377594,-1.368906,-1.360291,-1.351746,
      -1.343269,-1.334859,-1.326512,-1.318229,-1.310006,-1.301843,
      -1.293737,-1.285688,-1.277693,-1.269752,-1.261863,-1.254024,
      -1.246235,-1.238494,-1.230800,-1.223153,-1.215550,-1.207990,
      -1.200474,-1.192999,-1.185566,-1.178172,-1.170817,-1.163500,
      -1.156220,-1.148977,-1.141770,-1.134598,-1.127459,-1.120354,
      -1.113282,-1.106242,-1.099233,-1.092255,
      -1.085306,-1.078388,-1.071498,-1.064636,-1.057802,-1.050996,
      -1.044215,-1.037461,-1.030733,-1.024029,-1.017350,-1.010695,
      -1.004064, -.997456, -.990871, -.984308, -.977767, -.971247,
       -.964749, -.958271, -.951813, -.945375, -.938957, -.932558,
       -.926178, -.919816, -.913472, -.907146, -.900838, -.894547,
       -.888272, -.882014, -.875773, -.869547, -.863337, -.857142,
       -.850963, -.844798, -.838648, -.832512, -.826390, -.820282,
       -.814187, -.808106, -.802038, -.795982, -.789940, -.783909,
       -.777891, -.771884, -.765889, -.759906, -.753934, -.747973,
       -.742023, -.736084, -.730155, -.724237, -.718328, -.712429,
       -.706541, -.700661, -.694791, -.688931, -.683079, -.677236,
       -.671402, -.665576, -.659759, -.653950, -.648149, -.642356,
       -.636570, -.630793, -.625022, -.619259, -.613503, -.607754,
       -.602012, -.596276, -.590548, -.584825, -.579109, -.573399,
       -.567695, -.561997, -.556305, -.550618, -.544937, -.539262,
       -.533592, -.527926, -.522266, -.516611, -.510961, -.505315,
       -.499674, -.494037, -.488405, -.482777,
       -.477153, -.471533, -.465917, -.460305, -.454697, -.449092,
       -.443491, -.437893, -.432299, -.426707, -.421119, -.415534,
       -.409951, -.404372, -.398795, -.393221, -.387649, -.382080,
       -.376513, -.370949, -.365387, -.359826, -.354268, -.348712,
       -.343157, -.337604, -.332053, -.326503, -.320955, -.315408,
       -.309863, -.304318, -.298775, -.293233, -.287692, -.282152,
       -.276613, -.271074, -.265536, -.259999, -.254462, -.248926,
       -.243389, -.237854, -.232318, -.226783, -.221247, -.215712,
       -.210176, -.204641, -.199105, -.193568, -.188032, -.182495,
       -.176957, -.171419, -.165880, -.160341, -.154800, -.149259,
       -.143717, -.138173, -.132629, -.127083, -.121537, -.115989,
       -.110439, -.104889, -.099336, -.093782, -.088227, -.082670,
       -.077111, -.071550, -.065987, -.060423, -.054856, -.049288,
       -.043717, -.038144, -.032569, -.026991, -.021411, -.015828,
       -.010243, -.004656,  .000934,  .006527,  .012123,  .017722,
        .023323,  .028928,  .034535,  .040146,  .045759,  .051376,
        .056997,  .062620,  .068247,  .073877,
        .079511,  .085149,  .090790,  .096435,  .102083,  .107736,
        .113392,  .119052,  .124716,  .130385,  .136057,  .141734,
        .147414,  .153100,  .158789,  .164483,  .170181,  .175884,
        .181592,  .187304,  .193021,  .198743,  .204469,  .210201,
        .215937,  .221678,  .227425,  .233177,  .238933,  .244696,
        .250463,  .256236,  .262014,  .267798,  .273587,  .279382,
        .285183,  .290989,  .296801,  .302619,  .308443,  .314273,
        .320109,  .325951,  .331799,  .337654,  .343515,  .349382,
        .355255,  .361135,  .367022,  .372915,  .378815,  .384721,
        .390634,  .396554,  .402481,  .408415,  .414356,  .420304,
        .426260,  .432222,  .438192,  .444169,  .450153,  .456145,
        .462144,  .468151,  .474166,  .480188,  .486218,  .492256,
        .498302,  .504356,  .510418,  .516488,  .522566,  .528653,
        .534747,  .540850,  .546962,  .553082,  .559210,  .565347,
        .571493,  .577648,  .583811,  .589983,  .596164,  .602355,
        .608554,  .614762,  .620980,  .627207,  .633444,  .639689,
        .645945,  .652210,  .658484,  .664768,
        .671062,  .677366,  .683680,  .690004,  .696338,  .702682,
        .709036,  .715400,  .721775,  .728160,  .734556,  .740963,
        .747379,  .753807,  .760246,  .766695,  .773155,  .779627,
        .786109,  .792603,  .799107,  .805624,  .812151,  .818690,
        .825241,  .831803,  .838377,  .844962,  .851560,  .858170,
        .864791,  .871425,  .878071,  .884729,  .891399,  .898082,
        .904778,  .911486,  .918206,  .924940,  .931686,  .938446,
        .945218,  .952003,  .958802,  .965614,  .972439,  .979278,
        .986130,  .992996,  .999875, 1.006769, 1.013676, 1.020597,
       1.027533, 1.034482, 1.041446, 1.048424, 1.055417, 1.062424,
       1.069446, 1.076482, 1.083534, 1.090600, 1.097681, 1.104778,
       1.111889, 1.119016, 1.126159, 1.133316, 1.140490, 1.147679,
       1.154884, 1.162105, 1.169342, 1.176595, 1.183864, 1.191149,
       1.198451, 1.205770, 1.213105, 1.220457, 1.227826, 1.235211,
       1.242614, 1.250034, 1.257471, 1.264926, 1.272398, 1.279888,
       1.287395, 1.294921, 1.302464, 1.310026, 1.317605, 1.325203,
       1.332819, 1.340454, 1.348108, 1.355780,
       1.363472, 1.371182, 1.378912, 1.386660, 1.394429, 1.402216,
       1.410024, 1.417851, 1.425698, 1.433565, 1.441453, 1.449360,
       1.457288, 1.465237, 1.473206, 1.481196, 1.489208, 1.497240,
       1.505293, 1.513368, 1.521465, 1.529583, 1.537723, 1.545885,
       1.554068, 1.562275, 1.570503, 1.578754, 1.587028, 1.595325,
       1.603644, 1.611987, 1.620353, 1.628743, 1.637156, 1.645593,
       1.654053, 1.662538, 1.671047, 1.679581, 1.688139, 1.696721,
       1.705329, 1.713961, 1.722619, 1.731303, 1.740011, 1.748746,
       1.757506, 1.766293, 1.775106, 1.783945, 1.792810, 1.801703,
       1.810623, 1.819569, 1.828543, 1.837545, 1.846574, 1.855631,
       1.864717, 1.873830, 1.882972, 1.892143, 1.901343, 1.910572,
       1.919830, 1.929117, 1.938434, 1.947781, 1.957158, 1.966566,
       1.976004, 1.985473, 1.994972, 2.004503, 2.014065, 2.023659,
       2.033285, 2.042943, 2.052633, 2.062355, 2.072110, 2.081899,
       2.091720, 2.101575, 2.111464, 2.121386, 2.131343, 2.141334,
       2.151360, 2.161421, 2.171517, 2.181648, 2.191815, 2.202018,
       2.212257, 2.222533, 2.232845, 2.243195,
       2.253582, 2.264006, 2.274468, 2.284968, 2.295507, 2.306084,
       2.316701, 2.327356, 2.338051, 2.348786, 2.359562, 2.370377,
       2.381234, 2.392131, 2.403070, 2.414051, 2.425073, 2.436138,
       2.447246, 2.458397, 2.469591, 2.480828, 2.492110, 2.503436,
       2.514807, 2.526222, 2.537684, 2.549190, 2.560743, 2.572343,
       2.583989, 2.595682, 2.607423, 2.619212, 2.631050, 2.642936,
       2.654871, 2.666855, 2.678890, 2.690975, 2.703110, 2.715297,
       2.727535, 2.739825, 2.752168, 2.764563, 2.777012, 2.789514,
       2.802070, 2.814681, 2.827347, 2.840069, 2.852846, 2.865680,
       2.878570, 2.891518, 2.904524, 2.917588, 2.930712, 2.943894,
       2.957136, 2.970439, 2.983802, 2.997227, 3.010714, 3.024263,
       3.037875, 3.051551, 3.065290, 3.079095, 3.092965, 3.106900,
       3.120902, 3.134971, 3.149107, 3.163312, 3.177585, 3.191928,
       3.206340, 3.220824, 3.235378, 3.250005, 3.264704, 3.279477,
       3.294323, 3.309244, 3.324240, 3.339312, 3.354461, 3.369687,
       3.384992, 3.400375, 3.415838, 3.431381, 3.447005, 3.462711,
       3.478500, 3.494372, 3.510328, 3.526370,
       3.542497, 3.558711, 3.575012, 3.591402, 3.607881, 3.624450,
       3.641111, 3.657863, 3.674708, 3.691646, 3.708680, 3.725809,
       3.743034, 3.760357, 3.777779, 3.795300, 3.812921, 3.830645,
       3.848470, 3.866400, 3.884434, 3.902574, 3.920821, 3.939176,
       3.957640, 3.976215, 3.994901, 4.013699, 4.032612, 4.051639,
       4.070783, 4.090045, 4.109425, 4.128925, 4.148547, 4.168292,
       4.188160, 4.208154, 4.228275, 4.248524, 4.268903, 4.289413,
       4.310056, 4.330832, 4.351745, 4.372794, 4.393982, 4.415310,
       4.436781, 4.458395, 4.480154, 4.502060, 4.524114, 4.546319,
       4.568676, 4.591187, 4.613854, 4.636678, 4.659662, 4.682807,
       4.706116, 4.729590, 4.753231, 4.777041, 4.801024, 4.825179,
       4.849511, 4.874020, 4.898710, 4.923582, 4.948639, 4.973883,
       4.999316, 5.024942, 5.050761, 5.076778, 5.102993, 5.129411,
       5.156034, 5.182864, 5.209903, 5.237156, 5.264625, 5.292312,
       5.320220, 5.348354, 5.376714, 5.405306, 5.434131, 5.463193,
       5.492496, 5.522042, 5.551836, 5.581880, 5.612178, 5.642734,
       5.673552, 5.704634, 5.735986, 5.767610,
       5.799512, 5.831694, 5.864161, 5.896918, 5.929968, 5.963316,
       5.996967, 6.030925, 6.065194, 6.099780, 6.134687, 6.169921,
       6.205486, 6.241387, 6.277630, 6.314220, 6.351163, 6.388465,
       6.426130, 6.464166, 6.502578, 6.541371, 6.580553, 6.620130,
       6.660109, 6.700495, 6.741297, 6.782520, 6.824173, 6.866262,
       6.908795, 6.951780, 6.995225, 7.039137, 7.083525, 7.128398,
       7.173764, 7.219632, 7.266011, 7.312910, 7.360339, 7.408308,
       7.456827, 7.505905, 7.555554, 7.605785, 7.656608, 7.708035,
       7.760077, 7.812747, 7.866057, 7.920019, 7.974647, 8.029953,
       8.085952, 8.142657, 8.200083, 8.258245, 8.317158, 8.376837,
       8.437300, 8.498562, 8.560641, 8.623554, 8.687319, 8.751955,
       8.817481, 8.883916, 8.951282, 9.019600, 9.088889, 9.159174,
       9.230477, 9.302822, 9.376233, 9.450735, 9.526355, 9.603118,
       9.681054, 9.760191, 9.840558, 9.922186,10.005107,10.089353,
      10.174959,10.261958,10.350389,10.440287,10.531693,10.624646,
      10.719188,10.815362,10.913214,11.012789,11.114137,11.217307,
      11.322352,11.429325,11.538283,11.649285,
      11.762390,11.877664,11.995170,12.114979,12.237161,12.361791,
      12.488946,12.618708,12.751161,12.886394,13.024498,13.165570,
      13.309711,13.457026,13.607625,13.761625,13.919145,14.080314,
      14.245263,14.414134,14.587072,14.764233,14.945778,15.131877,
      15.322712,15.518470,15.719353,15.925570,16.137345,16.354912,
      16.578520,16.808433,17.044929,17.288305,17.538873,17.796967,
      18.062943,18.337176,18.620068,18.912049,19.213574,19.525133,
      19.847249,20.180480,20.525429,20.882738,21.253102,21.637266,
      22.036036,22.450278,22.880933,23.329017,23.795634,24.281981,
      24.789364,25.319207,25.873062,26.452634,27.059789,27.696581,
      28.365274,29.068370,29.808638,30.589157,31.413354,32.285060,
      33.208568,34.188705,35.230920,36.341388,37.527131,38.796172,
      40.157721,41.622399,43.202525,44.912465,46.769077,48.792279,
      51.005773,53.437996,56.123356,59.103894 ]


    d.θ <= 0 ? (return 0) : nothing

    x = rand()
    u = 1000*x
    i = Int(floor(u))
    u -= i
    
    ranlan = 0.

    if (i >= 70 && i < 800)
        ranlan = f[i-1] + u*(f[i] - f[i-1])

    elseif (i >= 7 && i <= 980) 
        ranlan =  f[i-1] + u*(f[i]-f[i-1]-0.25*(1-u)*(f[i+1]-f[i]-f[i-1]+f[i-2]))

    elseif (i < 7)
        v = log(x)
        u = 1/v

        ranlan = ((0.99858950+(3.45213058E1+1.70854528E1*u)*u)/(1+(3.41760202E1+4.01244582  *u)*u))*(-log(-0.91893853-v)-1);
    else
        u = 1-x
        v = u^2
        if (x <= 0.999) 
            ranlan = (1.00060006+2.63991156E2*u+4.37320068E3*v)/((1+2.57368075E2*u+3.41448018E3*v)*u)
        else 
            ranlan = (1.00001538+6.07514119E3*u+7.34266409E5*v)/((1 + 6.06511919E3*u+6.94021044E5*v)*u)
        end
    end

    res = d.μ + d.θ*ranlan

    return res    
end

