library CMS71FHIRSTKAnticoagAFFlutter version '0.3.001'

using QICore version '4.1.1'

/* 2025 AU */


include FHIRHelpers version '4.4.000' called FHIRHelpers
include CQMCommon version '2.2.000' called CQMCommon
include QICoreCommon version '2.1.000' called QICoreCommon
include SupplementalDataElements version '3.5.000' called SDE
include TJCOverall version '8.15.000' called TJC

valueset "Anticoagulant Therapy": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.200'
valueset "Atrial Ablation": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.203'
valueset "Atrial Fibrillation or Flutter": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.202'
valueset "Discharge To Acute Care Facility": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.87'
valueset "Discharged to Health Care Facility for Hospice Care": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.207'
valueset "Discharged to Home for Hospice Care": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.209'
valueset "History of Atrial Ablation": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1110.76'
valueset "Left Against Medical Advice": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.308'
valueset "Medical Reason For Not Providing Treatment": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.473'
valueset "Patient Expired": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.309'
valueset "Patient Refusal": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.117.1.7.1.93'

parameter "Measurement Period" Interval<DateTime>
  default Interval[@2026-01-01T00:00:00.000Z, @2026-12-31T23:59:59.999Z]

context Patient

define "Initial Population":
  TJC."Ischemic Stroke Encounter"

define "Denominator":
  "Encounter With A History Of Atrial Ablation"
    union "Encounter With Prior Or Present Diagnosis Of Atrial Fibrillation Or Flutter"

define "Encounter With A History Of Atrial Ablation":
  ( TJC."Ischemic Stroke Encounter" IschemicStrokeEncounter
      where exists ( ["Procedure": "Atrial Ablation"] AtrialAblationProcedure
          where AtrialAblationProcedure.status = 'completed'
            and AtrialAblationProcedure.performed.toInterval ( ) starts before start of IschemicStrokeEncounter.period
      )
  )
    union ( TJC."Ischemic Stroke Encounter" IschemicStrokeEncounter
        with ["Condition": "History of Atrial Ablation"] AtrialAblationDiagnosis
          such that AtrialAblationDiagnosis.verificationStatus is not null
            and AtrialAblationDiagnosis.verificationStatus ~ QICoreCommon."confirmed"
            and AtrialAblationDiagnosis.onset.toInterval ( ) starts before start of IschemicStrokeEncounter.period
    )
    union ( TJC."Ischemic Stroke Encounter" IschemicStrokeEncounter
        with ["Observation": "History of Atrial Ablation"] AtrialAblationObservation
          such that AtrialAblationObservation.status in { 'final', 'amended', 'corrected' }
            and AtrialAblationObservation.effective.earliest ( ) on or before end of IschemicStrokeEncounter.period
    )

define "Encounter With Prior Or Present Diagnosis Of Atrial Fibrillation Or Flutter":
  ( TJC."Ischemic Stroke Encounter" IschemicStrokeEncounter
      with ["Condition": "Atrial Fibrillation or Flutter"] AtrialFibrillationFlutter
        such that AtrialFibrillationFlutter.verificationStatus is not null
          and AtrialFibrillationFlutter.verificationStatus ~ QICoreCommon."confirmed"
          and AtrialFibrillationFlutter.onset.toInterval ( ) starts on or before end of IschemicStrokeEncounter.period
  )
    union TJC."Ischemic Stroke Encounter" IschemicStrokeEncounter
      where exists ( ( IschemicStrokeEncounter.encounterDiagnosis ( ) ) EncounterDiagnosis
          where EncounterDiagnosis.code in "Atrial Fibrillation or Flutter"
      )

define "Denominator Exclusions":
  ( "Denominator" Encounter
      where Encounter.status = 'finished'
        and ( Encounter.hospitalization.dischargeDisposition in "Discharge To Acute Care Facility"
            or Encounter.hospitalization.dischargeDisposition in "Left Against Medical Advice"
            or Encounter.hospitalization.dischargeDisposition in "Patient Expired"
            or Encounter.hospitalization.dischargeDisposition in "Discharged to Home for Hospice Care"
            or Encounter.hospitalization.dischargeDisposition in "Discharged to Health Care Facility for Hospice Care"
        )
  )
    union "Encounter With Comfort Measures During Hospitalization For Patients With Documented Atrial Fibrillation Or Flutter"

define "Encounter With Comfort Measures During Hospitalization For Patients With Documented Atrial Fibrillation Or Flutter":
  "Denominator" Encounter
    with TJC."Intervention Comfort Measures" ComfortMeasure
      such that Coalesce(start of ComfortMeasure.performed.toInterval(), ComfortMeasure.authoredOn) during Encounter.hospitalizationWithObservation ( )

define "Numerator":
  "Denominator" Encounter
    with ["MedicationRequest": medication in "Anticoagulant Therapy"] DischargeAnticoagulant
      such that ( DischargeAnticoagulant.isCommunity ( )
          or DischargeAnticoagulant.isDischarge ( )
      )
        and DischargeAnticoagulant.status in { 'active', 'completed' }
        and DischargeAnticoagulant.intent in { 'order', 'original-order', 'reflex-order', 'filler-order', 'instance-order' }
        and DischargeAnticoagulant.authoredOn during Encounter.period
      //BONNIEMAT-1617-Since there is an anticipated resolution for STU 5 for Medication.Discharge which leaves one blockers on coverage, will leave the assertion logic as is and update the test cases for coverage.


define "Denominator Exceptions":
  "Denominator" Encounter
    with "Documented Reason For Not Giving Anticoagulant At Discharge" NoDischargeAnticoagulant
      such that NoDischargeAnticoagulant.authoredOn during Encounter.period

define "Documented Reason For Not Giving Anticoagulant At Discharge":
  ["MedicationNotRequested": medication in "Anticoagulant Therapy"] NoAnticoagulant
    where ( NoAnticoagulant.reasonCode in "Medical Reason For Not Providing Treatment"
        or NoAnticoagulant.reasonCode in "Patient Refusal"
    )
      and ( NoAnticoagulant.isCommunity ( )
          or NoAnticoagulant.isDischarge ( )
      )
      and NoAnticoagulant.intent in { 'order', 'original-order', 'reflex-order', 'filler-order', 'instance-order' }

define "SDE Ethnicity":
  SDE."SDE Ethnicity"

define "SDE Payer":
  SDE."SDE Payer"

define "SDE Race":
  SDE."SDE Race"

define "SDE Sex":
  SDE."SDE Sex"