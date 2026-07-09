module expectation

using ITensors,ITensorMPS
using LinearAlgebra

export vN_entropy,entropy_block,dipole_correlation,dipole_fluctuation,COM_correlation,COM_averages,get_ctheta_dist,get_phi_dist,get_R_dist,binder
################################################################################
function vN_entropy(wf,mbond)

if length(wf) == 2
	orthogonalize!(wf, 2)
	U,S,V = svd(wf[2], (siteind(wf,2)))
else
	orthogonalize!(wf, mbond)
	U,S,V = svd(wf[mbond], (linkind(wf, mbond-1), siteind(wf,mbond)))
end
SvN = 0.0
schmidtvalues=zeros(dim(S, 1))
for n=1:dim(S, 1)
	p = S[n,n]^2
	schmidtvalues[n]=p
	SvN -= p * log(p)
end

return SvN,schmidtvalues
end
################################################################################
function entropy_block(psi,Nsites)

N=floor(Int,Nsites/2)
SvN=zeros(N)
for i=1:N
        wf=psi
        mbond=Nsites-i
        orthogonalize!(wf, mbond)
        U,S,V = svd(wf[mbond], (linkind(wf, mbond-1), siteind(wf,mbond)))
        dum=0.0
        for n=1:dim(S, 1)
                p = S[n,n]^2
                dum -= p * log(p)
        end
        SvN[i]=dum
end

return SvN
end
################################################################################
function COM_correlation(psi,Nsites,Nbasis,X,Y,Z)

global Xop=X
global Yop=Y
global Zop=Z
global Nstates=Nbasis

include("operators.jl")

sites=siteinds(psi)

#Calculate order parameter and correlation#
ampoX = AutoMPO()
ampoY = AutoMPO()
ampoZ = AutoMPO()

for i=1:Nsites-1
	#<sum(x_i x_i+1)>#
	ampoX += 1.0,"XCOM",i,"XCOM",i+1
	#<sum(y_i y_i+1)>#
	ampoY += 1.0,"YCOM",i,"YCOM",i+1
	#<sum(z_i z_i+1)>#
	ampoZ += 1.0,"ZCOM",i,"ZCOM",i+1
end

X_op = MPO(ampoX,sites)
Y_op = MPO(ampoY,sites)
Z_op = MPO(ampoZ,sites)


Xcorr=inner(psi,X_op,psi)
Ycorr=inner(psi,Y_op,psi)
Zcorr=inner(psi,Z_op,psi)

return real(Xcorr), real(Ycorr),real(Zcorr)
end
################################################################################
function dipole_correlation(psi,Nsites,Nbasis,X,Y,Z,Zabs)

global MuX=X
global MuY=Y
global MuZ=Z
global MuZabs=Zabs
global Nstates=Nbasis

include("operators.jl")

sites=siteinds(psi)

#Calculate order parameter and correlation#
ampoX = AutoMPO()
ampoY = AutoMPO()
ampoZ = AutoMPO()
ampoZ2 = AutoMPO()

for i=1:Nsites-1
	#<sum(x_i x_i+1)>#
	ampoX += 1.0,"MuX",i,"MuX",i+1
	#<sum(y_i y_i+1)>#
	ampoY += 1.0,"MuY",i,"MuY",i+1
	#<sum(z_i z_i+1)>#
	ampoZ += 1.0,"MuZ",i,"MuZ",i+1
	#<sum|z|>#
	ampoZ2 += 1.0,"MuZabs",i
end
ampoZ2 += 1.0,"MuZabs",Nsites

X_op = MPO(ampoX,sites)
Y_op = MPO(ampoY,sites)
Z_op = MPO(ampoZ,sites)
Z2_op = MPO(ampoZ2,sites)


Xcorr=inner(psi,X_op,psi)
Ycorr=inner(psi,Y_op,psi)
Zcorr=inner(psi,Z_op,psi)
Zorder=inner(psi,Z2_op,psi)

