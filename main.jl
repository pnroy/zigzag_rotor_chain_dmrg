using Printf
using LinearAlgebra
#using JLD
using ITensors
push!(LOAD_PATH,pwd())
using monomer
using dd_interaction
using create_operators
using expectation
using correlations
using trans_real_complex
using distributions

#Conversion factors#
a0toangst=0.529177210903 #Bohr to angstrom
eHtocm1=219474.631363	#Eh to cm-1
utome=1.0/(5.48579909065*1e-4)

function matrix_prod_ABC(U,A,B)
	tmp = BLAS.gemm('C','N', U,A)
	tmp2 = BLAS.gemm('N','N', tmp,B)
	C = BLAS.gemm('N','N', tmp2,U)
	return C
end

function create_file(path)
	fr=open(path,"w")
	println(fr,"jmax= ",jmax,", nmax= ",nmax)
	println(fr,"Nr. of sites: ",Nsites)
	println(fr,"Nr. of monomer states: ",Nstates)
	println(fr,"Dipole moment: ",mu0,", R0= ",R0*a0toangst)
	println(fr,"Chain angle: ",round(angle*180.0/pi,digits=2))
	println(fr)
	close(fr)
end

function make_TR_matrix(Ntrans,Nrot,M)
	matrix = zeros(Float64,(Ntrans*Nrot,Ntrans*Nrot))
	i1=0
	for it1=1:Ntrans
	for ir1=1:Nrot
		i1+=1
		i2=0
		for it2=1:Ntrans
		for ir2=1:Nrot
			i2+=1	
			if it1 == it2	
				matrix[i1,i2]=M[ir1,ir2]
			end
		end
		end
	end
	end
	return matrix
end

function transform_operator(iso,jmax,Ntrans,Nrot,oper,U,Utrans,Urot)
	tmp2 = transform_realbasis(Utrans_rot,tmp)
	M_TR = make_TR_matrix(Ntrans,Nrot,tmp2)
	tmp = BLAS.gemm('T','N', U,M_TR)
	op_out = BLAS.gemm('N','N', tmp,U)
	return op_out	
end

function transform_op_prod(iso,jmax,Ntrans,Nrot,A,B,U)
	tmp = BLAS.gemm('N','N', A,B)
	tmp2 = spin_isomer(iso,jmax,tmp)
	M_TR = make_TR_matrix(Ntrans,Nrot,tmp2)
	tmp3 = BLAS.gemm('C','N', U,M_TR)
	op_out = BLAS.gemm('N','N',tmp3,U)
	return op_out	
end

function transform_op_translation(M,U,Ntrans,Nrot,kind) 
	
	Ndist = size(M,3)
	#Rearrange monomer basis#
	Unew = zeros(Float64,(Ntrans,Nstates,Nrot))
	k=0
	for it=1:Ntrans
	for ir=1:Nrot
		k+=1
		Unew[it,:,ir] = U[k,:]
	end
	end 
	
	if kind == "distribution"
		Mout = zeros(Float64,(Nstates,Nstates,Ndist))
		for idist=1:Ndist
			for ir=1:Nrot
				tmp=BLAS.gemm('C','N', Unew[:,:,ir],M[:,:,idist])
				Mout[:,:,idist].+=real(BLAS.gemm('N','N',tmp,Unew[:,:,ir]))
			end
		end
	elseif kind == "normal"
		Mout = zeros(Float64,(Nstates,Nstates))
		for ir=1:Nrot
			tmp=BLAS.gemm('C','N', Unew[:,:,ir],M)
			Mout.+=real(BLAS.gemm('N','N',tmp,Unew[:,:,ir]))
		end
	end
	return Mout
end

function transform_op_rotation(M,U,Ntrans,Nrot,kind) 
	
	Ndist = size(M,3)
	#Rearrange monomer basis#
	Unew = zeros(Float64,(Nrot,Nstates,Ntrans))
	k=0
	for it=1:Ntrans
	for ir=1:Nrot
		k+=1
		Unew[ir,:,it] = U[k,:]
	end
	end 
	
	if kind == "distribution"
		Mout = zeros(Float64,(Nstates,Nstates,Ndist))
		for idist=1:Ndist
			for it=1:Ntrans
				tmp=BLAS.gemm('C','N', Unew[:,:,it],M[:,:,idist])
				Mout[:,:,idist].+=real(BLAS.gemm('N','N',tmp,Unew[:,:,it]))
			end
		end
	elseif kind == "normal"
		Mout = zeros(Float64,(Nstates,Nstates))
		for it=1:Ntrans
			tmp=BLAS.gemm('C','N', Unew[:,:,it],M)
			Mout.+=real(BLAS.gemm('N','N',tmp,Unew[:,:,it]))
		end
	end
	return Mout
