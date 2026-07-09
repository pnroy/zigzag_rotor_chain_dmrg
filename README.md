# Endofullerene Zigzag Chain DMRG Code

Julia/ITensor code for density matrix renormalization group (DMRG) calculations
of dipolar molecules (LiF, D₂O, H₂O) confined in bent ("zigzag") endofullerene
chains. Computes ground and excited states as a function of the chain angle and
effective dipole moment, and evaluates the observables behind the figures of the
accompanying manuscript: energies, von-Neumann entanglement entropy, dipole and
center-of-mass correlations, Binder parameters, net polarization, and
orientational/radial distributions.

## Requirements

- **Julia** (the version recorded in `env/Manifest.toml`)
- **ITensors.jl** (exact version pinned in `env/Manifest.toml`)
- Standard-library packages `Printf` and `LinearAlgebra`

The pinned environment lives in the `env/` subfolder (`env/Project.toml`,
`env/Manifest.toml`), while the source modules sit at the repository root. This
separation is deliberate: it keeps the root directory free of a `Project.toml`
so Julia can discover the loose sibling modules (`monomer.jl`, `kinetic.jl`, …)
via `LOAD_PATH`, while `--project=env` still pins the exact ITensors.jl version.

Install the exact dependency set from the pinned environment:

```bash
julia --project=env -e 'using Pkg; Pkg.instantiate()'
```

> The committed `env/Project.toml` and `env/Manifest.toml` fix the ITensors.jl
> version. Reproducing the published numbers requires this environment, since
> the ITensor API and performance change across versions.

## Repository layout

```
zigzag_rotor_chain_dmrg/
  main.jl, monomer.jl, kinetic.jl, ...   # source modules (repository root)
  input.txt, c60.txt                     # input files
  env/
    Project.toml, Manifest.toml          # pinned Julia environment
```

The source modules are loaded via `push!(LOAD_PATH, @__DIR__)`, which adds the
root directory (where all `.jl` files live) to Julia's load path. Because the
root has no `Project.toml`, Julia treats it as an implicit environment and finds
the loose sibling modules; the pinned dependencies are activated separately with
`--project=env`.

| File | Role |
|---|---|
| `main.jl` | Driver: reads input, builds the monomer basis, assembles the MPO, runs DMRG over a dipole-moment sweep, writes all observables |
| `monomer.jl` | Single-site (monomer) eigenbasis for the confined rotor |
| `dd_interaction.jl` | Dipole-dipole interaction matrices (pair-product decomposition) |
| `kinetic.jl` | Rotational/translational kinetic energy |
| `potential.jl`, `hf_potential.jl`, `lif_c60.jl` | Guest-cage potentials (H₂O/HF and LiF@C₆₀) |
| `create_operators.jl`, `operators.jl` | ITensor site type (`AsymTop`) and operator definitions |
| `expectation.jl` | Expectation values, entropy, Binder parameter |
| `correlations.jl` | Dipole and COM correlation functions |
| `distributions.jl` | Radial and orientational (cosθ, φ) distributions |
| `trans_real_complex.jl` | Real ↔ complex spherical-harmonic transforms |
| `observer.jl` | DMRG convergence observer |

Note: `operators.jl` is generated/large and is `include`d per dipole step by
`main.jl`; `observer.jl` is likewise `include`d in the sweep loop.

## Input files

The driver reads two files from the working directory:

