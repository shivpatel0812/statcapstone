# Analysis Guide: Diet, Exercise, and Health Outcomes

This guide maps your research questions to NHANES 2021–2023 data, specifies what to add to your current dataset, and suggests concrete analyses.

---

## 1. Data You Currently Have

| Domain | Variables | Notes |
|--------|-----------|-------|
| **Diet** | `total_calories`, `total_protein`, `total_carbs`, `total_fat`, `total_sugar`, `total_fiber`, `total_cholesterol` | Person-level (Day 1 recall); n=6,751 |
| **Physical activity** | `PAD680` (moderate-intensity min/week), `PAD800` (work), `PAD820` (transport) | n=4,980 with PAD680 |
| **Diet behavior** | `DBQ010` (perceived diet health), meal sources (DBQ301, DBQ330, etc.) | High missingness on many DBQ vars |

---

## 2. Additional NHANES Datasets to Merge (by SEQN)

### Must-have for your research questions

| File | Purpose | Key variables |
|------|---------|---------------|
| **DEMO_L** | Demographics, sample weights | `RIDAGEYR` (age), `RIAGENDR` (sex), `RIDRETH3` (race/ethnicity), `INDFMPIR` (poverty ratio), `WTMEC2YR` (exam weight) |
| **BMX_L** | BMI / anthropometrics | `BMXBMI`, `BMXWAIST`, `BMXWT`, `BMXHT` |
| **BPXO_L** | Blood pressure | `BPXPLS`, `BPXSY*`, `BPXDI*` (multiple readings; often averaged) |
| **GLU_L** | Fasting plasma glucose | `LBDGLUSI` (glucose mmol/L); requires fasting subsample |
| **GHB_L** | Glycated hemoglobin (HbA1c) | `LBXGH` (no fasting needed) |
| **HDL_L** | HDL cholesterol | `LBDHDDSI` |
| **TCHOL_L** | Total cholesterol | `LBXTC` |

### Lifestyle modifiers (stress, sleep, smoking)

| File | Purpose | Key variables |
|------|---------|---------------|
| **DPQ_L** | Depression / distress (proxy for stress) | `DPQ010`–`DPQ090` (PHQ-9 items); **`DPQ020`** (little interest), **total score** |
| **SLQ_L** | Sleep | `SLQ300`, `SLQ310` (weekday sleep/wake); `SLD012`, `SLD013` (derived sleep hours) |
| **SMQ_L** | Smoking | `SMQ020` (ever smoked 100+ cigarettes), `SMQ040` (current smoking status) |

### Optional: baseline health

| File | Purpose | Key variables |
|------|---------|---------------|
| **DIQ_L** | Diabetes | `DIQ010` (doctor told you have diabetes) |
| **MCQ_L** | Medical conditions | Heart disease, hypertension, etc. |

---

## 3. What to Examine for Each Research Question

### 3.1 Why can the same diet/exercise lead to different health outcomes?

**Concepts: effect modification and individual heterogeneity**

| What to look at | How |
|-----------------|-----|
| **Stratified associations** | Run the same model (e.g., activity → BMI) separately in high vs. low stress, short vs. adequate sleep, male vs. female |
| **Interaction terms** | `activity × stress`, `activity × sleep`, `activity × sex`; interpret and plot |
| **Residual variation** | In regression, look at residual variance; consider mixed models or quantile regression if appropriate |
| **Demographic subgroups** | Age (e.g., 18–40 vs. 40+), sex, race/ethnicity, income |

### 3.2 Do associations between diet/exercise and health differ across subgroups?

**Subgroups to define**

| Subgroup | Source | Coding |
|----------|--------|--------|
| **Stress** | DPQ_L | PHQ-9 total score; dichotomize (e.g., &lt;10 vs. ≥10) or tertiles |
| **Sleep** | SLQ_L | Sleep duration (e.g., &lt;6 vs. 6–9 vs. &gt;9 h); short/adequate/long |
| **Diet quality** | Your data | tertiles of fiber, sugar, or a simple diet score |
| **Smoking** | SMQ_L | Never / former / current |
| **Demographics** | DEMO_L | Age groups, sex, race/ethnicity, poverty |

**Analyses**

- **Stratified regressions** by each subgroup (e.g., activity → glucose in each stress group)
- **Interaction models** (e.g., activity × stress, activity × sleep)
- **Forest plots** of effect estimates across subgroups

### 3.3 How do activity patterns relate to clinical markers?

**Activity variables**

- `PAD680`: total moderate-intensity minutes/week
- Create groups: low (&lt;150), moderate (150–300), high (&gt;300) or tertiles/quartiles
- Use `PAD800`, `PAD820` to compare work vs. transport activity if sample size permits

**Clinical outcomes**

| Outcome | File | Variable |
|---------|------|----------|
| BMI | BMX_L | `BMXBMI` |
| Waist circumference | BMX_L | `BMXWAIST` |
| Systolic BP | BPXO_L | Average of `BPXSY1`, `BPXSY2`, `BPXSY3`, `BPXSY4` |
| Diastolic BP | BPXO_L | Average of `BPXDI1`–`BPXDI4` |
| Fasting glucose | GLU_L | `LBDGLUSI` |
| HbA1c | GHB_L | `LBXGH` |
| HDL | HDL_L | `LBDHDDSI` |
| Total cholesterol | TCHOL_L | `LBXTC` |