end




####################################
##Read information from input file##
####################################
f=open("input.txt") 
lines=readlines(f)


lsplit=split(lines[5])
Nsites=parse(Int64, lsplit[2])
lsplit=split(lines[6])
Nbond=parse(Int64, lsplit[2])
lsplit=split(lines[7])
Nsweep=parse(Int64, lsplit[2])

lsplit=split(lines[10])
e_cutoff=parse(Float64, lsplit[2])
lsplit=split(lines[11])
dmrg_svd=parse(Float64, lsplit[2])

lsplit=split(lines[14])
mbond=parse(Int64, lsplit[2])

lsplit=split(lines[17])
angle=parse(Float64, lsplit[2])
angle = angle*pi/180.0


lsplit=split(lines[18])
R0=parse(Float64, lsplit[2])
lsplit=split(lines[19])
mu0=parse(Float64, lsplit[2])
lsplit=split(lines[20])
dmu=parse(Float64, lsplit[2])
lsplit=split(lines[21])
Nmu=parse(Int64, lsplit[2])

lsplit=split(lines[24])
isomer=lsplit[2]

lsplit=split(lines[27])
Nlevel=parse(Int64, lsplit[2])

lsplit=split(lines[30])
Ntotal=parse(Int64, lsplit[2])

lsplit=split(lines[33])
polarization= lsplit[2]
lsplit=split(lines[34])
Estart= parse(Float64,lsplit[2])

lsplit=split(lines[37])
interaction= lsplit[2]

lsplit=split(lines[42])
jmax=parse(Int64, lsplit[2])

lsplit=split(lines[45])
Nalpha=parse(Int64, lsplit[2])
lsplit=split(lines[46])
Nm=parse(Int64, lsplit[2])

lsplit=split(lines[49])
B0=parse(Float64, lsplit[2])
B0=B0/eHtocm1

lsplit=split(lines[52])
nmax=parse(Int64, lsplit[2])
lsplit=split(lines[53])
mass=parse(Float64, lsplit[2])
mass=mass*utome
lsplit=split(lines[54])
omega=parse(Float64, lsplit[2])
omega/= eHtocm1 #HF
#omega= 267.29/eHtocm1	#LiF
nu=mass*omega*0.5

lsplit=split(lines[57])
NR=parse(Int64, lsplit[2])
lsplit=split(lines[58])
Ntheta=parse(Int64, lsplit[2])
lsplit=split(lines[59])
Nphi=parse(Int64, lsplit[2])

lsplit=split(lines[62])
eq_struct=zeros(2)
eq_struct[1]=parse(Float64,lsplit[2])
eq_struct[1]=eq_struct[1]/a0toangst

lsplit=split(lines[65])
svd_err=parse(Float64, lsplit[2])

close(f)

if interaction == "next" && Nsites == 2
        println("Not enough sites for next-nearest interaction!")
        exit()
end

#Determine total number of monomer states for given number of levels#
#states_degeneracy = [1,3,3,5,1,3,5,1,5,4,3,3,5,3,4,3,5,3,4,5,4,3,3,5,3,4,1,3,4]	#HF
states_degeneracy = [1,3,5,3,3,1,5,4,3,5,3,3,4,5,1,3,5,3,4,3,4,5,3,4,5,4,5,3]	#DF
global Nstates=0
for ii=1:Nlevel
	global Nstates+=states_degeneracy[ii]
end

create_file("energy.txt")
create_file("entropy.txt")
for istates=1:Ntotal
	create_file("schmidt_values_"*string(istates)*".txt")
	create_file("radial_distribution_"*string(istates)*".txt")
	create_file("ctheta_distribution_"*string(istates)*".txt")
	create_file("phi_distribution_"*string(istates)*".txt")
end
create_file("muxcorr.txt")
create_file("muycorr.txt")
create_file("muzcorr.txt")
create_file("muxcorr_center.txt")
create_file("muycorr_center.txt")
create_file("muzcorr_center.txt")
create_file("mux.txt")
create_file("muy.txt")
create_file("muz.txt")
create_file("xcorr.txt")
create_file("ycorr.txt")
create_file("zcorr.txt")
create_file("xavg.txt")
create_file("yavg.txt")
create_file("zavg.txt")
create_file("binder_x.txt")
create_file("binder_y.txt")
create_file("binder_z.txt")

###########################
##Calculate monomer basis##
###########################	

