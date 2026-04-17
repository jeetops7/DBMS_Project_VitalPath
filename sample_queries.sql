-- =============================================================
-- VITALPATH SQL QUERY EXAMPLES
-- =============================================================

-- 1. SIMPLE QUERIES
-- ------------------

-- All patients with basic info
SELECT name, age, blood_group, gender, emergency_contact 
FROM patients 
ORDER BY name;

-- All hospitals with bed availability
SELECT name, zone, available_er_beds, total_er_beds,
       ROUND((available_er_beds::FLOAT / total_er_beds * 100), 1) || '%' as availability_percentage
FROM hospitals 
ORDER BY available_er_beds DESC;

-- All ambulances with status
SELECT registration_number, driver_name, status, 
       CASE 
           WHEN status = 'AVAILABLE' THEN 'Ready for dispatch'
           WHEN status = 'BUSY' THEN 'Currently assigned'
           WHEN status = 'OFFLINE' THEN 'Not operational'
           ELSE 'Under maintenance'
       END as status_description
FROM ambulances 
ORDER BY status, registration_number;

-- 2. BASIC JOINS
-- --------------

-- Patients with their emergency requests
SELECT p.name, p.age, p.blood_group, 
       er.symptom_category, er.severity_score, er.status, er.requested_at
FROM patients p
JOIN emergency_requests er ON p.id = er.patient_id
ORDER BY er.requested_at DESC;

-- Emergency requests with assigned ambulances
SELECT er.id as request_id, p.name as patient_name,
       a.registration_number, a.driver_name, aa.status as assignment_status
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
LEFT JOIN ambulance_assignments aa ON er.id = aa.request_id
LEFT JOIN ambulances a ON aa.ambulance_id = a.id
ORDER BY er.requested_at DESC;

-- Complete dispatch information
SELECT p.name as patient_name, p.age, p.blood_group,
       er.symptom_category, er.severity_score,
       a.registration_number as ambulance, a.driver_name,
       h.name as hospital, h.zone, h.available_er_beds,
       aa.assigned_at, aa.status as dispatch_status
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
LEFT JOIN ambulance_assignments aa ON er.id = aa.request_id
LEFT JOIN ambulances a ON aa.ambulance_id = a.id
LEFT JOIN hospitals h ON aa.hospital_id = h.id
ORDER BY er.requested_at DESC;

-- 3. COMPLEX JOINS & AGGREGATES
-- ------------------------------

-- Hospitals with total emergency requests received
SELECT h.name, h.zone, h.available_er_beds, h.total_er_beds,
       COUNT(er.id) as total_requests,
       COUNT(CASE WHEN er.status = 'COMPLETED' THEN 1 END) as completed_requests
FROM hospitals h
LEFT JOIN ambulance_assignments aa ON h.id = aa.hospital_id
LEFT JOIN emergency_requests er ON aa.request_id = er.id
GROUP BY h.id, h.name, h.zone, h.available_er_beds, h.total_er_beds
ORDER BY total_requests DESC;

-- Ambulance utilization statistics
SELECT a.registration_number, a.driver_name, a.status,
       COUNT(aa.id) as total_assignments,
       COUNT(CASE WHEN aa.status = 'COMPLETED' THEN 1 END) as completed_assignments,
       MAX(aa.completed_at) as last_completion
FROM ambulances a
LEFT JOIN ambulance_assignments aa ON a.id = aa.ambulance_id
GROUP BY a.id, a.registration_number, a.driver_name, a.status
ORDER BY total_assignments DESC;

-- Patient demographics by blood group
SELECT blood_group, 
       COUNT(*) as total_patients,
       ROUND(AVG(age), 1) as average_age,
       COUNT(CASE WHEN gender = 'MALE' THEN 1 END) as male_patients,
       COUNT(CASE WHEN gender = 'FEMALE' THEN 1 END) as female_patients
FROM patients
GROUP BY blood_group
ORDER BY total_patients DESC;

-- 4. LEFT JOINS (finding missing data)
-- ------------------------------------