#Correlation center sites#
Ncenter = floor(Int64,Nsites/2)
ampoXc = AutoMPO()
ampoYc = AutoMPO()
ampoZc = AutoMPO()
ampoXc += 1.0,"MuX",Ncenter,"MuX",Ncenter+1
ampoYc += 1.0,"MuY",Ncenter,"MuY",Ncenter+1
ampoZc += 1.0,"MuZ",Ncenter,"MuZ",Ncenter+1

X_op_c = MPO(ampoXc,sites)
Y_op_c = MPO(ampoYc,sites)
Z_op_c = MPO(ampoZc,sites)

Xc=inner(psi,X_op_c,psi)
Yc=inner(psi,Y_op_c,psi)
Zc=inner(psi,Z_op_c,psi)

return real(Xcorr), real(Ycorr),real(Zcorr),real(Zorder),real(Xc),real(Yc),real(Zc)
end
################################################################################
function dipole_fluctuation(psi,Nbasis,X,Y,Z)

global MuX=X
global MuY=Y
global MuZ=Z
global Nstates=Nbasis

include("operators.jl")

#Calculate <O>#
dum = expect(psi,"MuX")
mux = sum(dum)
dum = expect(psi,"MuY")
muy = sum(dum)
dum = expect(psi,"MuZ")
muz = sum(dum)

return real(mux),real(muy),real(muz)
end
################################################################################
function COM_averages(psi,Nbasis,X,Y,Z)

global Xop=X
global Yop=Y
global Zop=Z
global Nstates=Nbasis

include("operators.jl")

#Calculate <O>#
xavg = expect(psi,"XCOM")
yavg = expect(psi,"YCOM")
zavg = expect(psi,"ZCOM")

return real(xavg),real(yavg),real(zavg)
end
################################################################################
function get_ctheta_dist(psi,Nsites,Nbasis,M)

Nangle = size(M,3)
global Nstates=Nbasis
global Ptheta = M

include("operators.jl")

ct_dist = zeros((Nsites,Nangle))

for it=1:Nangle
	dum= expect(psi,string("PT_",it))
	ct_dist[:,it] = dum
end

return ct_dist
end
################################################################################
function get_phi_dist(psi,Nsites,Nbasis,M)

Nangle = size(M,3)
global Nstates=Nbasis
global Pphi = M

include("operators.jl")

phi_dist = zeros((Nsites,Nangle))

for it=1:Nangle
        dum= expect(psi,string("PP_",it))
        phi_dist[:,it] = dum
end

return phi_dist
end
################################################################################
function get_R_dist(psi,Nsites,Nbasis,M)

NR = size(M,3)
global Nstates=Nbasis
global PR = M

include("operators.jl")

R_dist = zeros((Nsites,NR))

for it=1:NR
	dum= expect(psi,string("PR_",it))
	R_dist[:,it] = dum
end

return R_dist
end
################################################################################
function angular_correlation(psi,Nsites,Nbasis,X,Y,Z)

global Jx=X
global Jy=Y
global Jz=Z
global Nstates=Nbasis

include("operators.jl")

sites=siteinds(psi)
#center_site=Int(Nsites/2)

#Calculate order parameter and correlation#
ampoX = AutoMPO()
ampoY = AutoMPO()
ampoZ = AutoMPO()
#ampoX2 = AutoMPO()
#ampoY2 = AutoMPO()
#ampoZ2 = AutoMPO()

for i=1:Nsites-1
        #<sum(Jz_i Jz_i+1)>#
        ampoX += 1.0,"Jx",i,"Jx",i+1
        ampoY += 1.0,"Jy",i,"Jy",i+1
        ampoZ += 1.0,"Jz",i,"Jz",i+1
end
#ampoX2 += 1.0,"Jx",center_site,"Jx",center_site+1
#ampoY2 += 1.0,"Jy",center_site,"Jy",center_site+1
#ampoZ2 += 1.0,"Jz",center_site,"Jz",center_site+1

oper = MPO(ampoX,sites)
Jxcorr_sum=inner(psi,oper,psi)
#oper2 = MPO(ampoX2,sites)
#Jxcorr=inner(psi,oper2,psi)

