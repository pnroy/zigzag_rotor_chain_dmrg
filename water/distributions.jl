module distributions
__precompile__(false)   # local modules share names across run folders: never use the shared depot cache

using LinearAlgebra
using SpecialFunctions
using WignerSymbols
using AssociatedLegendrePolynomials
using ClassicalOrthogonalPolynomials: laguerrel
using GaussQuadrature: legendre 
push!(LOAD_PATH, @__DIR__)
using trans_real_complex
using potential
using spin


export XYZ_COM,RAlphaBeta,distro_R,distro_alpha,distro_ctheta,phi_distribution,chi_distribution

#################################################################################
function XYZ_COM(nmax,omega,mass,Utrans)

Ntrans = size(Utrans,2)

#Radial part#
MR = R_integral(Ntrans,nmax,omega,mass,1)

#Angular part#
Xmat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))
Ymat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))
Zmat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))

i1=0
for l1=0:nmax
for m1=-l1:l1
	i2=0	
	i1+=1
	for l2=0:nmax
	for m2=-l2:l2
		i2+=1
		wk=wigner3j(BigFloat,l1,1,l2,0,0,0)
		N=sqrt((2*l1+1)*(2*l2+1)*3/(4*pi))*(-1)^m1
		Y01 = N*wk*wigner3j(BigFloat,l1,1,l2,-m1,0,m2)
		Y11 = N*wk*wigner3j(BigFloat,l1,1,l2,-m1,1,m2)
		Ym11 = N*wk*wigner3j(BigFloat,l1,1,l2,-m1,-1,m2)
		Xmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = (Ym11-Y11)*sqrt(2.0*pi/3.0)
		Ymat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = (Ym11+Y11)*sqrt(2.0*pi/3.0)*im
		Zmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = Y01*2*sqrt(pi/3)
	end
	end
end
end

X = zeros(ComplexF64,(Ntrans,Ntrans))
Y = zeros(ComplexF64,(Ntrans,Ntrans))
Z = zeros(ComplexF64,(Ntrans,Ntrans))
i1=0
for n1=0:nmax
for l1=n1:-2:0
for m1=-l1:l1
	i1+=1
	i2=0
	for n2=0:nmax
	for l2=n2:-2:0
	for m2=-l2:l2
		i2+=1
		X[i1,i2] = MR[n1+1,n2+1,l1+1,l2+1]*Xmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
		Y[i1,i2] = MR[n1+1,n2+1,l1+1,l2+1]*Ymat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
		Z[i1,i2] = MR[n1+1,n2+1,l1+1,l2+1]*Zmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
	end
	end
	end
end
end
end

#Transform to real basis#
Xtrans = transform_realbasis(Utrans,X)
Ytrans = transform_realbasis(Utrans,Y)
Ztrans = transform_realbasis(Utrans,Z)


return Xtrans,Ytrans,Ztrans
end
#################################################################################
function RAlphaBeta(nmax,omega,mass,Utrans_trans)

Ntrans = size(Utrans_trans,2)

#Radial part#
MR0 = R_integral(Ntrans,nmax,omega,mass,0)
MR1 = R_integral(Ntrans,nmax,omega,mass,1)

#Angular part#
Ctmat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))
Pmat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))
Cpmat = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))
delta = zeros(ComplexF64,(nmax+1,nmax+1,2*nmax+1,2*nmax+1))

Ntheta = 200#2*nmax+1 
Utrans = Utl(nmax,Ntheta)

i1=0
for l1=0:nmax
for m1=-l1:l1
	i2=0	
	i1+=1
	for l2=0:nmax
	for m2=-l2:l2
		i2+=1
		wk=wigner3j(BigFloat,l1,1,l2,0,0,0)
		N=sqrt((2*l1+1)*(2*l2+1)*3/(4*pi))*(-1)^m1
		Y01 = N*wk*wigner3j(BigFloat,l1,1,l2,-m1,0,m2)
		Ctmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = Y01*2*sqrt(pi/3)
		#tmp = sum(Utrans[:,l1+1,nmax+1+m1].*Utrans[:,l2+1,nmax+1+m2])
		tmp=0.0
		for it=1:Ntheta
			tmp += Utrans[it,l1+1,nmax+1+m1]*Utrans[it,l2+1,nmax+1+m2]
		end

		if m1 == m2
			Im = pi
		else
			Im = im/(m1-m2)
		end
		if abs(m1-m2) == 1
			Im2 = 0.5
		else
			Im2 = 0.0
		end

		Pmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = Im*tmp
		Cpmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = Im2*tmp
		if l1 == l2 && m1 == m2
			delta[l1+1,l2+1,nmax+1+m1,nmax+1+m2] = 1.0
		end
	end
	end