-- Patients with no emergency history
SELECT p.name, p.age, p.blood_group, p.chronic_diseases
FROM patients p
LEFT JOIN emergency_requests er ON p.id = er.patient_id
WHERE er.id IS NULL
ORDER BY p.name;

-- Hospitals that never received patients
SELECT h.name, h.zone, h.available_er_beds, h.total_er_beds
FROM hospitals h
LEFT JOIN ambulance_assignments aa ON h.id = aa.hospital_id
WHERE aa.id IS NULL
ORDER BY h.zone, h.name;

-- Ambulances never assigned to emergencies
SELECT a.registration_number, a.driver_name, a.status
FROM ambulances a
LEFT JOIN ambulance_assignments aa ON a.id = aa.ambulance_id
WHERE aa.id IS NULL
ORDER BY a.status, a.registration_number;

-- 5. SUBQUERIES & CTEs
-- --------------------

-- Patients with high severity emergencies (9-10)
SELECT name, age, blood_group, chronic_diseases, emergency_contact
FROM patients
WHERE id IN (
    SELECT patient_id 
    FROM emergency_requests 
    WHERE severity_score >= 9
)
ORDER BY name;

-- Hospitals with above-average bed availability for their zone
WITH zone_averages AS (
    SELECT zone, AVG(available_er_beds) as avg_beds
    FROM hospitals
    GROUP BY zone
)
SELECT h.name, h.zone, h.available_er_beds, za.avg_beds,
       ROUND((h.available_er_beds - za.avg_beds), 1) as above_average
FROM hospitals h
JOIN zone_averages za ON h.zone = za.zone
WHERE h.available_er_beds > za.avg_beds
ORDER BY h.zone, above_average DESC;

-- 6. ADVANCED ANALYTICS
-- ---------------------

-- Emergency response time analysis
SELECT 
    p.name as patient_name,
    er.requested_at,
    aa.assigned_at,
    EXTRACT(EPOCH FROM (aa.assigned_at - er.requested_at))/60 as response_time_minutes,
    CASE 
        WHEN EXTRACT(EPOCH FROM (aa.assigned_at - er.requested_at))/60 <= 5 THEN 'Excellent'
        WHEN EXTRACT(EPOCH FROM (aa.assigned_at - er.requested_at))/60 <= 10 THEN 'Good'
        WHEN EXTRACT(EPOCH FROM (aa.assigned_at - er.requested_at))/60 <= 15 THEN 'Acceptable'
        ELSE 'Needs Improvement'
    END as response_rating
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
JOIN ambulance_assignments aa ON er.id = aa.request_id
WHERE aa.assigned_at IS NOT NULL
ORDER BY response_time_minutes;

-- Symptom category analysis by zone
SELECT h.zone, er.symptom_category,
       COUNT(*) as case_count,
       ROUND(AVG(er.severity_score), 1) as avg_severity,
       COUNT(CASE WHEN er.severity_score >= 8 THEN 1 END) as critical_cases
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
JOIN ambulance_assignments aa ON er.id = aa.request_id
JOIN hospitals h ON aa.hospital_id = h.id
GROUP BY h.zone, er.symptom_category
ORDER BY h.zone, case_count DESC;

-- 7. PERFORMANCE & UTILIZATION
-- ---------------------------

-- Hospital performance metrics
SELECT h.name, h.zone, h.total_er_beds, h.available_er_beds,
       COUNT(aa.id) as total_patients_received,
       ROUND(COUNT(aa.id) * 100.0 / h.total_er_beds, 1) as utilization_rate,
       ROUND(AVG(
           EXTRACT(EPOCH FROM (aa.completed_at - aa.assigned_at))/60
       ), 1) as avg_treatment_time_minutes
FROM hospitals h
LEFT JOIN ambulance_assignments aa ON h.id = aa.hospital_id
WHERE aa.completed_at IS NOT NULL
GROUP BY h.id, h.name, h.zone, h.total_er_beds, h.available_er_beds
ORDER BY utilization_rate DESC;

