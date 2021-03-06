### A Pluto.jl notebook ###
# v0.12.17

using Markdown
using InteractiveUtils

# ╔═╡ 49630972-4192-11eb-3dd3-c14371066e1a
begin
	using Markdown
	using InteractiveUtils
	using LinearAlgebra
end

# ╔═╡ 54ef1f40-4192-11eb-3e9d-1b8d62a4d99f
begin
    using PlutoUI
    using Plots
    using Printf
    using Interact
end

# ╔═╡ 3a43bac0-4192-11eb-30c2-e1c845f3e7bb
md"_Compressible Similarity, version 1_"

# ╔═╡ 4072d430-4192-11eb-15ad-d551a4cc6523
md"""

## **Compressible Similarity Solution** 

#### **Description:**

This notebook computes the compressible version of Falkner-Skan Similarity Solution coupled with energy equation

		selfsimilar(M∞, T∞, ηmax, N, itermax, ϵProfile, ϵBC)

If the arguments are missing, it will use the default values.
    
		selfsimilar(M∞=1, T∞=300, ηmax=10, N=50, itermax=40, ϵProfile=1e-6, ϵBC=1e-6)

#### **Compressible Similarity Equation**
Boundary-layer velocity and temperature profiles on the flat plate can be projected onto single profile wich is self-similar profile. It can be represented using the ordinary differential equations (ODEs) below:

$$(cf'')'+ff'' =0$$
$$(a_1g'+a_2f'f'')'+fg'=0$$
    
where 

$$f'=\frac{u}{u_e}$$
$$c=\frac{\rho \mu}{\rho_e \mu_e}$$
$$g=\frac{H}{H_e}$$ 
$$a_1=\frac{c}{\sigma}$$
$$a_2=\frac{(\gamma-1)M^2}{1+(\frac{\gamma-1}{2})M^2}\left(1-\frac{1}{\sigma}\right)c$$


and H is the enthalpy, γ is the ratio of specific heats, M is the edge Mach number, and σ is the Prandtl number. σ and M can be defined as

$$M=\frac{u_e}{\sqrt{\gamma \mathfrak{R}T_e}}$$
$$\sigma=\frac{\mu c_p}{k}$$
    
In this code, σ is assumed as 0.72. The viscosity μ is a function of T and it is calculated as

\begin{equation}
    μ = c₁\frac{T^{3/2}}{T+c₂}    
\end{equation}

c₂ is 110.4 Kelvin. c₁ is disappearing on the nondimensionalizing process. The boundary conditions for the system of ODEs are
    
$$y=0;  f=f'=0$$
$$y\rightarrow \infty;  f',g \rightarrow 0$$

The resultant equations along with the boundary conditions are solved with the Runge-Kutta Fehlberg scheme with Newton's iteration method for missing boundary condition.

Details of RK Fehlberg:
Numerical Recipes, Cambridge

Details of Similarity solution formulation:
Boundary-Layer Theory, 7ᵗʰ edition, Schlichting

Feel free to ask questions!

*Furkan Oz*

foz@okstate.edu
"""

# ╔═╡ 5b66da70-4192-11eb-3e5a-051e2c64153f
function Y1(η,y₁,y₂,y₃,y₄,y₅)
    return y₂
end

# ╔═╡ 5fff2740-4192-11eb-39b5-11f529ae8fa1
function Y2(η,y₁,y₂,y₃,y₄,y₅)
    return y₃
end

# ╔═╡ 64d910ee-4192-11eb-30ff-b730c8610bd9
function Y3(η,y₁,y₂,y₃,y₄,y₅,cμ,T∞)
    return -y₃*((y₅/(2*(y₄)))-(y₅/(y₄+cμ/T∞)))-y₁*y₃*((y₄+cμ/T∞)/(sqrt(y₄)*(1+cμ/T∞)));
end

# ╔═╡ 6a635ee0-4192-11eb-3d15-79ce34aa522b
function Y4(η,y₁,y₂,y₃,y₄,y₅)
    return y₅
end

# ╔═╡ 6ed84530-4192-11eb-2c32-9fd8d5c0684e
function Y5(η,y₁,y₂,y₃,y₄,y₅,cμ,T∞,Pr,γ,M∞)
    return -y₅^2*((0.5/y₄)-(1/(y₄+cμ/T∞)))-Pr*y₁*y₅/sqrt(y₄)*(y₄+cμ/T∞)/(1+cμ/T∞)-(γ-1)*Pr*M∞^2*y₃^2;
