SELECT DISTINCT
    yug.patienthealthsystemstayid 
  , yug.patientunitstayid
  , yug.gender
  , CASE WHEN yug.gender = 'Female' THEN 1 ELSE 0 END AS sex_female
  , yug.age as anchor_age
  , yug.ethnicity as race
  , CASE 
      WHEN (
        LOWER(yug.ethnicity) LIKE "%caucasian%" 
      ) THEN "White"
      WHEN (
        LOWER(yug.ethnicity) LIKE "%african american%"
      ) THEN "Black"
      WHEN (
         LOWER(yug.ethnicity) LIKE "%hispanic%"
      ) THEN "Hispanic"
      WHEN (
         LOWER(yug.ethnicity) LIKE "%asian%"
      ) THEN "Asian"
      ELSE "Other"
    END AS race_group
  , yug.admissionweight AS weight_admit
  , yug.hospitaladmitsource AS adm_type
  , yug.hospitaldischargeyear AS anchor_year_group
  , yug.los_icu
  , icustay_detail.unitvisitnumber

  , yug.Charlson as CCI
  , CASE 
      WHEN ( yug.Charlson >= 0 AND yug.Charlson <= 3) THEN "0-3"
      WHEN ( yug.Charlson >= 4 AND yug.Charlson <= 6) THEN "4-6" 
      WHEN ( yug.Charlson >= 7 AND yug.Charlson <= 10) THEN "7-10" 
      WHEN ( yug.Charlson > 10) THEN ">10" 
    END AS CCI_ranges

  , yug.sofa_admit as SOFA 
  , CASE 
      WHEN ( yug.sofa_admit >= 0 AND yug.sofa_admit <= 3) THEN "0-3"
      WHEN ( yug.sofa_admit >= 4 AND yug.sofa_admit <= 6) THEN "4-6" 
      WHEN ( yug.sofa_admit >= 7 AND yug.sofa_admit <= 10) THEN "7-10" 
      WHEN ( yug.sofa_admit > 10) THEN ">10" 
    END AS SOFA_ranges

-- Treatments and their offsets
  , CASE 
      WHEN 
           yug.vent IS TRUE
        OR vent_yes > 0
      THEN 1
      ELSE 0
    END AS mech_vent

  , CASE 
      WHEN 
           yug.rrt IS TRUE
        OR rrt_yes > 0
      THEN 1
      ELSE 0
    END AS rrt

  , CASE 
      WHEN 
           yug.vasopressor IS TRUE
        OR vp_yes > 0
      THEN 1
      ELSE 0
    END AS vasopressor
  
  , vent_start_offset
  , rrt_start_offset
  , vp_start_offset

  , SAFE_DIVIDE(vent_start_offset,(24*60)) AS mv_time_d -- convert from minutes to days, in MIMIC it's from hours to days
  , SAFE_DIVIDE(rrt_start_offset,(24*60)) AS rrt_time_d
  , SAFE_DIVIDE(vp_start_offset,(24*60)) AS vp_time_d
  , SAFE_DIVIDE(SAFE_DIVIDE(vent_duration,(24*60)),yug.los_icu) AS MV_time_perc_of_stay
 -- , SAFE_DIVIDE(SAFE_DIVIDE(vp_time_hr,(24*60)),yug.los_icu) AS VP_time_perc_of_stay -- omitted as not easily feasible in eICU

  , cancer.has_cancer
  , cancer.group_solid
  , cancer.group_metastasized
  , cancer.group_hematological
  , cancer.loc_colon_rectal
  , cancer.loc_liver_bd
  , cancer.loc_pancreatic
  , cancer.loc_lung_bronchus
  , cancer.loc_melanoma
  , cancer.loc_breast
  , cancer.loc_endometrial
  , cancer.loc_prostate
  , cancer.loc_kidney
  , cancer.loc_bladder
  , cancer.loc_thyroid
  , cancer.loc_nhl
  , cancer.loc_leukemia
  , coms.hypertension_present AS com_hypertension_present
  , coms.heart_failure_present AS com_heart_failure_present
  , coms.copd_present AS com_copd_present
  , coms.asthma_present AS com_asthma_present
  , coms.ckd_stages AS com_ckd_stages

  , CASE
      WHEN codes.first_code IS NULL
        OR codes.first_code = "No blood draws" 
        OR codes.first_code = "No blood products"
        OR codes.first_code = "Full therapy"
      THEN 1
      ELSE 0
    END AS is_full_code_admission
  
  , CASE
      WHEN codes.last_code IS NULL
        OR codes.last_code = "No blood draws" 
        OR codes.last_code = "No blood products"
        OR codes.last_code = "Full therapy"
      THEN 1
      ELSE 0
    END AS is_full_code_discharge

  , CASE 
      WHEN yug.unitdischargelocation = "Death"
        OR yug.unitdischargestatus = "Expired"
        OR yug.hospitaldischargestatus = "Expired"
      THEN 1
      ELSE 0
    END AS mortality_in 


FROM `db_name.my_eICU.yugang` AS yug


LEFT JOIN(
  SELECT patientunitstayid, unitvisitnumber
  FROM `physionet-data.eicu_crd_derived.icustay_detail`
) 
AS icustay_detail
ON icustay_detail.patientunitstayid = yug.patientunitstayid

LEFT JOIN(
  SELECT *
  FROM `db_name.my_eICU.aux_treatments`
)
AS treatments
ON treatments.patientunitstayid = yug.patientunitstayid


LEFT JOIN(
  SELECT *
  FROM `db_name.my_eICU.pivoted_cancer`
)
AS cancer
ON cancer.patientunitstayid = yug.patientunitstayid

LEFT JOIN(
  SELECT *
  FROM `db_name.my_eICU.pivoted_comorbidities`
)
AS coms
ON coms.patientunitstayid = yug.patientunitstayid

LEFT JOIN(
  SELECT *
  FROM `db_name.my_eICU.pivoted_codes`
)
AS codes
ON codes.patientunitstayid = yug.patientunitstayid 

ORDER BY yug.patienthealthsystemstayid, yug.patientunitstayid