-- Driver performance ranking
SELECT a.driver_name, a.registration_number,
       COUNT(aa.id) as total_dispatches,
       COUNT(CASE WHEN aa.status = 'COMPLETED' THEN 1 END) as completed_dispatches,
       ROUND(COUNT(CASE WHEN aa.status = 'COMPLETED' THEN 1 END) * 100.0 / 
             NULLIF(COUNT(aa.id), 0), 1) as completion_rate,
       ROUND(AVG(
           EXTRACT(EPOCH FROM (aa.completed_at - aa.assigned_at))/60
       ), 1) as avg_response_time
FROM ambulances a
LEFT JOIN ambulance_assignments aa ON a.id = aa.ambulance_id
GROUP BY a.driver_name, a.registration_number
ORDER BY completed_dispatches DESC, completion_rate DESC;

-- 8. EMERGENCY PATTERNS
-- ---------------------

-- Peak emergency hours
SELECT EXTRACT(HOUR FROM er.requested_at) as hour_of_day,
       COUNT(*) as emergency_count,
       ROUND(AVG(er.severity_score), 1) as avg_severity,
       COUNT(CASE WHEN er.severity_score >= 8 THEN 1 END) as critical_cases
FROM emergency_requests er
GROUP BY hour_of_day
ORDER BY emergency_count DESC;

-- Chronic conditions correlation with emergencies
SELECT p.chronic_diseases,
       COUNT(*) as patient_count,
       COUNT(er.id) as emergency_count,
       ROUND(AVG(er.severity_score), 1) as avg_severity,
       COUNT(CASE WHEN er.severity_score >= 8 THEN 1 END) as critical_emergencies
FROM patients p
LEFT JOIN emergency_requests er ON p.id = er.patient_id
WHERE p.chronic_diseases IS NOT NULL AND p.chronic_diseases != 'None'
GROUP BY p.chronic_diseases
ORDER BY emergency_count DESC;

-- 9. SYSTEM OVERVIEW
-- ------------------

-- Complete system status dashboard
SELECT 
    (SELECT COUNT(*) FROM patients) as total_patients,
    (SELECT COUNT(*) FROM hospitals) as total_hospitals,
    (SELECT SUM(available_er_beds) FROM hospitals) as total_available_beds,
    (SELECT SUM(total_er_beds) FROM hospitals) as total_beds_capacity,
    (SELECT COUNT(*) FROM ambulances WHERE status = 'AVAILABLE') as available_ambulances,
    (SELECT COUNT(*) FROM ambulances WHERE status = 'BUSY') as busy_ambulances,
    (SELECT COUNT(*) FROM emergency_requests WHERE status = 'PENDING') as pending_requests,
    (SELECT COUNT(*) FROM emergency_requests WHERE status = 'COMPLETED') as completed_requests,
    (SELECT COUNT(*) FROM emergency_requests WHERE requested_at > CURRENT_DATE - INTERVAL '24 hours') as last_24h_requests;

-- Active emergency summary
SELECT 
    p.name as patient_name,
    p.age,
    p.blood_group,
    er.symptom_category,
    er.severity_score,
    a.registration_number as ambulance,
    a.driver_name,
    h.name as destination_hospital,
    h.zone,
    aa.assigned_at,
    CASE 
        WHEN aa.status = 'EN_ROUTE' THEN 'Ambulance on the way'
        WHEN aa.status = 'AT_SCENE' THEN 'Attending patient'
        WHEN aa.status = 'TRANSPORTING' THEN 'En route to hospital'
        WHEN aa.status = 'ARRIVED' THEN 'At hospital'
        ELSE 'Status unknown'
    END as current_status
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
JOIN ambulance_assignments aa ON er.id = aa.request_id
JOIN ambulances a ON aa.ambulance_id = a.id
JOIN hospitals h ON aa.hospital_id = h.id
WHERE er.status NOT IN ('COMPLETED', 'CANCELLED')
ORDER BY er.severity_score DESC, aa.assigned_at;
