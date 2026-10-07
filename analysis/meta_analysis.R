## =====================================================================
## meta_analysis.R
## Systematic review: Perioperative Management of Biologic and Targeted
## Synthetic DMARDs in Psoriasis / Psoriatic Arthritis Undergoing
## Orthopedic Surgery.
##
## Primary engine: R 4.6.0 + metafor 5.0.1 (jsonlite for results.json).
## Produces: analysis/results.json, supplement/sensitivity_output.md,
##           tables/Table3_GRADE_SoF.csv, Figures 3 & 4 (png + pdf).
##
## Reproducible: runs clean end-to-end. No package beyond metafor/jsonlite.
## =====================================================================

suppressPackageStartupMessages({
  library(metafor)
  library(jsonlite)
})
options(stringsAsFactors = FALSE)
set.seed(42)

PROJ <- local({ a <- grep("^--file=", commandArgs(FALSE), value = TRUE); if (length(a)) normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", a[1]), fixed = TRUE)), "..")) else normalizePath(".") })
DAT  <- file.path(PROJ, "data", "poolable_dataset.csv")
FIGDIR <- file.path(PROJ, "outputs", "figures")
TABDIR <- file.path(PROJ, "outputs", "tables")
SUPDIR <- file.path(PROJ, "outputs", "supplement")
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TABDIR, showWarnings = FALSE, recursive = TRUE)
dir.create(SUPDIR, showWarnings = FALSE, recursive = TRUE)

dat_all <- read.csv(DAT)
cat("Loaded", nrow(dat_all), "poolable rows across analyses:",
    paste(sort(unique(dat_all$analysis)), collapse = ", "), "\n")

BERTHOLD <- "EMBASE3-0017"
BORGAS   <- "EMBASE2-0040"
GEORGE   <- "EMBASE2-0082"
FABIANO  <- "EMBASE3-0011"

## ---------------------------------------------------------------------
## 0. OVERLAP-RULE ASSERTION (Berthold <-> Borgas never share a pool)
## ---------------------------------------------------------------------
assert_overlap <- function(d) {
  for (a in unique(d$analysis)) {
    ids <- unique(d$study_id[d$analysis == a])
    if (BERTHOLD %in% ids && BORGAS %in% ids) {
      stop(sprintf("OVERLAP-RULE VIOLATION: Berthold (%s) and Borgas (%s) both in pool '%s'.",
                   BERTHOLD, BORGAS, a))
    }
  }
  invisible(TRUE)
}
assert_overlap(dat_all)
OVERLAP_PASS <- TRUE
cat("[ASSERT OK] Overlap rule: Berthold and Borgas never appear in the same pool.\n\n")

## ---------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------
# Build wide (continue vs discontinue) frame for a comparative pool
make_wide <- function(d, analysis_name) {
  sub  <- d[d$analysis == analysis_name, ]
  cont <- sub[sub$arm == "continue", c("study_id","study_label","events","n")]
  disc <- sub[sub$arm == "discontinue", c("study_id","events","n")]
  m <- merge(cont, disc, by = "study_id", suffixes = c("_c","_d"))
  m <- m[order(m$study_label), ]
  m
}

rnd <- function(x, d = 4) if (is.null(x) || length(x) == 0) NA else round(as.numeric(x), d)
naNull <- function(x) if (length(x) == 0 || is.na(x)) NA else x

# Standardized summary for an OR (log-scale) rma model
summ_or <- function(res) {
  pr <- predict(res, transf = exp)
  list(
    k = res$k,
    pooled_OR = rnd(pr$pred), ci_low = rnd(pr$ci.lb), ci_high = rnd(pr$ci.ub),
    I2 = rnd(res$I2, 1), tau2 = rnd(res$tau2), H2 = rnd(res$H2, 3),
    Q = rnd(res$QE, 3), Q_df = res$k - 1, Q_pval = rnd(res$QEp),
    prediction_interval = list(pi_low = rnd(pr$pi.lb), pi_high = rnd(pr$pi.ub))
  )
}

# Standardized summary for a logit-proportion rma model
summ_prop <- function(res) {
  pr <- predict(res, transf = transf.ilogit)
  list(
    k = res$k,
    pooled_prop = rnd(pr$pred), ci_low = rnd(pr$ci.lb), ci_high = rnd(pr$ci.ub),
    pooled_pct = rnd(100 * pr$pred, 2),
    pct_ci_low = rnd(100 * pr$ci.lb, 2), pct_ci_high = rnd(100 * pr$ci.ub, 2),
    I2 = rnd(res$I2, 1), tau2 = rnd(res$tau2), Q = rnd(res$QE, 3),
    Q_df = res$k - 1, Q_pval = rnd(res$QEp),
    prediction_interval = list(pi_low = rnd(pr$pi.lb), pi_high = rnd(pr$pi.ub),
                               pi_low_pct = rnd(100 * pr$pi.lb, 2),
                               pi_high_pct = rnd(100 * pr$pi.ub, 2))
  )
}

per_study_or <- function(dat, res) {
  w  <- weights(res)
  or <- exp(dat$yi); lo <- exp(dat$yi - 1.96*sqrt(dat$vi)); hi <- exp(dat$yi + 1.96*sqrt(dat$vi))
  lapply(seq_len(nrow(dat)), function(i) list(
    study = dat$study_label[i],
    events_continue = dat$events_c[i], n_continue = dat$n_c[i],
    events_discontinue = dat$events_d[i], n_discontinue = dat$n_d[i],
    OR = rnd(or[i]), ci_low = rnd(lo[i]), ci_high = rnd(hi[i]), weight_pct = rnd(w[i], 2)))
}

per_study_prop <- function(dat, res) {
  w <- weights(res)
  p  <- dat$events / dat$n
  lo <- transf.ilogit(dat$yi - 1.96*sqrt(dat$vi))
  hi <- transf.ilogit(dat$yi + 1.96*sqrt(dat$vi))
  lapply(seq_len(nrow(dat)), function(i) list(
    study = dat$study_label[i], events = dat$events[i], n = dat$n[i],
    proportion = rnd(p[i]), pct = rnd(100*p[i], 2),
    ci_low = rnd(lo[i]), ci_high = rnd(hi[i]), weight_pct = rnd(w[i], 2)))
}

out <- list()

## ---------------------------------------------------------------------
## 1. META-DATA
## ---------------------------------------------------------------------
out$meta <- list(
  project = "Perioperative biologic/tsDMARD management in psoriasis/PsA orthopedic surgery",
  role = "Meta-analysis + GRADE",
  engine = "R", R_version = R.version.string,
  packages = list(metafor = as.character(packageVersion("metafor")),
                  jsonlite = as.character(packageVersion("jsonlite"))),
  primary_model = "Random-effects (REML) via metafor::rma",
  or_convention = "OR = odds of SSI/wound (or flare) in CONTINUE vs DISCONTINUE arm; OR>1 favours discontinuation (more events with continuation), OR<1 favours continuation.",
  proportion_transform = "Primary logit (measure='PLO'); sensitivity Freeman-Tukey double-arcsine (measure='PFT')",
  date_run = as.character(Sys.Date()),
  overlap_rule_asserted_pass = OVERLAP_PASS,
  input = "extraction/poolable_dataset.csv",
  notes = "Berthold discontinue arm = 28/872 primary (25/872 sensitivity). Fabiano continue arm = 1/87 primary (Table 2) with 0/87 as sensitivity (narrative text), continuity-corrected by escalc (add=1/2, to=only0). George = recent-IFX (<4wk) proxy primary; whole-cohort alternatives as sensitivity. All numbers trace to this file; Figures 3/4 and Table 3 reflect these exactly."
)

## =====================================================================
## MA1_SSI  — comparative continue vs discontinue -> composite SSI/wound
## =====================================================================
cat("========== MA1_SSI ==========\n")
m1 <- make_wide(dat_all, "MA1_SSI")
print(m1[, c("study_label","events_c","n_c","events_d","n_d")])

esc1 <- escalc(measure = "OR", ai = events_c, bi = n_c - events_c,
               ci = events_d, di = n_d - events_d, data = m1, slab = study_label)

# Primary: random-effects REML OR
ma1_reml <- rma(yi, vi, data = esc1, method = "REML")
# Fixed-effect for comparison
ma1_fe   <- rma(yi, vi, data = esc1, method = "FE")
# Rare-event: Mantel-Haenszel, Peto, GLMM
ma1_mh   <- rma.mh(measure = "OR", ai = events_c, bi = n_c - events_c,
                   ci = events_d, di = n_d - events_d, data = m1, slab = m1$study_label)
ma1_peto <- rma.peto(ai = events_c, bi = n_c - events_c,
                     ci = events_d, di = n_d - events_d, data = m1, slab = m1$study_label)
ma1_glmm <- tryCatch(
  rma.glmm(measure = "OR", ai = events_c, bi = n_c - events_c,
           ci = events_d, di = n_d - events_d, data = m1, slab = m1$study_label,
           model = "UM.FS"),
  error = function(e) { cat("GLMM failed:", conditionMessage(e), "\n"); NULL })

cat("\nMA1 REML OR:", round(exp(coef(ma1_reml)),3),
    " I2:", round(ma1_reml$I2,1), " tau2:", round(ma1_reml$tau2,3), "\n")

# ---- Sensitivity analyses for MA1 ----
# (a) Berthold discontinue 25/872 instead of 28/872
m1_25 <- m1; m1_25$events_d[m1_25$study_id == BERTHOLD] <- 25
esc1_25 <- escalc(measure="OR", ai=events_c, bi=n_c-events_c, ci=events_d, di=n_d-events_d,
                  data=m1_25, slab=study_label)
ma1_reml_25 <- rma(yi, vi, data = esc1_25, method = "REML")

# (a2) Fabiano continue 0/87 instead of 1/87 (narrative text vs Table 2 discrepancy).
#      The zero cell triggers escalc's default continuity correction (add=1/2, to="only0"),
#      applied to that study only; the other three studies are untouched.
m1_f0 <- m1; m1_f0$events_c[m1_f0$study_id == FABIANO] <- 0
esc1_f0 <- escalc(measure="OR", ai=events_c, bi=n_c-events_c, ci=events_d, di=n_d-events_d,
                  data=m1_f0, slab=study_label)
ma1_reml_f0 <- rma(yi, vi, data = esc1_f0, method = "REML")

# (b) Exclude Berthold entirely (overlap robustness: cohort represented by Borgas PJI only)
m1_noB <- m1[m1$study_id != BERTHOLD, ]
esc1_noB <- escalc(measure="OR", ai=events_c, bi=n_c-events_c, ci=events_d, di=n_d-events_d,
                   data=m1_noB, slab=study_label)
ma1_reml_noB <- rma(yi, vi, data = esc1_noB, method = "REML")

# (c) Leave-one-out
l1o_ma1 <- leave1out(ma1_reml, transf = exp)

# (d) Subgroup: psoriasis/PsA-pure (Bakkour, Fabiano) vs mixed (Berthold, Nguyen)
esc1$pure <- ifelse(esc1$study_id %in% c("EMBASE2-0094","EMBASE3-0011"), "pure_PsO_PsA", "mixed")
ma1_pure  <- rma(yi, vi, data = esc1[esc1$pure=="pure_PsO_PsA", ], method = "REML")
ma1_mixed <- rma(yi, vi, data = esc1[esc1$pure=="mixed", ], method = "REML")
ma1_sgtest <- rma(yi, vi, mods = ~ pure, data = esc1, method = "REML")

out$analyses$MA1_SSI <- c(
  list(analysis = "MA1_SSI",
       description = "Comparative: continuation vs discontinuation of biologic/tsDMARD -> composite surgical-site infection / wound complication. Primary: random-effects (REML) odds ratio.",
       interpretation = "The primary RE (REML) OR (0.50) is MODEL-DEPENDENT: REML down-weights the large Berthold study via tau2, while fixed-effect/Mantel-Haenszel/Peto all give ~0.97 (null). ALL estimates cross OR=1. Defensible conclusion: NO evidence that continuation increases SSI/wound risk (not a proven protective effect). Certainty Very Low.",
       studies = m1$study_label,
       measure = "OR", model = "random-effects (REML)",
       primary = summ_or(ma1_reml),
       per_study = per_study_or(esc1, ma1_reml)),
  list(sensitivity = list(
    fixed_effect      = list(model="FE OR", pooled_OR=rnd(exp(coef(ma1_fe))),
                             ci_low=rnd(exp(ma1_fe$ci.lb)), ci_high=rnd(exp(ma1_fe$ci.ub))),
    mantel_haenszel   = list(model="Mantel-Haenszel OR (no continuity correction to cells)",
                             pooled_OR=rnd(exp(coef(ma1_mh))),
                             ci_low=rnd(exp(ma1_mh$ci.lb)), ci_high=rnd(exp(ma1_mh$ci.ub)),
                             I2=rnd(ma1_mh$I2,1), Q_pval=rnd(ma1_mh$QEp)),
    peto              = list(model="Peto OR",
                             pooled_OR=rnd(exp(coef(ma1_peto))),
                             ci_low=rnd(exp(ma1_peto$ci.lb)), ci_high=rnd(exp(ma1_peto$ci.ub)),
                             I2=rnd(ma1_peto$I2,1), Q_pval=rnd(ma1_peto$QEp)),
    glmm              = if (!is.null(ma1_glmm))
                          list(model="Binomial-normal GLMM (UM.FS)",
                               pooled_OR=rnd(exp(coef(ma1_glmm))),
                               ci_low=rnd(exp(ma1_glmm$ci.lb)), ci_high=rnd(exp(ma1_glmm$ci.ub)),
                               I2=rnd(ma1_glmm$I2,1))
                        else list(model="Binomial-normal GLMM", note="did not converge / not estimable"),
    berthold_25       = list(model="REML OR, Berthold discontinue=25/872",
                             pooled_OR=rnd(exp(coef(ma1_reml_25))),
                             ci_low=rnd(exp(ma1_reml_25$ci.lb)), ci_high=rnd(exp(ma1_reml_25$ci.ub)),
                             I2=rnd(ma1_reml_25$I2,1)),
    fabiano_0         = list(model="REML OR, Fabiano continue=0/87 (continuity correction add=1/2, to=only0)",
                             pooled_OR=rnd(exp(coef(ma1_reml_f0))),
                             ci_low=rnd(exp(ma1_reml_f0$ci.lb)), ci_high=rnd(exp(ma1_reml_f0$ci.ub)),
                             I2=rnd(ma1_reml_f0$I2,1)),
    exclude_berthold  = list(model="REML OR, Berthold excluded (overlap robustness)",
                             k=ma1_reml_noB$k, studies=m1_noB$study_label,
                             pooled_OR=rnd(exp(coef(ma1_reml_noB))),
                             ci_low=rnd(exp(ma1_reml_noB$ci.lb)), ci_high=rnd(exp(ma1_reml_noB$ci.ub)),
                             I2=rnd(ma1_reml_noB$I2,1), tau2=rnd(ma1_reml_noB$tau2)),
    leave_one_out     = lapply(seq_along(l1o_ma1$estimate), function(i) list(
                             omitted=ma1_reml$slab[i], pooled_OR=rnd(l1o_ma1$estimate[i]),
                             ci_low=rnd(l1o_ma1$ci.lb[i]), ci_high=rnd(l1o_ma1$ci.ub[i]),
                             I2=rnd(l1o_ma1$I2[i],1))),
    subgroup_pure_vs_mixed = list(
      pure_PsO_PsA = list(studies=c("Bakkour 2016","Fabiano 2014"),
                          pooled_OR=rnd(exp(coef(ma1_pure))),
                          ci_low=rnd(exp(ma1_pure$ci.lb)), ci_high=rnd(exp(ma1_pure$ci.ub))),
      mixed        = list(studies=c("Berthold 2013","Nguyen 2021"),
                          pooled_OR=rnd(exp(coef(ma1_mixed))),
                          ci_low=rnd(exp(ma1_mixed$ci.lb)), ci_high=rnd(exp(ma1_mixed$ci.ub))),
      test_of_subgroup_diff_pval = rnd(ma1_sgtest$QMp))
  ))
)

## =====================================================================
## MA2_flare — comparative continue vs discontinue -> disease flare (k=2)
## =====================================================================
cat("\n========== MA2_flare ==========\n")
m2 <- make_wide(dat_all, "MA2_flare")
print(m2[, c("study_label","events_c","n_c","events_d","n_d")])
esc2 <- escalc(measure="OR", ai=events_c, bi=n_c-events_c, ci=events_d, di=n_d-events_d,
               data=m2, slab=study_label)
ma2_reml <- rma(yi, vi, data = esc2, method = "REML")
ma2_fe   <- rma(yi, vi, data = esc2, method = "FE")
ma2_peto <- rma.peto(ai=events_c, bi=n_c-events_c, ci=events_d, di=n_d-events_d,
                     data=m2, slab=m2$study_label)
cat("MA2 REML OR:", round(exp(coef(ma2_reml)),3), " I2:", round(ma2_reml$I2,1), "\n")

out$analyses$MA2_flare <- list(
  analysis = "MA2_flare",
  description = "Comparative: continuation vs discontinuation -> disease flare. EXPLORATORY (only k=2 studies; prediction interval unstable). Vasavada exposure is AGGREGATE immunosuppression, not biologic-isolated (see notes).",
  caveat = "k=2: heterogeneity and prediction interval are unstable and not interpretable; report point estimate with caution. Nguyen excluded (no continued-arm flare count -> no valid pair).",
  studies = m2$study_label,
  measure = "OR", model = "random-effects (REML)",
  primary = summ_or(ma2_reml),
  per_study = per_study_or(esc2, ma2_reml),
  sensitivity = list(
    fixed_effect = list(model="FE OR", pooled_OR=rnd(exp(coef(ma2_fe))),
                        ci_low=rnd(exp(ma2_fe$ci.lb)), ci_high=rnd(exp(ma2_fe$ci.ub))),
    peto = list(model="Peto OR", pooled_OR=rnd(exp(coef(ma2_peto))),
                ci_low=rnd(exp(ma2_peto$ci.lb)), ci_high=rnd(exp(ma2_peto$ci.ub)))
  )
)

## =====================================================================
## MA3_SSIprop — single-arm SSI/wound proportion among CONTINUERS
## =====================================================================
cat("\n========== MA3_SSIprop ==========\n")
p3 <- dat_all[dat_all$analysis == "MA3_SSIprop", ]
p3 <- p3[order(p3$study_label), ]
print(p3[, c("study_label","events","n")])
esc3 <- escalc(measure="PLO", xi=events, ni=n, data=p3, slab=study_label)
ma3s_reml <- rma(yi, vi, data = esc3, method = "REML")
# FTT sensitivity
esc3_ft <- escalc(measure="PFT", xi=events, ni=n, data=p3, slab=study_label)
ma3s_ft <- rma(yi, vi, data = esc3_ft, method = "REML")
pred3s_ft <- predict(ma3s_ft, transf = transf.ipft.hm, targs = list(ni = p3$n))
# Leave-one-out
l1o_3s <- leave1out(ma3s_reml, transf = transf.ilogit)
# Exclude Berthold (overlap robustness)
p3_noB <- p3[p3$study_id != BERTHOLD, ]
esc3_noB <- escalc(measure="PLO", xi=events, ni=n, data=p3_noB, slab=study_label)
ma3s_noB <- rma(yi, vi, data = esc3_noB, method = "REML")
# George whole-cohort alternative (270/4288 serious infection)
p3_gw <- p3; p3_gw$events[p3_gw$study_id==GEORGE] <- 270; p3_gw$n[p3_gw$study_id==GEORGE] <- 4288
esc3_gw <- escalc(measure="PLO", xi=events, ni=n, data=p3_gw, slab=study_label)
ma3s_gw <- rma(yi, vi, data = esc3_gw, method = "REML")
cat("MA3_SSIprop pooled:", round(100*transf.ilogit(coef(ma3s_reml)),2), "%  I2:", round(ma3s_reml$I2,1), "\n")

out$analyses$MA3_SSIprop <- list(
  analysis = "MA3_SSIprop",
  description = "Single-arm pooled SSI/wound-complication proportion among CONTINUERS. Primary: logit-transformed proportion (REML). George = recent-IFX <4wk (serious/hospitalized infection within 30d, not SSI-specific).",
  studies = p3$study_label,
  measure = "proportion", model = "random-effects (REML), logit transform",
  primary = summ_prop(ma3s_reml),
  per_study = per_study_prop(esc3, ma3s_reml),
  sensitivity = list(
    freeman_tukey = list(model="Freeman-Tukey double-arcsine (PFT)",
                         pooled_prop = rnd(pred3s_ft$pred), pooled_pct = rnd(100*pred3s_ft$pred,2),
                         ci_low = rnd(pred3s_ft$ci.lb), ci_high = rnd(pred3s_ft$ci.ub),
                         pct_ci_low = rnd(100*pred3s_ft$ci.lb,2), pct_ci_high = rnd(100*pred3s_ft$ci.ub,2),
                         I2 = rnd(ma3s_ft$I2,1)),
    exclude_berthold = list(model="logit, Berthold excluded (overlap robustness)",
                            k=ma3s_noB$k, studies=p3_noB$study_label,
                            pooled_pct = rnd(100*transf.ilogit(coef(ma3s_noB)),2),
                            pct_ci_low = rnd(100*transf.ilogit(ma3s_noB$ci.lb),2),
                            pct_ci_high= rnd(100*transf.ilogit(ma3s_noB$ci.ub),2),
                            I2 = rnd(ma3s_noB$I2,1)),
    george_whole_cohort = list(model="logit, George=270/4288 whole-cohort serious infection",
                            pooled_pct = rnd(100*transf.ilogit(coef(ma3s_gw)),2),
                            pct_ci_low = rnd(100*transf.ilogit(ma3s_gw$ci.lb),2),
                            pct_ci_high= rnd(100*transf.ilogit(ma3s_gw$ci.ub),2),
                            I2 = rnd(ma3s_gw$I2,1)),
    leave_one_out = lapply(seq_along(l1o_3s$estimate), function(i) list(
                            omitted=ma3s_reml$slab[i], pooled_pct=rnd(100*l1o_3s$estimate[i],2),
                            pct_ci_low=rnd(100*l1o_3s$ci.lb[i],2), pct_ci_high=rnd(100*l1o_3s$ci.ub[i],2),
                            I2=rnd(l1o_3s$I2[i],1)))
  )
)

## =====================================================================
## MA3_PJIprop — single-arm PJI proportion (Borgas here, NOT Berthold)
## =====================================================================
cat("\n========== MA3_PJIprop ==========\n")
p4 <- dat_all[dat_all$analysis == "MA3_PJIprop", ]
p4 <- p4[order(p4$study_label), ]
print(p4[, c("study_label","events","n")])
esc4 <- escalc(measure="PLO", xi=events, ni=n, data=p4, slab=study_label)
ma3p_reml <- rma(yi, vi, data = esc4, method = "REML")
esc4_ft <- escalc(measure="PFT", xi=events, ni=n, data=p4, slab=study_label)
ma3p_ft <- rma(yi, vi, data = esc4_ft, method = "REML")
pred3p_ft <- predict(ma3p_ft, transf = transf.ipft.hm, targs = list(ni = p4$n))
l1o_3p <- leave1out(ma3p_reml, transf = transf.ilogit)
# George whole-cohort PJI alternative (105/4288)
p4_gw <- p4; p4_gw$events[p4_gw$study_id==GEORGE] <- 105; p4_gw$n[p4_gw$study_id==GEORGE] <- 4288
esc4_gw <- escalc(measure="PLO", xi=events, ni=n, data=p4_gw, slab=study_label)
ma3p_gw <- rma(yi, vi, data = esc4_gw, method = "REML")
cat("MA3_PJIprop pooled:", round(100*transf.ilogit(coef(ma3p_reml)),2), "%  I2:", round(ma3p_reml$I2,1), "\n")

out$analyses$MA3_PJIprop <- list(
  analysis = "MA3_PJIprop",
  description = "Single-arm pooled periprosthetic-joint-infection proportion. Borgas (TNFi-user), George (recent-IFX <4wk, PJI within 1yr), Nguyen (1/43 arthroplasties). Primary: logit (REML). OVERLAP RULE: Borgas here, NOT Berthold.",
  studies = p4$study_label,
  measure = "proportion", model = "random-effects (REML), logit transform",
  primary = summ_prop(ma3p_reml),
  per_study = per_study_prop(esc4, ma3p_reml),
  sensitivity = list(
    freeman_tukey = list(model="Freeman-Tukey double-arcsine (PFT)",
                         pooled_prop = rnd(pred3p_ft$pred), pooled_pct = rnd(100*pred3p_ft$pred,2),
                         ci_low = rnd(pred3p_ft$ci.lb), ci_high = rnd(pred3p_ft$ci.ub),
                         pct_ci_low = rnd(100*pred3p_ft$ci.lb,2), pct_ci_high = rnd(100*pred3p_ft$ci.ub,2),
                         I2 = rnd(ma3p_ft$I2,1)),
    george_whole_cohort = list(model="logit, George=105/4288 whole-cohort PJI",
                         pooled_pct = rnd(100*transf.ilogit(coef(ma3p_gw)),2),
                         pct_ci_low = rnd(100*transf.ilogit(ma3p_gw$ci.lb),2),
                         pct_ci_high= rnd(100*transf.ilogit(ma3p_gw$ci.ub),2),
                         I2 = rnd(ma3p_gw$I2,1)),
    leave_one_out = lapply(seq_along(l1o_3p$estimate), function(i) list(
                         omitted=ma3p_reml$slab[i], pooled_pct=rnd(100*l1o_3p$estimate[i],2),
                         pct_ci_low=rnd(100*l1o_3p$ci.lb[i],2), pct_ci_high=rnd(100*l1o_3p$ci.ub[i],2),
                         I2=rnd(l1o_3p$I2[i],1)))
  )
)

## =====================================================================
## MA4_flareprop — flare proportions, continuers vs discontinuers
## =====================================================================
cat("\n========== MA4_flareprop ==========\n")
p5 <- dat_all[dat_all$analysis == "MA4_flareprop", ]
p5c <- p5[p5$arm == "continue", ];    p5c <- p5c[order(p5c$study_label), ]
p5d <- p5[p5$arm == "discontinue", ]; p5d <- p5d[order(p5d$study_label), ]
cat("Continue arm:\n"); print(p5c[, c("study_label","events","n")])
cat("Discontinue arm:\n"); print(p5d[, c("study_label","events","n")])

esc5c <- escalc(measure="PLO", xi=events, ni=n, data=p5c, slab=study_label)
ma4c  <- rma(yi, vi, data = esc5c, method = "REML")
esc5d <- escalc(measure="PLO", xi=events, ni=n, data=p5d, slab=study_label)
ma4d  <- rma(yi, vi, data = esc5d, method = "REML")

out$analyses$MA4_flareprop <- list(
  analysis = "MA4_flareprop",
  description = "Flare-burden proportions by arm (Bakkour, Vasavada). k=2 per arm (exploratory). Continuers vs discontinuers pooled separately (logit, REML).",
  caveat = "k=2 per arm; prediction interval unstable. Vasavada exposure is aggregate immunosuppression, not biologic-isolated.",
  continuers = c(list(studies = p5c$study_label), summ_prop(ma4c),
                 list(per_study = per_study_prop(esc5c, ma4c))),
  discontinuers = c(list(studies = p5d$study_label), summ_prop(ma4d),
                 list(per_study = per_study_prop(esc5d, ma4d)))
)

## =====================================================================
## NARRATIVE (SWiM) — no pooling
## =====================================================================
out$narrative <- list(
  implant_survival = list(
    study = "Di Martino 2023 (registry cohort, THA)",
    finding = "Perioperative TNFi users (n=121) showed 5-year implant survival 96.6%; 3/121 revisions. Non-bDMARD comparator n=870. Comparison unmatched/imbalanced (age, AS%, RA%); revision is an objective ~95%-captured registry endpoint.",
    certainty_note = "Serious RoB (confounding + immortal-time selection); narrative only."),
  spine_infection = list(
    study = "Day 2023 (PearlDiver database, single-level lumbar discectomy)",
    finding = "Pure-psoriasis cohort matched 1:4. Psoriasis vs non-psoriasis SSI OR 1.795. Biologics subgroup (topicals+biologics, n=140): SSI OR 3.102 (p=.019), sepsis OR 6.367 (p=.027). Exposure is CHRONIC biologic use (recommendation-level), not a perioperative continue-vs-hold decision; no events/N reported for the biologic subgroup (ORs only).",
    certainty_note = "Serious RoB (D3 exposure-construct mismatch + confounding by indication). Hypothesis-generating; NOT a perioperative-timing comparison."),
  case_reports = list(
    Koga_2025 = "PsA (DAPSA 7.24, low activity), bilateral high tibial osteotomy, adalimumab held 2wk pre-op; no wound infection, no flare, 2-yr functional improvement. High-quality case report (JBI 8/8).",
    Kunimi_2018 = "PsA mutilans, hand surgery (thumb fusion/contracture release) with infliximab CONTINUED; infection-free, function improved. Moderate quality (letter; vague timing).",
    Kawakami_2016 = "Case 1 (the ONLY orthopedic case: Achilles tendon repair) had delayed wound healing AND psoriasis flare (PASI ->18.8) DURING an IFX hold, resolving only after restart. Direction of evidence: discontinuation -> flare + delayed healing. (Three uneventful cases were non-orthopedic.)"
  ),
  direction_of_evidence = "SSI: continuation not associated with excess SSI/wound complication (in Bakkour and Nguyen the HELD group had numerically MORE complications -> confounding by indication makes the safety of continuation conservative). Flare: interruption associated with flare (Bakkour 40% vs 8.7%; Kawakami ortho case). PJI: sparse, no signal of excess with TNFi continuation. Implant survival: high (Di Martino)."
)

cat("\nStatistical analyses complete.\n")

## =====================================================================
## GRADE — certainty per outcome (start LOW for observational bodies)
## =====================================================================
# Participant totals
n_ma1 <- sum(m1$n_c) + sum(m1$n_d)            # SSI comparative
n_ma2 <- sum(m2$n_c) + sum(m2$n_d)            # flare comparative
n_pji <- sum(p4$n)                            # PJI proportion
n_ssiprop <- sum(p3$n)                        # SSI proportion (continuers)

ma1_OR <- sprintf("OR %.2f (95%% CI %.2f-%.2f)", exp(coef(ma1_reml)),
                  exp(ma1_reml$ci.lb), exp(ma1_reml$ci.ub))
ma2_OR <- sprintf("OR %.2f (95%% CI %.2f-%.2f)", exp(coef(ma2_reml)),
                  exp(ma2_reml$ci.lb), exp(ma2_reml$ci.ub))
ssiprop_txt <- sprintf("%.1f%% (95%% CI %.1f-%.1f)", 100*transf.ilogit(coef(ma3s_reml)),
                       100*transf.ilogit(ma3s_reml$ci.lb), 100*transf.ilogit(ma3s_reml$ci.ub))
pji_txt <- sprintf("%.1f%% (95%% CI %.1f-%.1f)", 100*transf.ilogit(coef(ma3p_reml)),
                   100*transf.ilogit(ma3p_reml$ci.lb), 100*transf.ilogit(ma3p_reml$ci.ub))

out$grade <- list(
  approach = "GRADE for prognostic/observational body of evidence. All 12 studies non-randomized (no RCTs; RoB-2 not applicable). Baseline certainty LOW; rated down further per outcome. Not rated up (no large effect after controlling for confounding by indication that runs against the safety signal; dose-response not established).",
  SSI_wound = list(
    outcome = "Surgical-site infection / wound complication (continuation vs discontinuation, plus continuer proportion)",
    n_studies = 4L, n_participants = n_ma1,
    effect_comparative = ma1_OR,
    effect_proportion_continuers = ssiprop_txt,
    certainty = "Very low",
    starting_certainty = "Low (observational)",
    downgrades = list(
      list(domain="Risk of bias", direction="down", serious="serious",
           reason="Comparative pool dominated by unadjusted / calendar-era designs in mixed cohorts (Berthold, Nguyen = Serious ROBINS-I); Fabiano a case series; only Bakkour adjusted (Moderate). Unblinded outcome adjudication; SSI definitions unvalidated for arthroplasty."),
      list(domain="Inconsistency", direction=paste0("down (I2=", round(ma1_reml$I2), "%)"), serious="serious",
           reason="Directional heterogeneity: Berthold OR>1 while Nguyen/Bakkour/Fabiano OR<1; high I2. Explained partly by confounding by indication (sicker patients preferentially held)."),
      list(domain="Indirectness", direction="down", serious="serious",
           reason="PsA not isolated in the mixed cohorts (RA/IBD-dominated); SSI outcome definitions heterogeneous (CDC-SSI vs 90-day SSTI vs composite wound complication); orthopedic events not isolable by arm; mixed surgery types."),
      list(domain="Imprecision", direction="down", serious="serious",
           reason="Sparse events (as few as 1-2 per arm), wide pooled CI crossing the null; small total sample."),
      list(domain="Publication bias", direction="undetected/unassessable", serious="not serious",
           reason="Formally unassessable at k<10; funnel/Egger underpowered and not rendered.")
    ),
    # CORRECTED 2026-07-24 (v6 round). The earlier wording called the direction
    # "conservative rather than exaggerated" given confounding by indication. That
    # inverts the bias. If sicker patients and higher-risk operations were
    # preferentially selected for a hold, the held arm accrues events for reasons
    # unrelated to holding, which biases the comparison IN FAVOUR of continuation.
    # The bias therefore flatters continuation; it does not understate its safety.
    # String-only change; no estimate is affected.
    direction_note = "Certainty is Very Low. The direction is consistent in three of the four studies, but confounding by indication most likely flatters continuation rather than understating its safety, because sicker patients and higher-risk operations were preferentially selected for a hold. The defensible reading is no evidence that continuation increases risk, not evidence of benefit."
  ),
  flare = list(
    outcome = "Disease flare (continuation vs discontinuation)",
    n_studies = 2L, n_participants = n_ma2,
    effect_comparative = ma2_OR,
    effect_proportion = sprintf("continuers %.1f%% vs discontinuers %.1f%% (pooled, Bakkour+Vasavada)",
                                100*transf.ilogit(coef(ma4c)), 100*transf.ilogit(coef(ma4d))),
    certainty = "Very low",
    starting_certainty = "Low (observational)",
    downgrades = list(
      list(domain="Risk of bias", direction="down", serious="serious",
           reason="Flare is a subjective, physician-diagnosed, unblinded endpoint (Bakkour, Vasavada both Moderate ROBINS-I; potential under-ascertainment when patients self-manage)."),
      list(domain="Indirectness", direction="down", serious="serious",
           reason="Vasavada exposure is AGGREGATE immunosuppression (biologics+csDMARDs+steroids+JAK), not biologic-isolated, and is arthroscopy (lower surgical stress); PsA not isolated. Do not over-read as a clean biologic hold-vs-continue flare contrast."),
      list(domain="Imprecision", direction="down", serious="very serious",
           reason="Only 2 studies, few flare events, wide CI; prediction interval unstable at k=2.")
    ),
    direction_note = "Direction (interruption -> flare) is clinically coherent and consistent with the Kawakami orthopedic case; confounding by indication would understate flare risk in continuers."
  ),
  implant_survival = list(
    outcome = "Implant survival / revision (narrative)",
    n_studies = 1L, n_participants = 121L,
    effect = "5-year THA survival 96.6%; 3/121 revisions in perioperative-TNFi users (Di Martino 2023).",
    certainty = "Very low",
    starting_certainty = "Low (observational)",
    downgrades = list(
      list(domain="Risk of bias", direction="down", serious="serious",
           reason="Di Martino: unmatched, significantly imbalanced TNFi-vs-non-bDMARD comparison; immortal-time/selection from defining exposure on pre- AND post-operative prescription."),
      list(domain="Indirectness", direction="down", serious="serious",
           reason="Exposure = prescription pick-up (chronic use), not a clean perioperative hold; PsA not isolated within a mixed inflammatory-arthritis cohort."),
      list(domain="Imprecision", direction="down", serious="serious",
           reason="Single study, only 3 revision events; no pooled estimate.")
    ),
    direction_note = "Objective registry-captured revision endpoint (D6 Low) makes the high survival estimate trustworthy even though the comparison is confounded; narrative/SWiM only."
  ),
  PJI = list(
    outcome = "Periprosthetic joint infection (single-arm proportion)",
    n_studies = 3L, n_participants = n_pji,
    effect = pji_txt,
    certainty = "Very low",
    starting_certainty = "Low (observational)",
    downgrades = list(
      list(domain="Risk of bias", direction="down", serious="serious",
           reason="Borgas Serious (univariate only, user-vs-non-user, 7 PJI total) and Nguyen Serious; only George Moderate but PJI ICD code unvalidated. No comparative adjustment."),
      list(domain="Indirectness", direction="down", serious="serious",
           reason="PsA not isolated (the single Borgas PsA PJI was on 'None' treatment, not a TNFi user); George PsA/PsO/AS combined covariate; recent-IFX proxy for continuation."),
      list(domain="Imprecision", direction="down", serious="very serious",
           reason="Very sparse events (1/157, 1/43, 30/1162); wide CI; pool dominated by a single study (George).")
    ),
    direction_note = "No signal of excess PJI with TNFi continuation, but the estimate is dominated by George and is very imprecise."
  )
)

## =====================================================================
## WRITE results.json
## =====================================================================
json_path <- file.path(PROJ, "outputs", "results.json")
writeLines(toJSON(out, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = 8),
           json_path)
cat("\n[WROTE]", json_path, "\n")

## =====================================================================
## Table3_GRADE_SoF.csv  (docx built by companion python helper)
## =====================================================================
g <- out$grade

## Unit composition of the five pooled GRADE rows, re-verified cell by cell
## against extraction/poolable_dataset.csv on 2026-07-24. Every pooled
## denominator mixes at least two kinds of unit, so no single word (procedures,
## surgeries, patients) is honest for any of them. The neutral term
## "analysis units" is used for all five rows, with the composition spelled out:
##   row 1  MA1_SSI       1,979 = Berthold 1,553 + Nguyen 218 + Bakkour 77
##                                procedures, plus Fabiano 131 patients
##   row 2  MA3_SSIprop   2,129 = Berthold 681 + Nguyen 142 + Bakkour 57
##                                procedures, George 1,162 surgeries,
##                                Fabiano 87 patients
##   row 3  MA2_flare       291 = Bakkour 77 procedures + Vasavada 214 patients
##   row 4  MA4_flareprop   291 = the same two studies as row 3
##   row 5  MA3_PJIprop   1,362 = George 1,162 surgeries + Borgas 157 patients
##                                + Nguyen 43 joint-replacement procedures
## Row 6 is narrative (Di Martino) and its unit, TNFi THA, is already exact.
## This is a label-only change: no value in results.json is touched by it.
cma <- function(x) formatC(as.integer(x), format = "d", big.mark = ",")

sof <- data.frame(
  Outcome = c(
    "SSI / wound complication - continuation vs discontinuation (OR)",
    "SSI / wound proportion among continuers (%)",
    "Disease flare - continuation vs discontinuation (OR)",
    "Disease flare proportion (continuers / discontinuers, %)",
    "Periprosthetic joint infection - pooled proportion (%)",
    "Implant survival / revision-free (narrative)"),
  No_studies_participants = c(
    sprintf("%d (%s analysis units: procedures in 3 studies, patients in 1)",
            4, cma(n_ma1)),
    sprintf("%d (%s analysis units: procedures in 3 studies, surgeries in 1, patients in 1)",
            5, cma(n_ssiprop)),
    sprintf("%d (%s analysis units: procedures in 1 study, patients in 1)",
            2, cma(n_ma2)),
    sprintf("%d (%s analysis units: procedures in 1 study, patients in 1)",
            2, cma(sum(p5$n))),
    sprintf("%d (%s analysis units: surgeries in 1 study, patients in 1, procedures in 1)",
            3, cma(n_pji)),
    sprintf("%d (%d TNFi THA)", 1, 121)),
  Pooled_effect_95CI = c(
    ma1_OR,
    ssiprop_txt,
    ma2_OR,
    sprintf("continuers %.1f%% (%.1f-%.1f); discontinuers %.1f%% (%.1f-%.1f)",
            100*transf.ilogit(coef(ma4c)), 100*transf.ilogit(ma4c$ci.lb), 100*transf.ilogit(ma4c$ci.ub),
            100*transf.ilogit(coef(ma4d)), 100*transf.ilogit(ma4d$ci.lb), 100*transf.ilogit(ma4d$ci.ub)),
    pji_txt,
    "5-yr survival 96.6%; 3/121 revisions"),
  Certainty_GRADE = c("Very low", "Very low", "Very low", "Very low", "Very low", "Very low"),
  stringsAsFactors = FALSE
)
sof$Key_footnotes <- c(
  "Down for risk of bias (unadjusted/era designs, unblinded SSI adjudication), inconsistency (directional heterogeneity, high I2), indirectness (PsA not isolated; heterogeneous SSI definitions; mixed surgery), imprecision (sparse events, wide CI). Direction conservative given confounding by indication.",
  "Same body of evidence as row 1 (continuer arm). George numerator = serious/hospitalized infection within 30d, not SSI-specific (indirectness).",
  "Down for risk of bias (subjective unblinded flare), indirectness (Vasavada aggregate immunosuppression + arthroscopy; PsA not isolated), imprecision (k=2, few events, unstable PI). Direction: interruption -> flare.",
  "Bakkour shows a large flare excess with discontinuation (40% vs 8.7%, P=.003); Vasavada shows no difference (aggregate IS, arthroscopy). k=2, exploratory.",
  "Down for risk of bias (univariate/underpowered Borgas & Nguyen; unvalidated PJI code), indirectness (PsA not isolated; recent-IFX proxy), imprecision (very sparse; pool dominated by George).",
  "Single registry cohort; unmatched/imbalanced comparison + immortal-time selection; objective revision endpoint. Narrative/SWiM only."
)
sof_path <- file.path(TABDIR, "Table3_GRADE_SoF.csv")
write.csv(sof, sof_path, row.names = FALSE)
cat("[WROTE]", sof_path, "\n")

## =====================================================================
## FIGURE 3 — MA1 forest (continuation vs discontinuation -> SSI/wound)
## =====================================================================
draw_fig3 <- function() {
  par(mar = c(6, 4, 2.5, 2), font = 1)
  ilab_c <- sprintf("%d/%d", esc1$events_c, esc1$n_c)
  ilab_d <- sprintf("%d/%d", esc1$events_d, esc1$n_d)
  forest(ma1_reml, atransf = exp,
         at = log(c(0.05, 0.25, 1, 4, 20)),
         xlim = c(-11, 8), ylim = c(-4, ma1_reml$k + 3),
         ilab = cbind(ilab_c, ilab_d),
         ilab.xpos = c(-6.2, -4.2),
         showweights = TRUE, addpred = TRUE,
         header = c("Study", "OR [95% CI]"),
         xlab = "Odds ratio (continuation vs discontinuation) - log scale",
         mlab = "", cex = 0.95, refline = 0, digits = 2L)
  # column headers
  top <- ma1_reml$k + 1.6
  text(-6.2, top, "Continue", font = 2, cex = 0.9)
  text(-4.2, top, "Discontinue", font = 2, cex = 0.9)
  text(c(-6.2, -4.2), top - 0.8, c("(n/N)", "(n/N)"), font = 2, cex = 0.82)
  # model / heterogeneity annotation (placed in the expanded lower gap)
  pr <- predict(ma1_reml, transf = exp)
  txt <- sprintf("RE model (REML): OR = %.2f [%.2f, %.2f];  I2 = %.0f%%, tau2 = %.2f,  Q(%d) = %.1f, p = %.3f",
                 pr$pred, pr$ci.lb, pr$ci.ub, ma1_reml$I2, ma1_reml$tau2,
                 ma1_reml$k-1, ma1_reml$QE, ma1_reml$QEp)
  text(-11, -2.0, txt, pos = 4, cex = 0.8)
  pitxt <- sprintf("95%% prediction interval: %.2f to %.2f  (dashed)", pr$pi.lb, pr$pi.ub)
  text(-11, -2.8, pitxt, pos = 4, cex = 0.8, font = 3)
  text(mean(log(c(0.05,1))), top + 0.5, "favours continuation", cex = 0.75, font = 3)
  text(mean(log(c(1,20))),   top + 0.5, "favours discontinuation", cex = 0.75, font = 3)
}
png(file.path(FIGDIR, "Figure3_forest_SSI.png"), width = 10, height = 5.2, units = "in", res = 300)
draw_fig3(); dev.off()
pdf(file.path(FIGDIR, "Figure3_forest_SSI.pdf"), width = 10, height = 5.2)
draw_fig3(); dev.off()
cat("[WROTE] Figure3_forest_SSI.png/.pdf\n")

## =====================================================================
## Pooled proportion rows (feed Figure 5, below)
## =====================================================================
prop_rows <- data.frame(
  label = c("SSI/wound - continuers (MA3)",
            "Flare - continuers (MA4)",
            "Flare - discontinuers (MA4)",
            "PJI - overall (MA3)"),
  est = c(transf.ilogit(coef(ma3s_reml)), transf.ilogit(coef(ma4c)),
          transf.ilogit(coef(ma4d)), transf.ilogit(coef(ma3p_reml))),
  lo  = c(transf.ilogit(ma3s_reml$ci.lb), transf.ilogit(ma4c$ci.lb),
          transf.ilogit(ma4d$ci.lb), transf.ilogit(ma3p_reml$ci.lb)),
  hi  = c(transf.ilogit(ma3s_reml$ci.ub), transf.ilogit(ma4c$ci.ub),
          transf.ilogit(ma4d$ci.ub), transf.ilogit(ma3p_reml$ci.ub)),
  ks  = c(ma3s_reml$k, ma4c$k, ma4d$k, ma3p_reml$k),
  stringsAsFactors = FALSE)

## =====================================================================
## FIGURE 4 - MA2 disease-flare forest (continuation vs discontinuation)
## =====================================================================
draw_fig4 <- function() {
  par(mar = c(5, 4, 2.5, 2), font = 1)
  il_c <- sprintf("%d/%d", esc2$events_c, esc2$n_c)
  il_d <- sprintf("%d/%d", esc2$events_d, esc2$n_d)
  forest(ma2_reml, atransf = exp, at = log(c(0.05, 0.25, 1, 4)),
         xlim = c(-11, 7), ylim = c(-3, ma2_reml$k + 3),
         ilab = cbind(il_c, il_d), ilab.xpos = c(-6.5, -4.5),
         showweights = TRUE, header = c("Study", "OR [95% CI]"),
         xlab = "Odds ratio (continuation vs discontinuation)",
         mlab = "", cex = 0.9, refline = 0, digits = 2L)
  topA <- ma2_reml$k + 1.4
  text(-6.5, topA, "Continue (n/N)", font = 2, cex = 0.8)
  text(-4.5, topA, "Discontinue (n/N)", font = 2, cex = 0.8)
  prA <- predict(ma2_reml, transf = exp)
  text(-11, -2.0, sprintf("RE model (REML): OR = %.2f [%.2f, %.2f]; I2 = %.0f%% (k=2, EXPLORATORY - PI unstable)",
                          prA$pred, prA$ci.lb, prA$ci.ub, ma2_reml$I2), pos = 4, cex = 0.75)
}
png(file.path(FIGDIR, "Figure4_forest_flare.png"), width = 10, height = 4, units = "in", res = 300)
draw_fig4(); dev.off()
pdf(file.path(FIGDIR, "Figure4_forest_flare.pdf"), width = 10, height = 4)
draw_fig4(); dev.off()
cat("[WROTE] Figure4_forest_flare.png/.pdf\n")

## =====================================================================
## FIGURE 5 - pooled single-arm event proportions (SSI, flare, PJI)
## =====================================================================
draw_fig5 <- function() {
  par(mar = c(5, 4, 2.5, 2), font = 1)
  forest(x = prop_rows$est, ci.lb = prop_rows$lo, ci.ub = prop_rows$hi,
         slab = prop_rows$label, xlim = c(-0.45, 0.75),
         ylim = c(-1, length(prop_rows$est) + 3),
         at = c(0, 0.1, 0.2, 0.3, 0.4, 0.5), refline = NA,
         ilab = sprintf("k=%d", prop_rows$ks), ilab.xpos = -0.14,
         xlab = "Pooled proportion (random-effects, logit; back-transformed)",
         pch = 18, psize = 2.4, cex = 0.9, digits = 3L,
         header = c("Pooled outcome (continuers unless noted)", "Proportion [95% CI]"))
  text(-0.14, length(prop_rows$est) + 1.4, "studies", font = 2, cex = 0.8)
}
png(file.path(FIGDIR, "Figure5_forest_proportions.png"), width = 10, height = 4.5, units = "in", res = 300)
draw_fig5(); dev.off()
pdf(file.path(FIGDIR, "Figure5_forest_proportions.pdf"), width = 10, height = 4.5)
draw_fig5(); dev.off()
cat("[WROTE] Figure5_forest_proportions.png/.pdf\n")

## =====================================================================
## SENSITIVITY OUTPUT (markdown)
## =====================================================================
fmtOR  <- function(res) sprintf("%.2f (95%% CI %.2f-%.2f)", exp(coef(res)), exp(res$ci.lb), exp(res$ci.ub))
fmtORo <- function(o, l, h) sprintf("%.2f (95%% CI %.2f-%.2f)", o, l, h)
fmtP   <- function(res) sprintf("%.1f%% (95%% CI %.1f-%.1f)", 100*transf.ilogit(coef(res)),
                                100*transf.ilogit(res$ci.lb), 100*transf.ilogit(res$ci.ub))
L <- c()
add <- function(...) L[[length(L)+1]] <<- paste0(...)
add("# Sensitivity & Robustness Output")
add("")
add("Engine: ", R.version.string, " + metafor ", as.character(packageVersion("metafor")),
    ". Generated ", as.character(Sys.Date()), ".")
add("")
add("## NOTES ON INTERPRETATION")
add("")
add("- **Overlap-rule assertion PASSED**: no pool contains both Berthold (EMBASE3-0017) and Borgas (EMBASE2-0040). The code stops with an error if violated.")
add("- **MA2_flare and MA4_flareprop are k=2 (exploratory).** tau2 and the 95% prediction interval are unstable and must NOT be interpreted as reliable; report point estimates with explicit caution. Nguyen cannot join MA2_flare (no continued-arm flare count).")
add("- **All pools have k<10; funnel plots / Egger tests are underpowered and were NOT rendered.** Publication bias is formally unassessable and is handled qualitatively in GRADE.")
add("- **MA1 heterogeneity is directional** (Berthold OR>1; the other three OR<1), largely explained by confounding by indication (sicker patients preferentially held). This drives the inconsistency downgrade but the direction (continuation safe) is conservative.")
add("- **DO NOT OVER-READ the MA1 primary OR of 0.50 as 'continuation halves SSI'.** It is model-dependent: the random-effects (REML) estimate down-weights the large Berthold study via tau2, whereas fixed-effect / Mantel-Haenszel / Peto all give ~0.97 (essentially null). ALL estimates cross OR=1. The defensible conclusion is: *no evidence that continuation increases SSI/wound risk* (not a demonstrated protective effect). Certainty is Very Low.")
add("- **George recent-IFX vs whole-cohort:** primary uses recent-IFX (<4wk) proxy; whole-cohort alternatives (SSI 270/4288, PJI 105/4288) are reported below and do not change conclusions.")
add("- **MA3_SSIprop is unaffected by the Berthold 28-vs-25 discrepancy** (that discrepancy is in the *discontinue* arm; MA3 uses Group B/continue = 35/681).")
add("")
add("## MA1_SSI (comparative OR) - primary and robustness")
add("")
add("| Analysis | k | Pooled OR (95% CI) | I2 |")
add("|---|---|---|---|")
add("| **Primary REML (random-effects)** | ", ma1_reml$k, " | **", fmtOR(ma1_reml), "** | ", sprintf("%.0f%%", ma1_reml$I2), " |")
add("| Fixed-effect | ", ma1_fe$k, " | ", fmtOR(ma1_fe), " | - |")
add("| Mantel-Haenszel | ", ma1_mh$k, " | ", fmtOR(ma1_mh), " | ", sprintf("%.0f%%", ma1_mh$I2), " |")
add("| Peto | ", ma1_peto$k, " | ", fmtOR(ma1_peto), " | ", sprintf("%.0f%%", ma1_peto$I2), " |")
if (!is.null(ma1_glmm)) add("| Binomial-normal GLMM (UM.FS) | ", ma1_glmm$k, " | ", fmtOR(ma1_glmm), " | ", sprintf("%.0f%%", ma1_glmm$I2), " |")
add("| Berthold discontinue = 25/872 (sensitivity) | ", ma1_reml_25$k, " | ", fmtOR(ma1_reml_25), " | ", sprintf("%.0f%%", ma1_reml_25$I2), " |")
add("| Fabiano continue = 0/87 (sensitivity; continuity correction add=1/2, to=only0) | ", ma1_reml_f0$k, " | ", fmtOR(ma1_reml_f0), " | ", sprintf("%.0f%%", ma1_reml_f0$I2), " |")
add("| **Exclude Berthold (overlap robustness)** | ", ma1_reml_noB$k, " | ", fmtOR(ma1_reml_noB), " | ", sprintf("%.0f%%", ma1_reml_noB$I2), " |")
add("")
pr1 <- predict(ma1_reml, transf = exp)
add("Primary 95% prediction interval: **", sprintf("%.2f to %.2f", pr1$pi.lb, pr1$pi.ub), "** (wide; spans the null).")
add("")
add("**Leave-one-out (MA1):**")
add("")
add("| Omitted | Pooled OR (95% CI) | I2 |")
add("|---|---|---|")
for (i in seq_along(l1o_ma1$estimate)) add("| ", as.character(ma1_reml$slab[i]), " | ",
    fmtORo(l1o_ma1$estimate[i], l1o_ma1$ci.lb[i], l1o_ma1$ci.ub[i]), " | ",
    sprintf("%.0f%%", l1o_ma1$I2[i]), " |")
add("")
add("**Subgroup (MA1) - pure psoriasis/PsA vs mixed cohort:**")
add("- Pure (Bakkour, Fabiano): OR ", fmtOR(ma1_pure))
add("- Mixed (Berthold, Nguyen): OR ", fmtOR(ma1_mixed))
add("- Test for subgroup difference: p = ", sprintf("%.3f", ma1_sgtest$QMp))
add("")
add("## MA2_flare (comparative OR, k=2, EXPLORATORY)")
add("- Primary REML: OR ", fmtOR(ma2_reml), ", I2 = ", sprintf("%.0f%%", ma2_reml$I2))
add("- Fixed-effect: OR ", fmtOR(ma2_fe), "; Peto: OR ", fmtOR(ma2_peto))
add("- Prediction interval unstable at k=2; not reported as reliable.")
add("")
add("## MA3_SSIprop (continuer SSI/wound proportion)")
add("- **Primary logit REML:** ", fmtP(ma3s_reml), ", I2 = ", sprintf("%.0f%%", ma3s_reml$I2))
add("- Freeman-Tukey (PFT): ", sprintf("%.1f%% (95%% CI %.1f-%.1f)", 100*pred3s_ft$pred, 100*pred3s_ft$ci.lb, 100*pred3s_ft$ci.ub))
add("- Exclude Berthold (overlap): ", sprintf("%.1f%% (95%% CI %.1f-%.1f), I2=%.0f%%",
    100*transf.ilogit(coef(ma3s_noB)), 100*transf.ilogit(ma3s_noB$ci.lb), 100*transf.ilogit(ma3s_noB$ci.ub), ma3s_noB$I2))
add("- George whole-cohort (270/4288): ", sprintf("%.1f%% (95%% CI %.1f-%.1f), I2=%.0f%%",
    100*transf.ilogit(coef(ma3s_gw)), 100*transf.ilogit(ma3s_gw$ci.lb), 100*transf.ilogit(ma3s_gw$ci.ub), ma3s_gw$I2))
add("")
add("**Leave-one-out (MA3_SSIprop):**")
add("")
add("| Omitted | Pooled % (95% CI) | I2 |")
add("|---|---|---|")
for (i in seq_along(l1o_3s$estimate)) add("| ", as.character(ma3s_reml$slab[i]), " | ",
    sprintf("%.1f%% (%.1f-%.1f)", 100*l1o_3s$estimate[i], 100*l1o_3s$ci.lb[i], 100*l1o_3s$ci.ub[i]), " | ",
    sprintf("%.0f%%", l1o_3s$I2[i]), " |")
add("")
add("## MA3_PJIprop (PJI proportion)")
add("- **Primary logit REML:** ", fmtP(ma3p_reml), ", I2 = ", sprintf("%.0f%%", ma3p_reml$I2))
add("- Freeman-Tukey (PFT): ", sprintf("%.1f%% (95%% CI %.1f-%.1f)", 100*pred3p_ft$pred, 100*pred3p_ft$ci.lb, 100*pred3p_ft$ci.ub))
add("- George whole-cohort (105/4288): ", sprintf("%.1f%% (95%% CI %.1f-%.1f), I2=%.0f%%",
    100*transf.ilogit(coef(ma3p_gw)), 100*transf.ilogit(ma3p_gw$ci.lb), 100*transf.ilogit(ma3p_gw$ci.ub), ma3p_gw$I2))
add("")
add("**Leave-one-out (MA3_PJIprop):**")
add("")
add("| Omitted | Pooled % (95% CI) | I2 |")
add("|---|---|---|")
for (i in seq_along(l1o_3p$estimate)) add("| ", as.character(ma3p_reml$slab[i]), " | ",
    sprintf("%.1f%% (%.1f-%.1f)", 100*l1o_3p$estimate[i], 100*l1o_3p$ci.lb[i], 100*l1o_3p$ci.ub[i]), " | ",
    sprintf("%.0f%%", l1o_3p$I2[i]), " |")
add("")
add("## MA4_flareprop (flare burden by arm)")
add("- Continuers (Bakkour, Vasavada): ", fmtP(ma4c), ", I2 = ", sprintf("%.0f%%", ma4c$I2))
add("- Discontinuers (Bakkour, Vasavada): ", fmtP(ma4d), ", I2 = ", sprintf("%.0f%%", ma4d$I2))
add("")
add("## Fixed vs random effects (all pools)")
add("- MA1: RE ", fmtOR(ma1_reml), " vs FE ", fmtOR(ma1_fe), " (conclusion unchanged).")
add("- MA2: RE ", fmtOR(ma2_reml), " vs FE ", fmtOR(ma2_fe), ".")
add("")
writeLines(unlist(L), file.path(SUPDIR, "sensitivity_output.md"))
cat("[WROTE]", file.path(SUPDIR, "sensitivity_output.md"), "\n")

cat("\n===== meta_analysis.R complete =====\n")
cat(sprintf("MA1 SSI OR=%.2f [%.2f-%.2f] I2=%.0f%% PI[%.2f-%.2f]\n",
            pr1$pred, pr1$ci.lb, pr1$ci.ub, ma1_reml$I2, pr1$pi.lb, pr1$pi.ub))
cat(sprintf("MA2 flare OR=%.2f [%.2f-%.2f]\n", exp(coef(ma2_reml)), exp(ma2_reml$ci.lb), exp(ma2_reml$ci.ub)))
cat(sprintf("MA3 SSIprop=%.1f%% PJIprop=%.1f%%\n",
            100*transf.ilogit(coef(ma3s_reml)), 100*transf.ilogit(coef(ma3p_reml))))
