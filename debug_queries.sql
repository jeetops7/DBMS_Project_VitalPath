-- Check all patients in the database
SELECT name, age, blood_group, gender, emergency_contact 
FROM patients 
ORDER BY name;

-- Check if Arjun Mehta exists specifically
SELECT * FROM patients WHERE name = 'Arjun Mehta';

-- Check all emergency requests
SELECT er.id, p.name as patient_name, er.symptom_category, er.status, er.requested_at
FROM emergency_requests er
JOIN patients p ON er.patient_id = p.id
ORDER BY er.requested_at DESC;

-- Check if there are any emergency requests at all
SELECT COUNT(*) as total_requests FROM emergency_requests;