oper = MPO(ampoY,sites)
Jycorr_sum=inner(psi,oper,psi)
#oper2 = MPO(ampoY2,sites)
#Jycorr=inner(psi,oper2,psi)

oper = MPO(ampoZ,sites)
Jzcorr_sum=inner(psi,oper,psi)
#oper2 = MPO(ampoZ2,sites)
#Jzcorr=inner(psi,oper2,psi)

return real(Jxcorr_sum),real(Jycorr_sum),real(Jzcorr_sum)#, real(Jxcorr),real(Jycorr),real(Jzcorr)
end
################################################################################
function angular_fluctuation(psi,Nsites,Nbasis,X,Y,Z)

global Jx=X
global Jy=Y
global Jz=Z
global Nstates=Nbasis

include("operators.jl")

sites=siteinds(psi)

#Calculate <|sum_i Jz_i|^2>#
#ampoZ = AutoMPO()
s1 = siteind(psi,1)
x = op("Jx",s1)
tmpX=apply(x,psi)
y = op("Jy",s1)
tmpY=apply(y,psi)
z = op("Jz",s1)
tmpZ=apply(z,psi)
for i=2:Nsites
        #ampoZ+=1.0,"Jz",i
        s1 = siteind(psi,i)
        x = op("Jx",s1)
        tmpX2=apply(x,psi)
        tmpX=tmpX+tmpX2

        y = op("Jy",s1)
        tmpY2=apply(y,psi)
        tmpY=tmpY+tmpY2

        z = op("Jz",s1)
        tmpZ2=apply(z,psi)
        tmpZ=tmpZ+tmpZ2
end
#Muz = MPO(ampoZ,sites)
#tmp=Muz*psi
Jx_avg = inner(psi,tmpX)
Jx2_avg = inner(tmpX,tmpX)
Jy_avg = inner(psi,tmpY)
Jy2_avg = inner(tmpY,tmpY)
Jz_avg = inner(psi,tmpZ)
Jz2_avg = inner(tmpZ,tmpZ)

return real(Jx_avg),real(Jx2_avg),real(Jy_avg),real(Jy2_avg),real(Jz_avg),real(Jz2_avg)
end
###############################################################################
function binder(psi,Nbasis,X,Y,Z)

global MuX=X
global MuY=Y
global MuZ=Z
global Nstates=Nbasis

include("operators.jl")


#Build O^2 operators#
Nsites = length(psi)
sites = siteinds(psi)

ampoX = AutoMPO()
ampoY = AutoMPO()
ampoZ = AutoMPO()

for i=1:Nsites
        ampoX += 1.0,"MuX",i
        ampoY += 1.0,"MuY",i
        ampoZ += 1.0,"MuZ",i
end

Mx = MPO(ampoX,sites)
My = MPO(ampoY,sites)
Mz = MPO(ampoZ,sites)

#M2*Psi#
MxPsi = replaceprime(contract(Mx, psi), 2 => 1)#apply(Mx,psi)
Mx2Psi = replaceprime(contract(Mx, MxPsi), 2 => 1)#apply(Mx,MxPsi)
MyPsi = replaceprime(contract(My, psi), 2 => 1)#apply(My,psi)
My2Psi = replaceprime(contract(My, MyPsi), 2 => 1)#apply(My,MyPsi)
MzPsi = replaceprime(contract(Mz, psi), 2 => 1)#apply(My,psi)
Mz2Psi = replaceprime(contract(Mz, MzPsi), 2 => 1)#apply(My,MyPsi)

#Expectation values#
Mx2 = real(inner(psi,Mx2Psi))
Mx4 = real(inner(Mx2Psi,Mx2Psi))

My2 = real(inner(psi,My2Psi))
My4 = real(inner(My2Psi,My2Psi))

Mz2 = real(inner(psi,Mz2Psi))
Mz4 = real(inner(Mz2Psi,Mz2Psi))

binderX = 1.0-Mx4/(3.0*Mx2^2)
binderY = 1.0-My4/(3.0*My2^2)
binderZ = 1.0-Mz4/(3.0*Mz2^2)

return binderX,binderY,binderZ
end
###############################################################################
end