end
end


R = zeros(ComplexF64,(Ntrans,Ntrans))
Ctheta = zeros(ComplexF64,(Ntrans,Ntrans))
Phi = zeros(ComplexF64,(Ntrans,Ntrans))
Cphi = zeros(ComplexF64,(Ntrans,Ntrans))

i1=0
for n1=0:nmax
for l1=n1:-2:0
for m1=-l1:l1
	i1+=1
	i2=0
	for n2=0:nmax
	for l2=n2:-2:0
	for m2=-l2:l2
		i2+=1
		R[i1,i2] = MR1[n1+1,n2+1,l1+1,l2+1]*delta[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
		Ctheta[i1,i2] = MR0[n1+1,n2+1,l1+1,l2+1]*Ctmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
		Phi[i1,i2] = MR0[n1+1,n2+1,l1+1,l2+1]*Pmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
		Cphi[i1,i2] = MR0[n1+1,n2+1,l1+1,l2+1]*Cpmat[l1+1,l2+1,nmax+1+m1,nmax+1+m2]
	end
	end
	end
end
end
end

#Transform to real basis#
Rtrans = transform_realbasis(Utrans_trans,R)
Cttrans = transform_realbasis(Utrans_trans,Ctheta)
Ptrans = transform_realbasis(Utrans_trans,Phi)
Cptrans = transform_realbasis(Utrans_trans,Cphi)


return Rtrans,Cttrans,Cptrans,Ptrans
end
#################################################################################
function distro_R(nmax,omega,mass,Utrans)

Ntrans = size(Utrans,2)

nu=mass*omega*0.5

a0toangst=0.529177210903 #Bohr to angstrom

R = [0.0 + ir*0.01 for ir=1:50]
R /=a0toangst
NR = length(R)

MR = zeros(ComplexF64,(Ntrans,Ntrans,NR))
i1=0
for n1=0:nmax
for l1=n1:-2:0
	k1 = Int((n1-l1)/2)
	Nkl1 = laguerre_normalization(k1,l1,nu)
for m1=-l1:l1
	i1+=1
	i2=0
	for n2=0:nmax
	for l2=n2:-2:0
		k2 = Int((n2-l2)/2)
		Nkl2 = laguerre_normalization(k2,l2,nu)
	for m2=-l2:l2
		i2+=1
		if l1 == l2 && m1 == m2
			for ir=1:NR
				MR[i1,i2,ir] = Nkl1*Nkl2*(R[ir]^(l1+l2+2))*laguerrel(k1,l1+0.5,2*nu*R[ir]^2)*laguerrel(k2,l2+0.5,2*nu*R[ir]^2)*exp(-2*nu*R[ir]^2)
			end
		end
	end
	end
	end
end
end
end

#Transform to real basis#
MRtrans = zeros(Float64,(Ntrans,Ntrans,NR))
for ir=1:NR
	MRtrans[:,:,ir] = transform_realbasis(Utrans,MR[:,:,ir])
end

return MRtrans,R
end
#################################################################################
function distro_alpha(nmax,omega,mass,Utrans)

Ntrans = size(Utrans,2)

nu=mass*omega*0.5
Nalpha = 90

ctheta, ct_weight = legendre(Nalpha)

Pleg = zeros(nmax+1,2*nmax+1,Nalpha)
for l=0:nmax
for m=-l:l
	Pleg[l+1,nmax+1+m,:] = Legpoly(ctheta,l,m)
end
end

MR = R_integral(Ntrans,nmax,omega,mass,0)

Malpha = zeros(ComplexF64,(Ntrans,Ntrans,Nalpha))
i1=0
for n1=0:nmax
for l1=n1:-2:0
	k1 = Int((n1-l1)/2)
	#Nkl1 = laguerre_normalization(k1,l1,nu)
for m1=-l1:l1
	i1+=1
	i2=0
	for n2=0:nmax
	for l2=n2:-2:0
		k2 = Int((n2-l2)/2)
		#Nkl2 = laguerre_normalization(k2,l2,nu)
	for m2=-l2:l2
		i2+=1
		if m1 == m2
			for it=1:Nalpha
				Malpha[i1,i2,it] = MR[n1+1,n2+1,l1+1,l2+1]*Pleg[l1+1,nmax+1+m1,it]*Pleg[l2+1,nmax+1+m2,it] 
			end
		end
	end
	end
	end
end
end
end

#Transform to real basis#
Malphatrans = zeros(Float64,(Ntrans,Ntrans,Nalpha))
for it=1:Nalpha
	Malphatrans[:,:,it] = transform_realbasis(Utrans,Malpha[:,:,it])
end

return Malphatrans,ctheta
end
#################################################################################
function distro_ctheta(isomer,Nspin,jmax,Utrans)

Nrot=0
for j=0:jmax
	Nrot+=(2*j+1)^2
end

Nangle=90
ctheta, ct_weight = legendre(Nangle)


djmk = zeros(Float64,(Nrot,Nangle))
ii=0
for j=0:jmax
for m=-j:j
for k=-j:j
	ii+=1
	djmk[ii,:] = wigner_dmatrix(j,m,k,ctheta,Nangle).*sqrt(2*j+1)
end
end
end	


dd = zeros(ComplexF64,(Nrot,Nrot,Nangle))
ii=0
for j1=0:jmax
for m1=-j1:j1
for k1=-j1:j1
	ii+=1
	d1=djmk[ii,:]
	jj=0
	for j2=0:jmax
	for m2=-j2:j2
	for k2=-j2:j2
		jj+=1
		if m1 == m2 && k1 == k2
			dd[ii,jj,:] = 0.5*d1.*djmk[jj,:]
		end
	end
	end
	end 
end
end
end

Pangle=zeros(Float64,(Nspin,Nspin,Nangle))
for it=1:Nangle
	tmp = spin_isomer(isomer,jmax,dd[:,:,it])
	Pangle[:,:,it] = transform_realbasis(Utrans,tmp)
end

return Pangle,ctheta
end
#################################################################################
function phi_distribution(isomer,Nspin,jmax,Urot)

Nrot=0
for j=0:jmax
        Nrot+=(2*j+1)^2
end

Nangle=90

Nalpha = 2*jmax #much larger than necessary

phi=zeros(Nangle)
for i=1:Nangle
        phi[i]=(i-1)*2.0*pi/Nangle
end

expo = zeros(ComplexF64,(2*jmax+1,2*jmax+1,Nangle))

for m1=-jmax:jmax
for m2=-jmax:jmax
        for ip=1:Nangle
                expo[jmax+1+m1,jmax+1+m2,ip] = exp(-im*(m2-m1)*phi[ip])
        end
end
end

Utrans = Utj(Nalpha,jmax,jmax,jmax)

dist = zeros(ComplexF64,(Nrot,Nrot,Nangle))
ii=0
for j1=0:jmax
for m1=-j1:j1
for k1=-j1:j1
        ii+=1
        jj=0
        for j2=0:jmax
        for m2=-j2:j2
        for k2=-j2:j2
                jj+=1
                if k1 == k2
                        tmp=BLAS.gemm('T','N', Utrans[:,:,jmax+1+m1,jmax+1+k1],Utrans[:,:,jmax+1+m2,jmax+1+k2])
                        dist[ii,jj,:] = tmp[j1+1,j2+1]*expo[jmax+1+m1,jmax+1+m2,:]
                end
        end
        end
        end
end
end
end

Pangle=zeros(Float64,(Nspin,Nspin,Nangle))
for it=1:Nangle
        tmp = spin_isomer(isomer,jmax,dist[:,:,it])
        Pangle[:,:,it] = transform_realbasis(Urot,tmp)
end

return Pangle*0.5/pi,phi
end
#################################################################################
function chi_distribution(isomer,Nspin,jmax,Urot)

Nrot=0
for j=0:jmax
        Nrot+=(2*j+1)^2
end

Nangle=90

Nalpha = 2*jmax #much larger than necessary

chi=zeros(Nangle)
for i=1:Nangle
        chi[i]=(i-1)*2.0*pi/Nangle
end

expo = zeros(ComplexF64,(2*jmax+1,2*jmax+1,Nangle))

for k1=-jmax:jmax
for k2=-jmax:jmax
        for ic=1:Nangle
                expo[jmax+1+k1,jmax+1+k2,ic] = exp(-im*(k2-k1)*chi[ic])
        end
end
end

Utrans = Utj(Nalpha,jmax,jmax,jmax)

dist = zeros(ComplexF64,(Nrot,Nrot,Nangle))
ii=0
for j1=0:jmax
for m1=-j1:j1
for k1=-j1:j1
        ii+=1
        jj=0
        for j2=0:jmax
        for m2=-j2:j2
        for k2=-j2:j2
                jj+=1
                if m1 == m2
                        tmp=BLAS.gemm('T','N', Utrans[:,:,jmax+1+m1,jmax+1+k1],Utrans[:,:,jmax+1+m2,jmax+1+k2])
                        dist[ii,jj,:] = tmp[j1+1,j2+1]*expo[jmax+1+k1,jmax+1+k2,:]
                end
        end
        end
        end
end
end
end

Pangle=zeros(Float64,(Nspin,Nspin,Nangle))
for it=1:Nangle
        tmp = spin_isomer(isomer,jmax,dist[:,:,it])
        Pangle[:,:,it] = transform_realbasis(Urot,tmp)
end

return Pangle*0.5/pi,chi
end
#################################################################################
function R_integral(Nspec,nmax,omega,mass,order)

lmax = nmax
if mod(nmax,2) == 0
	kmax = Int(nmax/2)
elseif mod(nmax,2) == 1
	kmax = Int((nmax-1)/2)
end

nu=mass*omega*0.5

integral=zeros(kmax+1,kmax+1,lmax+1,lmax+1)

for k1=0:kmax
for k2=0:kmax
	for l1=0:lmax
	for l2=0:lmax
		tau = k1-k2
		m = 0.5*(l1+l2+order+1)
		alpha1 = l1+0.5
		alpha2 = l2+0.5
		dum = 0.0
		if tau >= 0
			for sigma=0:k2
				dum+=binom_general(m-alpha1,tau+sigma)*binom_general(m-alpha2,sigma)*gamma(m+k2-sigma+1)/factorial(k2-sigma)
			end
		else
			for sigma=0:k1
				dum+=binom_general(m-alpha2,abs(tau)+sigma)*binom_general(m-alpha1,sigma)*gamma(m+k1-sigma+1)/factorial(k1-sigma)
			end
		end	
		dum=dum*((-1)^(k1+k2))/(4*nu*(2*nu)^m)
		integral[k1+1,k2+1,l1+1,l2+1]=dum*laguerre_normalization(k1,l1,nu)*laguerre_normalization(k2,l2,nu)
	end
	end
	
	for l1=0:lmax
	for l2=0:lmax
		integral[k2+1,k1+1,l1+1,l2+1]=integral[k1+1,k2+1,l2+1,l1+1]
	end
	end
end
end

int_out = zeros(ComplexF64,(nmax+1,nmax+1,lmax+1,lmax+1))
for n1=0:nmax
for l1=n1:-2:0
	k1 = Int((n1-l1)/2)
	for n2=0:nmax
	for l2=n2:-2:0
		k2 = Int((n2-l2)/2)
		int_out[n1+1,n2+1,l1+1,l2+1] = integral[k1+1,k2+1,l1+1,l2+1]
	end	
	end	
end	
end	

return int_out
end
##############################################################################################################
function Utl(nmax,Ntheta)

Utrans = zeros((Ntheta,nmax+1,2*nmax+1))

ctheta, ct_weight = legendre(Ntheta)

for l=0:nmax
	for m=-l:-1
		norm = legendre_normalization(l,m)
		for it=1:Ntheta
			Utrans[it,l+1,nmax+1+m] = (-1.0)^(abs(m))*(factorial(l-abs(m))/factorial(l+abs(m)))*Plm(l,abs(m),ctheta[it])*sqrt(ct_weight[it])*norm
		end
	end
	for m=0:l
		norm = legendre_normalization(l,m)
		for it=1:Ntheta
			Utrans[it,l+1,nmax+1+m] = Plm(l,m,ctheta[it])*sqrt(ct_weight[it])*norm
		end
	end


end

return Utrans
end
##############################################################################################################
function Legpoly(ctheta,l,m)

Ntheta = length(ctheta)
Pleg = zeros(Ntheta)

if m < 0
	#norm = legendre_normalization(l,m)
	for it=1:Ntheta
		Pleg[it] = (-1.0)^(abs(m))*(factorial(l-abs(m))/factorial(l+abs(m)))*Plm(l,abs(m),ctheta[it])#*norm
	end
else
	#norm = legendre_normalization(l,m)
	for it=1:Ntheta
		Pleg[it] = Plm(l,m,ctheta[it])#*norm
	end
end

return Pleg
end
##############################################################################################################
function laguerre_normalization(k,l,nu)

norm = sqrt(sqrt((2*nu^3)/pi)*(2^(k+2*l+3)*factorial(k)*nu^(l)/dfactorial(2*k+2*l+1)))

return norm
end
##############################################################################################################
function dfactorial(n)

if mod(n,2) == 0
	Nfac = Int(n/2)
elseif mod(n,2) == 1
	Nfac = Int((n+1)/2)
end

fac = 1.0
for ii=0:Nfac-1
	fac*=(n-2*ii)
end

return fac
end
##############################################################################################################
function binom_general(n,k)

num=1.0
for ii=0:k-1
	num*=(n-ii)
end
num/=factorial(k)

return num
end
#################################################################################
function legendre_normalization(l,m)

norm = sqrt(0.5*(2*l+1)*factorial(l-m)/factorial(l+m))
#norm = norm*(-1)^m	#Condon-Shortley phase factor not required, in the definition of Plm

return norm
end
#################################################################################
end