f=open("log","w")
println(f,"###################################")
println(f,"###########Monomer basis###########")
println(f,"###################################")
println(f)
println(f,"Number of sites: ",Nsites)
println(f)
println(f,"Number of monomer levels: ",Nlevel)
println(f,"Number of monomer states: ",Nstates)
close(f)
e_mono,Umono,Ntrans,Nrot = monomer_basis(Nstates,jmax,Nalpha,Nm,B0,nmax,NR,Ntheta,Nphi,omega,mass,eq_struct,svd_err)

f=open("log","a")
println(f)
println(f,"#####################################")
println(f,"###########Vdd calculation###########")
println(f,"#####################################")
println(f)
println(f,"Chain angle: ",round(angle*180.0/pi,digits=2))
println(f)
close(f)

#################################################
##Calculate Vdd matrix on monomer basis##
#################################################
if interaction == "next"
        f=open("log","a")
        println(f,"#Calculate next-nearest neighbour dipole-dipole interaction#")
        println(f)
        close(f)
        R1 = [0.0,0.0,0.0]
        R2 = 2*R0*[0.0,0.0,sin(0.5*angle)]
        coeff_nnn,VA_nnn,VB_nnn = Vdd(jmax,nmax,NR,Ntheta,Nphi,R0,R1,R2,mu0,nu,mass,Ntrans,Nrot,Umono[:,1:Nstates],svd_err)

        global Nprod_nnn = zeros(Int64,9)

        global V1_nnn = VA_nnn[1]
        global W1_nnn = VB_nnn[1]
        global Nprod_nnn[1] = size(V1_nnn,3)

        global V2_nnn = VA_nnn[2]
        global W2_nnn = VB_nnn[2]
        global Nprod_nnn[2] = size(V2_nnn,3)

        global V3_nnn = VA_nnn[3]
        global W3_nnn = VB_nnn[3]
        global Nprod_nnn[3] = size(V3_nnn,3)

        global V4_nnn = VA_nnn[4]
        global W4_nnn = VB_nnn[4]
        global Nprod_nnn[4] = size(V4_nnn,3)

        global V5_nnn = VA_nnn[5]
        global W5_nnn = VB_nnn[5]
        global Nprod_nnn[5] = size(V5_nnn,3)

        global V6_nnn = VA_nnn[6]
        global W6_nnn = VB_nnn[6]
        global Nprod_nnn[6] = size(V6_nnn,3)

        global V7_nnn = VA_nnn[7]
        global W7_nnn = VB_nnn[7]
        global Nprod_nnn[7] = size(V7_nnn,3)

        global V8_nnn = VA_nnn[8]
        global W8_nnn = VB_nnn[8]
        global Nprod_nnn[8] = size(V8_nnn,3)

        global V9_nnn = VA_nnn[9]
        global W9_nnn = VB_nnn[9]
        global Nprod_nnn[9] = size(V9_nnn,3)

elseif interaction == "nearest"

        Nprod_nnn=1

        f=open("log","a")
        println(f,"#Only nearest-neighbour dipole-dipole interaction#")
        println(f)
        close(f)
end

f=open("log","a")
println(f,"#Calculate upward dipole-dipole interaction#")
println(f)
close(f)
R1 = [0.0,0.0,0.0]
R2 = R0*[0.0,cos(0.5*angle),sin(0.5*angle)]

coeff_up,VA_up,VB_up = Vdd(jmax,nmax,NR,Ntheta,Nphi,R0,R1,R2,mu0,nu,mass,Ntrans,Nrot,Umono[:,1:Nstates],svd_err)


f=open("log","a")
println(f,"#Calculate downward dipole-dipole interaction#")
println(f)
close(f)
R1 = [0.0,0.0,0.0]
R2 = R0*[0.0,-cos(0.5*angle),sin(0.5*angle)]

coeff_down,VA_down,VB_down = Vdd(jmax,nmax,NR,Ntheta,Nphi,R0,R1,R2,mu0,nu,mass,Ntrans,Nrot,Umono[:,1:Nstates],svd_err)

f=open("log","a")
println(f,"Dipole-dipole interaction calculated")
println(f)

#Create kinetic energy matrices in monomer basis#
println(f,"Create kinetic matrix in monomer basis")
println(f)
close(f)
T = zeros(Float64,(Nstates,Nstates))
for ii=1:Nstates
	T[ii,ii] = e_mono[ii]-e_mono[1]
end

#############################################
##Calculate matrcies for expectation values##
#############################################

