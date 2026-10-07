# Sensitivity & Robustness Output

Engine: R version 4.6.0 (2026-04-24) + metafor 5.0.1. Generated 2026-10-07.

## NOTES ON INTERPRETATION

- **Overlap-rule assertion PASSED**: no pool contains both Berthold (EMBASE3-0017) and Borgas (EMBASE2-0040). The code stops with an error if violated.
- **MA2_flare and MA4_flareprop are k=2 (exploratory).** tau2 and the 95% prediction interval are unstable and must NOT be interpreted as reliable; report point estimates with explicit caution. Nguyen cannot join MA2_flare (no continued-arm flare count).
- **All pools have k<10; funnel plots / Egger tests are underpowered and were NOT rendered.** Publication bias is formally unassessable and is handled qualitatively in GRADE.
- **MA1 heterogeneity is directional** (Berthold OR>1; the other three OR<1), largely explained by confounding by indication (sicker patients preferentially held). This drives the inconsistency downgrade but the direction (continuation safe) is conservative.
- **DO NOT OVER-READ the MA1 primary OR of 0.50 as 'continuation halves SSI'.** It is model-dependent: the random-effects (REML) estimate down-weights the large Berthold study via tau2, whereas fixed-effect / Mantel-Haenszel / Peto all give ~0.97 (essentially null). ALL estimates cross OR=1. The defensible conclusion is: *no evidence that continuation increases SSI/wound risk* (not a demonstrated protective effect). Certainty is Very Low.
- **George recent-IFX vs whole-cohort:** primary uses recent-IFX (<4wk) proxy; whole-cohort alternatives (SSI 270/4288, PJI 105/4288) are reported below and do not change conclusions.
- **MA3_SSIprop is unaffected by the Berthold 28-vs-25 discrepancy** (that discrepancy is in the *discontinue* arm; MA3 uses Group B/continue = 35/681).

## MA1_SSI (comparative OR) - primary and robustness

| Analysis | k | Pooled OR (95% CI) | I2 |
|---|---|---|---|
| **Primary REML (random-effects)** | 4 | **0.50 (95% CI 0.16-1.55)** | 75% |
| Fixed-effect | 4 | 0.97 (95% CI 0.64-1.48) | - |
| Mantel-Haenszel | 4 | 0.98 (95% CI 0.65-1.47) | 78% |
| Peto | 4 | 0.97 (95% CI 0.64-1.49) | 80% |
| Binomial-normal GLMM (UM.FS) | 4 | 0.53 (95% CI 0.19-1.48) | 67% |
| Berthold discontinue = 25/872 (sensitivity) | 4 | 0.51 (95% CI 0.16-1.67) | 77% |
| Fabiano continue = 0/87 (sensitivity; continuity correction add=1/2, to=only0) | 4 | 0.45 (95% CI 0.13-1.56) | 78% |
| **Exclude Berthold (overlap robustness)** | 3 | 0.31 (95% CI 0.14-0.66) | 0% |

Primary 95% prediction interval: **0.06 to 4.37** (wide; spans the null).

**Leave-one-out (MA1):**

| Omitted | Pooled OR (95% CI) | I2 |
|---|---|---|
| Bakkour 2016 | 0.70 (95% CI 0.22-2.29) | 74% |
| Berthold 2013 | 0.31 (95% CI 0.14-0.66) | 0% |
| Fabiano 2014 | 0.55 (95% CI 0.15-2.04) | 83% |
| Nguyen 2021 | 0.50 (95% CI 0.10-2.52) | 75% |

**Subgroup (MA1) - pure psoriasis/PsA vs mixed cohort:**
- Pure (Bakkour, Fabiano): OR 0.19 (95% CI 0.05-0.68)
- Mixed (Berthold, Nguyen): OR 0.85 (95% CI 0.22-3.38)
- Test for subgroup difference: p = 0.147

## MA2_flare (comparative OR, k=2, EXPLORATORY)
- Primary REML: OR 0.39 (95% CI 0.06-2.43), I2 = 82%
- Fixed-effect: OR 0.50 (95% CI 0.24-1.05); Peto: OR 0.48 (95% CI 0.22-1.02)
- Prediction interval unstable at k=2; not reported as reliable.

## MA3_SSIprop (continuer SSI/wound proportion)
- **Primary logit REML:** 5.7% (95% CI 4.8-6.7), I2 = 0%
- Freeman-Tukey (PFT): 5.3% (95% CI 4.3-6.3)
- Exclude Berthold (overlap): 5.9% (95% CI 4.8-7.3), I2=0%
- George whole-cohort (270/4288): 6.0% (95% CI 5.2-6.9), I2=8%

**Leave-one-out (MA3_SSIprop):**

| Omitted | Pooled % (95% CI) | I2 |
|---|---|---|
| Bakkour 2016 | 5.7% (4.7-6.8) | 0% |
| Berthold 2013 | 5.9% (4.8-7.3) | 0% |
| Fabiano 2014 | 5.7% (4.8-6.8) | 0% |
| George 2017 | 5.2% (3.9-6.8) | 0% |
| Nguyen 2021 | 5.6% (4.7-6.7) | 0% |

## MA3_PJIprop (PJI proportion)
- **Primary logit REML:** 2.4% (95% CI 1.6-3.6), I2 = 2%
- Freeman-Tukey (PFT): 1.7% (95% CI 0.6-3.3)
- George whole-cohort (105/4288): 2.4% (95% CI 2.0-2.9), I2=0%

**Leave-one-out (MA3_PJIprop):**

| Omitted | Pooled % (95% CI) | I2 |
|---|---|---|
| Borgas 2020 | 2.6% (1.8-3.6) | 0% |
| George 2017 | 1.2% (0.3-4.7) | 0% |
| Nguyen 2021 | 1.8% (0.5-5.8) | 48% |

## MA4_flareprop (flare burden by arm)
- Continuers (Bakkour, Vasavada): 9.0% (95% CI 5.5-14.4), I2 = 0%
- Discontinuers (Bakkour, Vasavada): 20.6% (95% CI 4.1-61.0), I2 = 91%

## Fixed vs random effects (all pools)
- MA1: RE 0.50 (95% CI 0.16-1.55) vs FE 0.97 (95% CI 0.64-1.48) (conclusion unchanged).
- MA2: RE 0.39 (95% CI 0.06-2.43) vs FE 0.50 (95% CI 0.24-1.05).