- **`input.txt`** — DMRG and system parameters, read positionally by line
  number. Each parameter sits on its own line as `label value`. The fields, in
  order, are:

  | Parameter | Meaning |
  |---|---|
  | `Nsites` | number of chain sites |
  | `Nbond` | max bond dimension |
  | `Nsweep` | number of DMRG sweeps |
  | `e_cutoff` | energy convergence cutoff |
  | `dmrg_svd` | SVD truncation error |
  | `mbond` | bond index used for the entropy cut |
  | `angle` | chain angle γ (degrees) |
  | `R0` | cage-cage spacing (Å) |
  | `mu0` | starting dipole moment |
  | `dmu` | dipole-moment step |
  | `Nmu` | number of dipole-moment values |
  | `isomer` | spin isomer (e.g. ortho/para) |
  | `Nlevel` | number of monomer levels |
  | `Ntotal` | number of states (ground + excited) to target |
  | `polarization` | field direction: `no`, `X`, `Y`, `Z`, `XY`, `YZ` |
  | `Estart` | field strength (cm⁻¹) |
  | `interaction` | `nearest` or `next` (NN vs NN+NNN) |
  | `jmax` | max rotational quantum number |
  | `Nalpha`, `Nm` | Wigner-basis grid sizes |
  | `B0` | rotational constant (cm⁻¹) |
  | `nmax` | max translational quantum number |
  | `mass` | guest mass (u) |
  | `omega` | harmonic frequency of the translational mode (cm⁻¹) |
  | `NR`, `Ntheta`, `Nphi` | quadrature grid sizes |
  | `eq_struct` | equilibrium geometry parameter (Å) |
  | `svd_err` | SVD threshold for the pair-product decomposition |

  > `input.txt` is parsed by fixed line numbers in `main.jl`. Keep the line
  > layout identical to the provided template; add or reorder lines only if you
  > update the corresponding `lines[...]` indices in `main.jl`.

- **`c60.txt`** — C₆₀ cage geometry: first line is the atom count, followed by
  `element x y z` coordinates (Å), read by the guest-cage potential routines.

## Running a calculation

Place `input.txt` and `c60.txt` in the repository root (next to `main.jl`) and
run from that directory:

```bash
julia --project=env main.jl
```

Progress is logged to a file named `log`. For a chain that includes
next-nearest-neighbor interactions, set `interaction next` and use `Nsites` > 2.

## Reproduce-the-figures workflow

Each figure in the manuscript corresponds to a scan over the chain angle γ
and/or the effective dipole moment μ_eff. A single run sweeps μ (via `mu0`,
`dmu`, `Nmu`); different γ values are separate runs (vary `angle` in
`input.txt`). The observables are written to labeled text files, one row per
dipole-moment value, appended across the sweep.

**Guest species / parameters used in the paper**

- **LiF:** linear rotor; screened dipole μ_eff = 1.46 D. Set the LiF cage
  potential (`lif_c60.jl`) and the LiF rotational constant / mass in `input.txt`.
- **o-D₂O:** asymmetric top; unscreened dipole μ₀ = 1.86 D (see manuscript for
  the screening rationale).
- **p-H₂O:** asymmetric top; used to show the absence of ordering.
- Cage spacing `R0` = 10 Å throughout.

**Output files → figure quantities**

| Output file(s) | Quantity | Figure |
|---|---|---|
| `energy.txt` | ground/excited energies per μ | energy vs. N / γ (stability) |
| `ctheta_distribution_*.txt`, `phi_distribution_*.txt`, `radial_distribution_*.txt` | single-site orientational and radial densities P(cosθ), P(φ), P(R) | density panels |
| `muxcorr.txt`, `muycorr.txt`, `muzcorr.txt` (+ `_center`) | NN dipole correlation functions | phase diagram (correlation sign → ferro/antiferro) |
| `mux.txt`, `muy.txt`, `muz.txt` | net polarization components | polarization vs. N |
| `binder_x.txt`, `binder_y.txt`, `binder_z.txt` | Binder cumulants | Binder panel (transition location) |
| `entropy.txt`, `schmidt_values_*.txt` | von-Neumann entropy and Schmidt spectrum | entanglement-entropy panel |
| `xcorr.txt`, `ycorr.txt`, `zcorr.txt`, `xavg.txt`, `yavg.txt`, `zavg.txt` | COM correlations and averages | supporting analysis |

**Typical sequence to regenerate a full figure**

1. Choose the guest species (rotational constant, mass, cage potential) in
   `input.txt`.
2. For each target chain angle γ, set `angle` and run `julia --project=env main.jl`
   in a dedicated output directory.
3. For the phase diagram, ensure `Nmu`/`dmu` span the μ_eff range of interest;
   for the ferro/antiferro comparison, run both `interaction nearest` and
   `interaction next`.
4. Collect the resulting text files and plot (net polarization, Binder cumulant,
   entropy, and NN-correlation sign as functions of μ_eff and γ).

> Because output files are opened in append mode and initialized once per run,
> use a clean working directory (or clear the `*.txt` outputs) for each new
> (γ, species) combination to avoid mixing sweeps.

## Citing

If you use this code, please cite the accompanying manuscript and the archived
software release (see `CITATION.cff`).