#Transformation matrices to real rotational and translational basis#
Utrans_rot = trans_realSPH(jmax,Nrot,"rotation")
Utrans_trans = trans_realSPH(nmax,Ntrans,"translation")

##Elements of BF-S transformation matrix in Wigner basis##
preX1,preX2,preX3,preY1,preY2,preY3,preZ1,preZ2,preZ3,Muzabstmp = Rot_elements(jmax,Nalpha,Nm,Ntrans)

#Dipole moment components#
MuX = transform_op_rotation(preX3,Umono,Ntrans,Nrot,"normal") 
MuY = transform_op_rotation(preY3,Umono,Ntrans,Nrot,"normal") 
MuZ = transform_op_rotation(preZ3,Umono,Ntrans,Nrot,"normal") 
MuZabs = transform_op_rotation(Muzabstmp,Umono,Ntrans,Nrot,"normal") 

#COM components#
Xtmp,Ytmp,Ztmp = XYZ_COM(Nrot,Ntrans,nmax,omega,mass)
Xop = transform_op_translation(Xtmp,Umono,Ntrans,Nrot,"normal") 
Yop = transform_op_translation(Ytmp,Umono,Ntrans,Nrot,"normal") 
Zop = transform_op_translation(Ztmp,Umono,Ntrans,Nrot,"normal") 

#Distributions#
#Radial#
PRtmp,Rgrid = distro_R(Nrot,Ntrans,nmax,omega,mass)
PR = transform_op_translation(PRtmp,Umono,Ntrans,Nrot,"distribution") 
Nrad = length(Rgrid)

#Cos(theta) (Euler angle)#
Pttmp,ctgrid2 = distro_ctheta(Nrot,Ntrans,jmax,omega,mass)
Ptheta = transform_op_rotation(Pttmp,Umono,Ntrans,Nrot,"distribution") 
Nangle = length(ctgrid2)

#Phi (Rotational angle)#
Pptmp,pgrid = distro_phi(Nrot,Ntrans,jmax,omega,mass)
Pphi = transform_op_rotation(Pptmp,Umono,Ntrans,Nrot,"distribution")
Nangle_phi = length(pgrid)

global Nprod_up = zeros(Int64,9)
global Nprod_down = zeros(Int64,9)

global V1_up = VA_up[1]
global W1_up = VB_up[1]
global Nprod_up[1] = size(V1_up,3)
global V1_down = VA_down[1]
global W1_down = VB_down[1]
global Nprod_down[1] = size(V1_down,3)

global V2_up = VA_up[2]
global W2_up = VB_up[2]
global Nprod_up[2] = size(V2_up,3)
global V2_down = VA_down[2]
global W2_down = VB_down[2]
global Nprod_down[2] = size(V2_down,3)

global V3_up = VA_up[3]
global W3_up = VB_up[3]
global Nprod_up[3] = size(V3_up,3)
global V3_down = VA_down[3]
global W3_down = VB_down[3]
global Nprod_down[3] = size(V3_down,3)

global V4_up = VA_up[4]
global W4_up = VB_up[4]
global Nprod_up[4] = size(V4_up,3)
global V4_down = VA_down[4]
global W4_down = VB_down[4]
global Nprod_down[4] = size(V4_down,3)

global V5_up = VA_up[5]
global W5_up = VB_up[5]
global Nprod_up[5] = size(V5_up,3)
global V5_down = VA_down[5]
global W5_down = VB_down[5]
global Nprod_down[5] = size(V5_down,3)

global V6_down = VA_down[6]
global W6_down = VB_down[6]
global Nprod_down[6] = size(V6_down,3)
global V6_up = VA_up[6]
global W6_up = VB_up[6]
global Nprod_up[6] = size(V6_up,3)

global V7_down = VA_down[7]
global W7_down = VB_down[7]
global Nprod_down[7] = size(V7_down,3)
global V7_up = VA_up[7]
global W7_up = VB_up[7]
global Nprod_up[7] = size(V7_up,3)

global V8_down = VA_down[8]
global W8_down = VB_down[8]
global Nprod_down[8] = size(V8_down,3)
global V8_up = VA_up[8]
global W8_up = VB_up[8]
global Nprod_up[8] = size(V8_up,3)

global V9_down = VA_down[9]
global W9_down = VB_down[9]
global Nprod_down[9] = size(V9_down,3)
global V9_up = VA_up[9]
global W9_up = VB_up[9]
global Nprod_up[9] = size(V9_up,3)

operators(Nstates,Nprod_up,Nprod_down,Nprod_nnn,Nrad,Nangle,Nangle_phi,interaction)

if polarization == "no"
	Nfield = 1
end

lst = Float64[]