end

# ╔═╡ 564b53e0-4192-11eb-33c2-717cb09752bf
"""
Computes the compressible Similarity Solution
This notebook computes the compressible Similarity Solution

		selfsimilar(M∞, T∞, ηmax, N, itermax, ϵProfile, ϵBC)

If the arguments are missing, it will use the default values.
    
		selfsimilar(M∞=1, T∞=300, ηmax=10, N=50, itermax=40, ϵProfile=1e-6, ϵBC=1e-6)

Furkan Oz,
foz@okstate.edu, 
    
"""
function selfsimilar(M∞=1, T∞=300, ηmax=10, N=50, itermax=40, ϵProfile=1e-6, ϵBC=1e-6)
    Δη = ηmax/N
    Δη²= Δη^2
    γ  = 1.4   # Ratio of specific heat
    cμ = 110.4 # Sutherland law coefficient for [Kelvin]
    Pr = 0.72  # Prandtl Number
    
    Δ = 1e-7     # Small number for shooting method (Decrease when ϵ is decreased)

    # Initializing the solution vectors
    y₁ = zeros(N+1)   # f
    y₂ = zeros(N+1)   # f'
    y₃ = zeros(N+1)   # f''
    y₄ = zeros(N+1)   # ρ(η)
    y₅ = zeros(N+1)   # ρ(η)'
    η = [(i-1)*Δη for i=1:N+1]

    # Boundary Conditions for Isothermal Case
    y₁[1] = 0
    y₂[1] = 0
    y₅[1] = 0

    α₀ = 0.1 	  # Change that if code does not converge
    β₀ = 3.0      # Change that if code does not converge
    y₃[1] = α₀    # Initial Guess
    y₄[1] = β₀    # Initial Guess
    
    # We want
    # y2[N+1] = 1
    # y4[N+1] = 1
    
	# RK Fehlberg Coefficients see reference for details
    b₂ = 0.2; b₃ = 0.3; 
    b₄ = 0.6; b₅ = 1.0; b₆ = 7.0/8.0;
    a₂₁= 0.2; 
    a₃₁= 3.0/40.0; a₃₂= 9.0/40.0;
    a₄₁= 0.3; a₄₂=-0.9; a₄₃= 6.0/5.0;
    a₅₁=-11.0/54.0;a₅₂= 2.5;  a₅₃=-70.0/27.0; a₅₄= 35.0/27.0;
    a₆₁= 1631.0/55296.0; a₆₂= 175.0/512.0; a₆₃= 575.0/13824.0; 
	a₆₄= 44275.0/110592.0; a₆₅= 253.0/4096.0;
    c₁ = 37.0/378.0; c₂ = 0; c₃ = 250.0/621.0; c₄ = 125.0/594.0;
    c₅ = 0; c₆ = 512.0/1771.0; 
    
    iter = 0
    errorProfile = 1.
    errorBC = 1.
    normₒ = 0
    normₙ = 0
    
    while ϵProfile<=errorProfile && iter<itermax
        y₃[1] = α₀;    # Initial Guess
        y₄[1] = β₀;    # Initial Guess
        
		# First solution for Newton's iteration
        for i=1:N
            
            w₁ = Y5(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞,Pr,γ,M∞);
            w₂ = Y5(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₂₁*w₁),cμ,T∞,Pr,γ,M∞);
            w₃ = Y5(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₃₁*w₁+a₃₂*w₂),cμ,T∞,Pr,γ,M∞);
            w₄ = Y5(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃),cμ,T∞,Pr,γ,M∞);
            w₅ = Y5(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄),cμ,T∞,Pr,γ,M∞);
            w₆ = Y5(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅),cμ,T∞,Pr,γ,M∞);

            y₅[i+1] = y₅[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 
            
            w₁ = Y4(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y4(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₂₁*w₁), y₅[i]);
            w₃ = Y4(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₅[i]);
            w₄ = Y4(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₅[i]);
            w₅ = Y4(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₅[i]);
            w₆ = Y4(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₅[i]);

            y₄[i+1] = y₄[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y3(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞);
            w₂ = Y3(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i]+Δη*(a₂₁*w₁), y₄[i], y₅[i],cμ,T∞);
            w₃ = Y3(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₄[i], y₅[i],cμ,T∞);
            w₄ = Y3(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₄[i], y₅[i],cμ,T∞);
            w₅ = Y3(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₄[i], y₅[i],cμ,T∞);
            w₆ = Y3(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₄[i], y₅[i],cμ,T∞);

            y₃[i+1] = y₃[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 

            w₁ = Y2(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y2(η[i]+Δη*b₂, y₁[i], y₂[i]+Δη*(a₂₁*w₁), y₃[i], y₄[i], y₅[i]);
            w₃ = Y2(η[i]+Δη*b₃, y₁[i], y₂[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₃[i], y₄[i], y₅[i]);
            w₄ = Y2(η[i]+Δη*b₄, y₁[i], y₂[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₃[i], y₄[i], y₅[i]);
            w₅ = Y2(η[i]+Δη*b₅, y₁[i], y₂[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₃[i], y₄[i], y₅[i]);
            w₆ = Y2(η[i]+Δη*b₆, y₁[i], y₂[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₃[i], y₄[i], y₅[i]);

            y₂[i+1] = y₂[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y1(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y1(η[i]+Δη*b₂, y₁[i]+Δη*(a₂₁*w₁), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₃ = Y1(η[i]+Δη*b₃, y₁[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₄ = Y1(η[i]+Δη*b₄, y₁[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₅ = Y1(η[i]+Δη*b₅, y₁[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₆ = Y1(η[i]+Δη*b₆, y₁[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₂[i], y₃[i], y₄[i], y₅[i]);

            y₁[i+1] = y₁[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

        end
        
        # Storing the freestream values for Newton's iteration method
        y₂ₒ = y₂[N+1];
        y₄ₒ = y₄[N+1];
        
        # Small number addition for Newton's iteration method
        y₃[1] = α₀+Δ;  # Initial Guess + Small number
        y₄[1] = β₀;    # Initial Guess
        
		# Second solution for Newton's iteration
        for i=1:N
            
            w₁ = Y5(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞,Pr,γ,M∞);
            w₂ = Y5(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₂₁*w₁),cμ,T∞,Pr,γ,M∞);
            w₃ = Y5(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₃₁*w₁+a₃₂*w₂),cμ,T∞,Pr,γ,M∞);
            w₄ = Y5(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃),cμ,T∞,Pr,γ,M∞);
            w₅ = Y5(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄),cμ,T∞,Pr,γ,M∞);
            w₆ = Y5(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅),cμ,T∞,Pr,γ,M∞);

            y₅[i+1] = y₅[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 

            w₁ = Y4(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y4(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₂₁*w₁), y₅[i]);
            w₃ = Y4(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₅[i]);
            w₄ = Y4(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₅[i]);
            w₅ = Y4(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₅[i]);
            w₆ = Y4(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₅[i]);

            y₄[i+1] = y₄[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y3(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞);
            w₂ = Y3(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i]+Δη*(a₂₁*w₁), y₄[i], y₅[i],cμ,T∞);
            w₃ = Y3(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₄[i], y₅[i],cμ,T∞);
            w₄ = Y3(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₄[i], y₅[i],cμ,T∞);
            w₅ = Y3(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₄[i], y₅[i],cμ,T∞);
            w₆ = Y3(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₄[i], y₅[i],cμ,T∞);

            y₃[i+1] = y₃[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 

            w₁ = Y2(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y2(η[i]+Δη*b₂, y₁[i], y₂[i]+Δη*(a₂₁*w₁), y₃[i], y₄[i], y₅[i]);
            w₃ = Y2(η[i]+Δη*b₃, y₁[i], y₂[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₃[i], y₄[i], y₅[i]);
            w₄ = Y2(η[i]+Δη*b₄, y₁[i], y₂[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₃[i], y₄[i], y₅[i]);
            w₅ = Y2(η[i]+Δη*b₅, y₁[i], y₂[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₃[i], y₄[i], y₅[i]);
            w₆ = Y2(η[i]+Δη*b₆, y₁[i], y₂[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₃[i], y₄[i], y₅[i]);

            y₂[i+1] = y₂[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y1(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y1(η[i]+Δη*b₂, y₁[i]+Δη*(a₂₁*w₁), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₃ = Y1(η[i]+Δη*b₃, y₁[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₄ = Y1(η[i]+Δη*b₄, y₁[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₅ = Y1(η[i]+Δη*b₅, y₁[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₆ = Y1(η[i]+Δη*b₆, y₁[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₂[i], y₃[i], y₄[i], y₅[i]);

            y₁[i+1] = y₁[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

        end
        
        # Storing the freestream values for Newton's iteration method
        y₂ₙ₁ = y₂[N+1];
        y₄ₙ₁ = y₄[N+1];
        
        # Small number addition for Newton's iteration method
        y₃[1] = α₀;    # Initial Guess
        y₄[1] = β₀+Δ;  # Initial Guess + Small number
        
		# Third solution for Newton's iteration
        for i=1:N
            
            w₁ = Y5(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞,Pr,γ,M∞);
            w₂ = Y5(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₂₁*w₁),cμ,T∞,Pr,γ,M∞);
            w₃ = Y5(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₃₁*w₁+a₃₂*w₂),cμ,T∞,Pr,γ,M∞);
            w₄ = Y5(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃),cμ,T∞,Pr,γ,M∞);
            w₅ = Y5(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄),cμ,T∞,Pr,γ,M∞);
            w₆ = Y5(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅),cμ,T∞,Pr,γ,M∞);

            y₅[i+1] = y₅[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 

            w₁ = Y4(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y4(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₂₁*w₁), y₅[i]);
            w₃ = Y4(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₅[i]);
            w₄ = Y4(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₅[i]);
            w₅ = Y4(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₅[i]);
            w₆ = Y4(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i], y₄[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₅[i]);

            y₄[i+1] = y₄[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y3(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i],cμ,T∞);
            w₂ = Y3(η[i]+Δη*b₂, y₁[i], y₂[i], y₃[i]+Δη*(a₂₁*w₁), y₄[i], y₅[i],cμ,T∞);
            w₃ = Y3(η[i]+Δη*b₃, y₁[i], y₂[i], y₃[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₄[i], y₅[i],cμ,T∞);
            w₄ = Y3(η[i]+Δη*b₄, y₁[i], y₂[i], y₃[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₄[i], y₅[i],cμ,T∞);
            w₅ = Y3(η[i]+Δη*b₅, y₁[i], y₂[i], y₃[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₄[i], y₅[i],cμ,T∞);
            w₆ = Y3(η[i]+Δη*b₆, y₁[i], y₂[i], y₃[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₄[i], y₅[i],cμ,T∞);

            y₃[i+1] = y₃[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆); 

            w₁ = Y2(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y2(η[i]+Δη*b₂, y₁[i], y₂[i]+Δη*(a₂₁*w₁), y₃[i], y₄[i], y₅[i]);
            w₃ = Y2(η[i]+Δη*b₃, y₁[i], y₂[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₃[i], y₄[i], y₅[i]);
            w₄ = Y2(η[i]+Δη*b₄, y₁[i], y₂[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₃[i], y₄[i], y₅[i]);
            w₅ = Y2(η[i]+Δη*b₅, y₁[i], y₂[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₃[i], y₄[i], y₅[i]);
            w₆ = Y2(η[i]+Δη*b₆, y₁[i], y₂[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₃[i], y₄[i], y₅[i]);

            y₂[i+1] = y₂[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

            w₁ = Y1(η[i], y₁[i], y₂[i], y₃[i], y₄[i], y₅[i]);
            w₂ = Y1(η[i]+Δη*b₂, y₁[i]+Δη*(a₂₁*w₁), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₃ = Y1(η[i]+Δη*b₃, y₁[i]+Δη*(a₃₁*w₁+a₃₂*w₂), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₄ = Y1(η[i]+Δη*b₄, y₁[i]+Δη*(a₄₁*w₁+a₄₂*w₂+a₄₃*w₃), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₅ = Y1(η[i]+Δη*b₅, y₁[i]+Δη*(a₅₁*w₁+a₅₂*w₂+a₅₃*w₃+a₅₄*w₄), y₂[i], y₃[i], y₄[i], y₅[i]);
            w₆ = Y1(η[i]+Δη*b₆, y₁[i]+Δη*(a₆₁*w₁+a₆₂*w₂+a₆₃*w₃+a₆₄*w₄+a₆₅*w₅), y₂[i], y₃[i], y₄[i], y₅[i]);

            y₁[i+1] = y₁[i] + Δη*(c₁*w₁+c₂*w₂+c₃*w₃+c₄*w₄+c₅*w₅+c₆*w₆);

        end
        
        # Storing the freestream values for Newton's iteration method
        y₂ₙ₂ = y₂[N+1];
        y₄ₙ₂ = y₄[N+1];

        # Calculation of the next initial guess with Newton's iteration method
        p₁₁ = (y₂ₙ₁-y₂ₒ)/Δ;
        p₂₁ = (y₄ₙ₁-y₄ₒ)/Δ;
        p₁₂ = (y₂ₙ₂-y₂ₒ)/Δ;
        p₂₂ = (y₄ₙ₂-y₄ₒ)/Δ;
        r₁ = 1-y₂ₒ;
        r₂ = 1-y₄ₒ;
        Δα = (p₂₂*r₁-p₁₂*r₂)/(p₁₁*p₂₂-p₁₂*p₂₁);
        Δβ = (p₁₁*r₂-p₂₁*r₁)/(p₁₁*p₂₂-p₁₂*p₂₁);
        α₀ = α₀ + Δα;
        β₀ = β₀ + Δβ;
        
        # Profile change between iteration
        normₙ = norm(y₂)
        errorProfile = maximum(abs.(normₙ-normₒ))
		
		# Convergence of boundary condition
        errorBC = abs(y₂[N+1]-1.)
        iter += 1
        normₒ = normₙ
        @printf("%4.4d %16.6e %16.6e \n", iter, errorProfile, errorBC)
        
    end
    
    if errorProfile<=ϵProfile 
        println("")
        println("Solution converged!")
        println("The maximum change between consecutive profiles is less than the error criteria ϵProfile=$ϵProfile.")
    end

    if errorBC<=ϵBC
        println("")
        println("Solution for the boundary condition converged!")
        println("The difference between h(N) and h(N+1) is less than the error criteria ϵBC=$ϵBC.")
    end
    
	# Copying values for logical names
    U = y₂
    T = y₄
    
    # Integration for η --> y transformation
    y = zeros(N+1);
    for i=2:N+1
       y[i] = y[i-1] + y₄[i]*(η[i]-η[i-1]);  
    end
    y = y*sqrt(2);
    
    return η,y,U,T,N
end

# ╔═╡ 7830b222-4192-11eb-18b6-5548ffd5f535
begin
	η,y,U,T,N = selfsimilar();
	plot(U,η,
	        title = "Similarity (M=1 - T=300K)",
	        label = "U",
	        legend = :topleft,
	        xlabel = "U",
	        ylabel = "η",
	        linewidth = 2,
	        linecolor = :black,
	        markershape = :circle,
	        markercolor = :red,
	    )
end

# ╔═╡ 90bc1cd0-4192-11eb-352b-572716d665fe
plot(T,η,
        title = "Similarity (M=1 - T=300K)",
        label = "T",
        legend = :topleft,
        xlabel = "T",
        ylabel = "η",
        linewidth = 2,
        linecolor = :black,
        markershape = :circle,
        markercolor = :red,
    )

# ╔═╡ 92859230-4192-11eb-0029-9f6dcb343b1e
plot(U,y,
        title = "Similarity Solution (M=1 - T=300K)",
        label = "U",
        legend = :topleft,
        xlabel = "U",
        ylabel = "y/√(νx/U)",
        linewidth = 2,
        linecolor = :black,
        markershape = :circle,
        markercolor = :red,
    )

# ╔═╡ Cell order:
# ╟─3a43bac0-4192-11eb-30c2-e1c845f3e7bb
# ╟─4072d430-4192-11eb-15ad-d551a4cc6523
# ╟─49630972-4192-11eb-3dd3-c14371066e1a
# ╟─54ef1f40-4192-11eb-3e9d-1b8d62a4d99f
# ╟─564b53e0-4192-11eb-33c2-717cb09752bf
# ╟─5b66da70-4192-11eb-3e5a-051e2c64153f
# ╟─5fff2740-4192-11eb-39b5-11f529ae8fa1
# ╟─64d910ee-4192-11eb-30ff-b730c8610bd9
# ╟─6a635ee0-4192-11eb-3d15-79ce34aa522b
# ╟─6ed84530-4192-11eb-2c32-9fd8d5c0684e
# ╟─7830b222-4192-11eb-18b6-5548ffd5f535
# ╟─90bc1cd0-4192-11eb-352b-572716d665fe
# ╟─92859230-4192-11eb-0029-9f6dcb343b1e