**Analyses**

- ANOVA / Kruskal–Wallis: compare mean BMI, glucose, BP across activity groups
- Linear regression: activity (continuous or categorical) → each outcome
- Covariance adjustment: add diet, smoking, sleep, demographics

### 3.4 Is physical activity always associated with better health?

**Concepts: confounding and residual confounding**

| What to check | How |
|---------------|-----|
| **Unadjusted vs adjusted** | Compare coefficients before/after adding diet, smoking, sleep |
| **Confounders** | Age, sex, race, income, BMI (if outcome is not BMI), diet quality, smoking, sleep |
| **Different activity types** | Work vs. transport; some types may show weaker associations |
| **Nonlinearity** | Splines or activity categories; check if very high activity differs from moderate |

**Model sequence**

1. Activity → outcome (unadjusted)
2. + demographics (age, sex, race)
3. + diet (calories, fiber or diet score)
4. + smoking
5. + sleep
6. Full model

If the activity–outcome association shrinks with confounders, that suggests lifestyle/behavior explains part of the benefit.

### 3.5 Main analysis: activity + clinical outcomes, moderated by stress, sleep, diet

**Proposed models**

```
Outcome ~ Activity + Stress + Sleep + Diet_quality + (Activity × Stress) + (Activity × Sleep) + covariates
```

**Outcomes:** BMI, systolic BP, HbA1c (or fasting glucose), HDL  
**Covariates:** age, sex, race, income, smoking

**Steps**

1. Merge DEMO, BMX, BPXO, GLU/GHB, HDL, DPQ, SLQ, SMQ to your combined diet/activity data.
2. Create:
   - Activity groups (low / moderate / high)
   - Stress groups (e.g., PHQ-9 &lt;10 vs. ≥10)
   - Sleep groups (short / adequate / long)
   - Diet quality groups (tertiles of fiber or a simple score)
3. Run main-effects models first, then add interactions.
4. Interpret and plot key interactions (e.g., activity × stress on BMI).

---

## 4. Variable Creation Suggestions

### Diet quality score (simplified)

- Fiber (higher = better), sugar (lower = better), fruit/veg proxies if available
- Or tertiles of `total_fiber` as a simple diet-quality proxy

### Activity groups

- Low: &lt;150 min moderate/week  
- Moderate: 150–300  
- High: &gt;300  

### Sleep duration

- From SLQ: compute weekday sleep hours  
- Short: &lt;6 h, Adequate: 6–9 h, Long: &gt;9 h  

### Stress (DPQ / PHQ-9)

- Sum items for total score (0–27)  
- Low: &lt;10, High: ≥10  

---

## 5. Data Download Links (NHANES 2021–2023)

All from: https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx

- **Demographics:** [DEMO_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DEMO_L.xpt)
- **Body measures:** [BMX_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/BMX_L.xpt)
- **Blood pressure:** [BPXO_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/BPXO_L.xpt)
- **Plasma glucose:** [GLU_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/GLU_L.xpt)
- **Glycohemoglobin:** [GHB_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/GHB_L.xpt)
- **HDL:** [HDL_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/HDL_L.xpt)
- **Total cholesterol:** [TCHOL_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/TCHOL_L.xpt)
- **Depression (stress proxy):** [DPQ_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/DPQ_L.xpt)
- **Sleep:** [SLQ_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/SLQ_L.xpt)
- **Smoking:** [SMQ_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/SMQ_L.xpt)

---

## 6. Limitations and Considerations

1. **DPQ as stress:** DPQ is a depression screener (PHQ-9); use as a proxy for psychological distress, not direct stress.
2. **GLU vs. GHB:** GLU is fasting only; GHB does not require fasting and has broader coverage.
3. **Sample weights:** Use `WTMEC2YR` (and design variables) for nationally representative inference.
4. **Missing data:** Activity (~26% missing), DBQ (very high missingness); consider multiple imputation or sensitivity analyses.
5. **Causality:** Cross-sectional; associations only, no causal claims.
6. **Sleep in 2021–2023:** SLQ focuses on sleep/wake times; no detailed sleep-disorder questions.

---

## 7. Quick Reference: Analysis Checklist

- [ ] Download and merge DEMO_L, BMX_L, BPXO_L, GLU_L or GHB_L, HDL_L, DPQ_L, SLQ_L, SMQ_L
- [ ] Create activity groups (low / moderate / high)
- [ ] Create stress groups (PHQ-9)
- [ ] Create sleep duration groups
- [ ] Create diet quality groups
- [ ] Run: Activity → BMI, BP, glucose/HbA1c (unadjusted and adjusted)
- [ ] Run stratified analyses by stress, sleep, sex
- [ ] Add interaction terms (activity × stress, activity × sleep)
- [ ] Plot effect estimates and interactions
- [ ] Report sample sizes and missing data by analysis