for ii=1:Nmu-1
        push!(lst,mu0+dmu*(ii-1))
end
push!(lst,0.5759)
dvec = sort(lst)

for idip=0:Nmu-1
let
	include("operators.jl")
	include("observer.jl")
	
	if polarization == "no"
		Estrength = 0.0
	else
		Estrength = Estart 
		Estrength = Estrength/eHtocm1	
	end	

	#dipole = mu0 + dmu*idip 
	dipole = dvec[idip+1]

	################################################
	##DMRG calculation of chain of asymmetric tops##
	################################################
	fac1 = 1 #eHtocm1/Nsites
	fac2 = eHtocm1 #Nsites
	
	if idip == 0
		f1=open("log","a")
		println(f1,"###############################################################################")
		println(f1,"Calculate initial state (chain of free rotators)")
		println(f1)
		close(f1)
		sites=siteinds("AsymTop",Nsites)
		ampo0 = AutoMPO()
		#Define Hamiltonian as MPO#
		for j=1:Nsites
			ampo0 += 1.0*fac1,"T",j
		end
		#Add electrical field#
		if polarization == "no"
	
	        elseif polarization == "X"
	                for i=1:Nsites
	                        ampo0+=-Estrength*fac1,"MuX",i
	                end
	        elseif polarization == "Y"
	                for i=1:Nsites
	                        ampo0+=-Estrength*fac1,"MuY",i
	                end
	        elseif polarization == "Z"
	                for i=1:Nsites
	                       ampo0+=-Estrength*fac1,"MuZ",i
	                       #ampo0+=-Estrength*fac1,"MuZ",Nsites
	                end
	        elseif polarization == "XY"
	                for i=1:Nsites
	                        ampo0+=-Estrength*fac1,"MuX",i
	                        ampo0+=-Estrength*fac1,"MuY",i
	                end
	        elseif polarization == "YZ"
	                for i=1:Nsites
	                        ampo0+=-Estrength*fac1,"MuY",i
	                        ampo0+=-Estrength*fac1,"MuZ",i
	                end
	        end

		H0 = MPO(ampo0,sites)
		
		#Define accuracy parameters#
		sweeps = Sweeps(Nsweep)
		#Set up initial state#
		global psi0 = randomMPS(sites,10)
		maxdim!(sweeps,1) # gradually increase states kept
		cutoff!(sweeps,dmrg_svd) # desired truncation error
		
		#Perform DMRG runs#
		obs = DemoObserver(e_cutoff)
		energy,psi = dmrg(H0,psi0,sweeps,observer=obs, outputlevel=0)
		
		global psi0 = psi
		
		f1=open("log","a")
		maxbond=maxlinkdim(psi)
		println(f1,"Max. bond dimension: ",maxbond)
		println(f1)
		@printf(f1,"Final energy = %.12f  cm^-1\n",energy*fac2)
		println(f1)
		println(f1,"Initial state calculated")
		println(f1,"###############################################################################")
		println(f1)
		close(f1)
		
		global initial_states = [psi0 for ii=1:Ntotal]
	end

	f1=open("log","a")
	println(f1)
	println(f1,"##################################################")
	println(f1,"######mu=",round(dipole,digits=5)," E=",round(Estrength*fac2,digits=5)," cm-1#########")
	println(f1,"##################################################")
	println(f1)
	close(f1)

        sites=siteinds(psi0)

	ampo = AutoMPO()
	ampoTot = AutoMPO()
	#Define Hamiltonian as MPO#
	f2=open("log","a")
	println(f2,"Construct MPO")
	close(f2)

	#Kinetic terms#
        for i=1:Nsites
                ampo += 1.0*fac1,"T",i
                ampoTot += 1.0*fac1,"T",i
        end

        #Upward potential terms#
        for i=1:2:Nsites-1
                for it=1:9
                        C=coeff_up[it]*dipole^2
                        for lambda=1:Nprod_up[it]
                                ampo += C[lambda]*fac1,string("V",it,"_",lambda),i,string("W",it,"_",lambda),i+1
                                ampoTot += C[lambda]*fac1,string("V",it,"_",lambda),i,string("W",it,"_",lambda),i+1
                        end
                end
        end

        #Downward potential terms#
        for i=2:2:Nsites-1
                for it=1:9
                        C=coeff_up[it]*dipole^2
                        for lambda=1:Nprod_down[it]
                                ampo += C[lambda]*fac1,string("A",it,"_",lambda),i,string("B",it,"_",lambda),i+1
                                ampoTot += C[lambda]*fac1,string("A",it,"_",lambda),i,string("B",it,"_",lambda),i+1
                        end
                end
        end

        if interaction == "next"
                #Next-nearest neighbour potential terms#
                ampoNNN1 = AutoMPO()
                for i=1:2:Nsites-2
                        for it=1:9
                                C=coeff_nnn[it]*dipole^2
                                for lambda=1:Nprod_nnn[it]
                                        ampoNNN1 += C[lambda]*fac1,string("C",it,"_",lambda),i,string("D",it,"_",lambda),i+2
                                        ampoTot += C[lambda]*fac1,string("C",it,"_",lambda),i,string("D",it,"_",lambda),i+2
                                end
                        end
                end
                H2 = MPO(ampoNNN1,sites)
                ampoNNN2 = AutoMPO()
	
		if Nsites > 3

		for i=2:2:Nsites-2
                        for it=1:9
                                C=coeff_nnn[it]*dipole^2
                                for lambda=1:Nprod_nnn[it]
                                        ampoNNN2 += C[lambda]*fac1,string("C",it,"_",lambda),i,string("D",it,"_",lambda),i+2
                                        ampoTot += C[lambda]*fac1,string("C",it,"_",lambda),i,string("D",it,"_",lambda),i+2
                                end
                        end
                end
                H3 = MPO(ampoNNN2,sites)
		end
        end

	#Add electrical field#
	if polarization == "no"

        elseif polarization == "X"
                for i=1:Nsites
                        ampo+=-Estrength*fac1,"MuX",i
                        ampoTot+=-Estrength*fac1,"MuX",i
                end
        elseif polarization == "Y"
                for i=1:Nsites
                        ampo+=-Estrength*fac1,"MuY",i
                        ampoTot+=-Estrength*fac1,"MuY",i
                end
        elseif polarization == "Z"
                for i=1:Nsites
                        ampo+=-Estrength*fac1,"MuZ",i
                        #ampo+=-Estrength*fac1,"MuZ",Nsites
                        ampoTot+=-Estrength*fac1,"MuZ",i
                        #ampoTot+=-Estrength*fac1,"MuZ",Nsites
                end
        elseif polarization == "XY"
                for i=1:Nsites
                        ampo+=-Estrength*fac1,"MuX",i
                        ampo+=-Estrength*fac1,"MuY",i
                        ampoTot+=-Estrength*fac1,"MuX",i
                        ampoTot+=-Estrength*fac1,"MuY",i
                end
        elseif polarization == "YZ"
                for i=1:Nsites
                        ampo+=-Estrength*fac1,"MuY",i
                        ampo+=-Estrength*fac1,"MuZ",i
                        ampoTot+=-Estrength*fac1,"MuY",i
                        ampoTot+=-Estrength*fac1,"MuZ",i
                end
        end

	H1 = MPO(ampo,sites)

	energies = []
	
	#Perform DMRG runs#
	f1=open("log","a")
	println(f1,"Start DMRG run")
	close(f1)
	sweeps = Sweeps(Nsweep)
	cutoff!(sweeps,dmrg_svd) # desired truncation error
	if idip == 0
	    #noise!(sweeps,1e-5,1e-5,1e-5,1e-8,1e-8,1e-8,1e-10)
	    maxdim!(sweeps,10,20,30,40,Nbond) # gradually increase states kept
	else
	    maxdim!(sweeps,maxlinkdim(initial_states[1]),Nbond) # gradually increase states kept
	end

	obs = DemoObserver(e_cutoff)
        if interaction == "next"
                if Nsites > 3
			energy,psi = dmrg([H1,H2,H3],initial_states[1],sweeps,observer=obs, outputlevel=0)
        	else
			energy,psi = dmrg([H1,H2],initial_states[1],sweeps,observer=obs, outputlevel=0)
		end
	elseif interaction == "nearest"
                energy,psi = dmrg(H1,initial_states[1],sweeps,observer=obs, outputlevel=0)
        end
	global initial_states[1] = psi

	append!(energies,energy)
	
	f1=open("log","a")
	println(f1)
	maxbond=maxlinkdim(psi)
	println(f1,"Max. bond dimension: ",maxbond)
       	println(f1)
	println(f1,"Final energy ground state= "*string(round(energy*fac2,digits=12))*"  cm^-1\n")
	println(f1)
	close(f1)

	global wavefunction = [psi for ii=1:Ntotal]

	if Ntotal > 1
                if interaction == "next"
                        Htot = MPO(ampoTot,sites)
                end
		for istates=1:Ntotal-1

			if idip == 0
				global initial_states[istates+1] = randomMPS(sites,Nbond)
				maxdim!(sweeps,10,20,30,40,Nbond) # gradually increase states kept
	    		else
				maxdim!(sweeps,maxlinkdim(initial_states[istates+1]),Nbond) # gradually increase states kept
			end

			#Define accuracy parameters#
		        #sweeps = Sweeps(Nsweep)
			#noise!(sweeps,1e-5,1e-5,1e-5,1e-8,1e-8,1e-8,1e-10)
		        cutoff!(sweeps,dmrg_svd) # desired truncation error
		
			
			#global psi0 = randomMPS(sites,10)
			
		
			#Perform DMRG runs#
			f1=open("log","a")
			println(f1,"Start DMRG run")
			close(f1)
			obs = DemoObserver(e_cutoff)
                        if interaction == "next"
                                energy ,psi = dmrg(Htot,wavefunction[1:istates],initial_states[istates+1] ,sweeps, observer=obs, outputlevel=0)
                        elseif interaction == "nearest"
                                energy ,psi = dmrg(H1,wavefunction[1:istates],initial_states[istates+1] ,sweeps, observer=obs, outputlevel=0)
                        end

			append!(energies,energy)
			global wavefunction[istates+1]=psi		
			global initial_states[istates+1]=psi		
			
			f1=open("log","a")
			println(f1)
			maxbond=maxlinkdim(psi)
			println(f1,"Max. bond dimension: ",maxbond)
		       	println(f1)
			println(f1,"Final energy "*string(istates)*". excited state= "*string(round(energy*fac2,digits=12))*"  cm^-1\n")
			println(f1)
			close(f1)
		end
	end
	text_energy=" "
	text_ent=" "
	text_xcorr=" "
	text_ycorr=" "
	text_zcorr=" "
	text_xcorr_c=" "
	text_ycorr_c=" "
	text_zcorr_c=" "
	text_mux=" "
	text_muy=" "
	text_muz=" "
	text_x=" "
	text_y=" "
	text_z=" "
	text_xavg=" "
	text_yavg=" "
	text_zavg=" "
	text_bx=" "
	text_by=" "
	text_bz=" "
	for istates=1:Ntotal
	
		#Calculate von-Neumann entropy and Schmidt coefficients#
		SvN, Svalues = vN_entropy(wavefunction[istates],mbond)

		text=" "
		for b=1:length(Svalues)
        		text*=string(Svalues[b]," ")
		end

		f1=open("schmidt_values_"*string(istates)*".txt","a")
		println(f1,round(dipole,digits=5),text)
		close(f1)
		
		#Calculate dipole correlations#
		xcorr,ycorr,zcorr,zorder,xcorr_c,ycorr_c,zcorr_c=dipole_correlation(wavefunction[istates],Nsites,Nstates,MuX,MuY,MuZ,MuZabs)
		
		#Calculate dipole components#
		mx,my,mz = dipole_fluctuation(wavefunction[istates],Nstates,MuX,MuY,MuZ)
	
		#Calculate COM correlations#
		xcom_corr,ycom_corr,zcom_corr=COM_correlation(wavefunction[istates],Nsites,Nstates,Xop,Yop,Zop)
	
		#Calculate COM expecation values per site#
		xavg,yavg,zavg = COM_averages(wavefunction[istates],Nstates,Xop,Yop,Zop)

		#Calculate binder parameters#
                bx,by,bz = binder(wavefunction[istates],Nstates,MuX,MuY,MuZ)


		#Calculate cos(theta) distribution#
		distT = get_ctheta_dist(wavefunction[istates],Nsites,Nstates,Ptheta)
		f1=open("ctheta_distribution_"*string(istates)*".txt","a")
		for it=1:Nangle
			text=" "
			for b=1:Nsites
        			text*=string(distT[b,it]," ")
			end
			println(f1,round(dipole,digits=5)," ",round(ctgrid2[it],digits=5)," ",text)
		end
		println(f1)
		println(f1)
		close(f1)
                #Calculate phi distribution#
                distP = get_phi_dist(wavefunction[istates],Nsites,Nstates,Pphi)
                f1=open("phi_distribution_"*string(istates)*".txt","a")
                for it=1:Nangle_phi
                        text=" "
                        for b=1:Nsites
                                text*=string(distP[b,it]," ")
                        end
                        println(f1,round(dipole,digits=5)," ",round(pgrid[it],digits=5)," ",text)
                end
                println(f1)
                println(f1)
                close(f1)

		#Calculate radial distribution#
		distR = get_R_dist(wavefunction[istates],Nsites,Nstates,PR)
		f1=open("radial_distribution_"*string(istates)*".txt","a")
		for ir=1:Nrad
			text=" "
			for b=1:Nsites
        			text*=string(distR[b,ir]," ")
			end
			println(f1,round(dipole,digits=5)," ",round(Rgrid[ir],digits=5)*a0toangst," ",text)
		end
		println(f1)
		println(f1)
		close(f1)


		#Calculate correlations of angular momenta#
		#Jxcorr,Jycorr,Jzcorr = angular_correlation(wavefunction[istates],Nstates,Nspec,Jx,Jy,Jz)
			
		text_energy*=string(energies[istates]*fac2," ")
		text_ent*=string(SvN," ")
		text_xcorr*=string(xcorr," ")
		text_ycorr*=string(ycorr," ")
		text_zcorr*=string(zcorr," ",zorder," ")
		text_xcorr_c*=string(xcorr_c," ")
		text_ycorr_c*=string(ycorr_c," ")
		text_zcorr_c*=string(zcorr_c," ")
		text_mux*=string(mx," ")
		text_muy*=string(my," ")
		text_muz*=string(mz," ")
		text_x*=string(xcom_corr," ")
		text_y*=string(ycom_corr," ")
		text_z*=string(zcom_corr," ")
		text_bx*=string(bx," ")
		text_by*=string(by," ")
		text_bz*=string(bz," ")

		for isites=1:Nsites
			text_xavg*=string(xavg[isites]," ")
			text_yavg*=string(yavg[isites]," ")
			text_zavg*=string(zavg[isites]," ")
		end
		#Write COM averages to file#
		fcx=open("xavg.txt","a")
		println(fcx,round(dipole,digits=5),"   ",text_xavg)
		close(fcx)
		
		fcy=open("yavg.txt","a")
		println(fcy,round(dipole,digits=5),"   ",text_yavg)
		close(fcy)

		fcz=open("zavg.txt","a")
		println(fcz,round(dipole,digits=5),"   ",text_zavg)
		close(fcz)
	end
	
	f1=open("energy.txt","a")
	println(f1,round(dipole,digits=5),text_energy)
	close(f1)

	f1=open("entropy.txt","a")
	println(f1,round(dipole,digits=5),text_ent)
	close(f1)

	#Write dipole correlations to file#
	fcx=open("muxcorr.txt","a")
	println(fcx,round(dipole,digits=5),"   ",text_xcorr)
	close(fcx)
	
	fcy=open("muycorr.txt","a")
	println(fcy,round(dipole,digits=5),"   ",text_ycorr)
	close(fcy)
	
	fcz=open("muzcorr.txt","a")
	println(fcz,round(dipole,digits=5),"   ",text_zcorr)
	close(fcz)

	fcx=open("muxcorr_center.txt","a")
	println(fcx,round(dipole,digits=5),"   ",text_xcorr_c)
	close(fcx)
	
	fcy=open("muycorr_center.txt","a")
	println(fcy,round(dipole,digits=5),"   ",text_ycorr_c)
	close(fcy)
	
	fcz=open("muzcorr_center.txt","a")
	println(fcz,round(dipole,digits=5),"   ",text_zcorr_c)
	close(fcz)

	#Write dipole components to file#
	fcx=open("mux.txt","a")
	println(fcx,round(dipole,digits=5),"   ",text_mux)
	close(fcx)
	
	fcy=open("muy.txt","a")
	println(fcy,round(dipole,digits=5),"   ",text_muy)
	close(fcy)
	
	fcz=open("muz.txt","a")
	println(fcz,round(dipole,digits=5),"   ",text_muz)
	close(fcz)

	#Write COM correlations to file#
	fcx=open("xcorr.txt","a")
	println(fcx,round(dipole,digits=5),"   ",text_x)
	close(fcx)
	
	fcy=open("ycorr.txt","a")
	println(fcy,round(dipole,digits=5),"   ",text_y)
	close(fcy)
	
	fcz=open("zcorr.txt","a")
	println(fcz,round(dipole,digits=5),"   ",text_z)
	close(fcz)

        #Write binder parameters to file#
        fcx=open("binder_x.txt","a")
        println(fcx,round(dipole,digits=5),"   ",text_bx)
        close(fcx)

        fcy=open("binder_y.txt","a")
        println(fcy,round(dipole,digits=5),"   ",text_by)
        close(fcy)

        fcz=open("binder_z.txt","a")
        println(fcz,round(dipole,digits=5),"   ",text_bz)
        close(fcz)	
end
end
f=open("log","a")
println(f,"Calculations finished.")
close(f)
