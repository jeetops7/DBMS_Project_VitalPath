

-- =============================================================
-- VITALPATH: COMPLETE SYSTEM INITIALIZATION (MUMBAI)
-- =============================================================

-- PHASE 1: CLEANUP & SCHEMA
-- -------------------------------------------------------------

DROP TABLE IF EXISTS ambulance_assignments CASCADE;
DROP TABLE IF EXISTS emergency_requests    CASCADE;
DROP TABLE IF EXISTS ambulances            CASCADE;
DROP TABLE IF EXISTS hospitals             CASCADE;
DROP TABLE IF EXISTS patients              CASCADE;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    age INTEGER NOT NULL CHECK (age > 0 AND age < 130),
    blood_group VARCHAR(10) CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    gender VARCHAR(20) CHECK (gender IN ('MALE','FEMALE','OTHER')),
    chronic_diseases TEXT,
    allergies TEXT,
    emergency_contact VARCHAR(20),
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN 6.0 AND 40.0),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN 60.0 AND 100.0)
);

CREATE TABLE ambulances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_number VARCHAR(50) UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE','BUSY','OFFLINE','MAINTENANCE')),
    current_hexagon_id VARCHAR(20),
    driver_name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION CHECK (latitude BETWEEN 6.0 AND 40.0),
    longitude DOUBLE PRECISION CHECK (longitude BETWEEN 60.0 AND 100.0),
    last_updated TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hospitals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    total_er_beds INTEGER NOT NULL DEFAULT 0 CHECK (total_er_beds >= 0),
    available_er_beds INTEGER NOT NULL DEFAULT 0 CHECK (available_er_beds >= 0),
    base_hexagon_id VARCHAR(20),
    zone VARCHAR(100),
    contact_number VARCHAR(20),
    version INTEGER NOT NULL DEFAULT 0,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN 6.0 AND 40.0),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN 60.0 AND 100.0),
    CONSTRAINT chk_beds CHECK (available_er_beds <= total_er_beds)
);

CREATE TABLE emergency_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL,
    symptom_category VARCHAR(100) NOT NULL CHECK (symptom_category IN ('CARDIAC','TRAUMA','RESPIRATORY','NEUROLOGICAL','OBSTETRIC','PEDIATRIC','BURNS','POISONING','OTHER')),
    severity_score INTEGER CHECK (severity_score BETWEEN 1 AND 10),
    location_hexagon_id VARCHAR(20) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    requested_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','DISPATCHED','EN_ROUTE','AT_SCENE','COMPLETED','CANCELLED')),
    notes TEXT,
    CONSTRAINT fk_er_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
);

CREATE TABLE ambulance_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL,
    ambulance_id UUID NOT NULL,
    hospital_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'EN_ROUTE' CHECK (status IN ('EN_ROUTE','AT_SCENE','TRANSPORTING','ARRIVED','COMPLETED','CANCELLED')),
    assigned_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    arrived_at TIMESTAMP WITHOUT TIME ZONE,
    completed_at TIMESTAMP WITHOUT TIME ZONE,
    CONSTRAINT fk_aa_request   FOREIGN KEY (request_id)   REFERENCES emergency_requests(id) ON DELETE CASCADE,
    CONSTRAINT fk_aa_ambulance FOREIGN KEY (ambulance_id) REFERENCES ambulances(id)         ON DELETE CASCADE,
    CONSTRAINT fk_aa_hospital  FOREIGN KEY (hospital_id)  REFERENCES hospitals(id)          ON DELETE CASCADE
);


-- =============================================================
-- PHASE 2: DATA POPULATION
-- =============================================================

-- ---------------------------------------------------------------
-- 1. HOSPITALS (20 rows)
-- ---------------------------------------------------------------
INSERT INTO hospitals (id, name, total_er_beds, available_er_beds, base_hexagon_id, zone, contact_number, latitude, longitude) VALUES
('f0000001-0000-0000-0000-000000000001','Breach Candy Hospital',     60,  12,'8928308280fffff','South Mumbai',    '+91-22-23667888',18.9725,72.8055),
('f0000001-0000-0000-0000-000000000002','Jaslok Hospital',           80,  18,'8928308281fffff','South Mumbai',    '+91-22-66573333',18.9716,72.8076),
('f0000001-0000-0000-0000-000000000003','Tata Memorial Hospital',   100,   5,'8928308282fffff','South Mumbai',    '+91-22-24177000',18.9986,72.8128),
('f0000001-0000-0000-0000-000000000004','KEM Hospital',             200,  35,'8928308283fffff','South Mumbai',    '+91-22-24107000',18.9975,72.8386),
('f0000001-0000-0000-0000-000000000005','Sir JJ Hospital',          250,  42,'8928308284fffff','South Mumbai',    '+91-22-23735555',18.9620,72.8347),
('f0000001-0000-0000-0000-000000000006','Hinduja Hospital',         120,  22,'8928308285fffff','Central Mumbai',  '+91-22-24452222',19.0000,72.8353),
('f0000001-0000-0000-0000-000000000007','Global Hospital Mumbai',   100,  28,'8928308286fffff','Central Mumbai',  '+91-22-67670101',19.0144,72.8434),
('f0000001-0000-0000-0000-000000000008','Lilavati Hospital',         90,  14,'8928308287fffff','Western Suburbs', '+91-22-26568000',19.0593,72.8354),
('f0000001-0000-0000-0000-000000000009','Holy Family Hospital',      60,  20,'8928308288fffff','Western Suburbs', '+91-22-26428000',19.0523,72.8388),
('f0000001-0000-0000-0000-000000000010','SevenHills Hospital',      150,  30,'892830828afffff','Western Suburbs', '+91-22-67676767',19.1152,72.8607),
('f0000001-0000-0000-0000-000000000011','Kokilaben Ambani Hospital', 140,  24,'892830828bfffff','Western Suburbs', '+91-22-30999999',19.1335,72.8272),
('f0000001-0000-0000-0000-000000000012','Nanavati Max Hospital',    100,  16,'892830828cfffff','Western Suburbs', '+91-22-26267500',19.1008,72.8405),
('f0000001-0000-0000-0000-000000000013','Hiranandani Hospital Powai', 80, 18,'892830828dfffff','Eastern Suburbs', '+91-22-25763300',19.1178,72.9051),
('f0000001-0000-0000-0000-000000000014','Fortis Hospital',           70,  10,'892830828efffff','Eastern Suburbs', '+91-22-25623000',19.1147,72.9115),
('f0000001-0000-0000-0000-000000000015','Apollo Spectra',            60,  22,'892830828fffff', 'Eastern Suburbs', '+91-22-67906000',19.0626,72.9003),
('f0000001-0000-0000-0000-000000000016','MGM Hospital Vashi',       180,  45,'892830829afffff','Navi Mumbai',     '+91-22-27684000',19.0760,73.0078),
('f0000001-0000-0000-0000-000000000017','Wockhardt Hospital',       100,  32,'892830829bfffff','Western Suburbs', '+91-22-61446000',19.2922,72.8627),
('f0000001-0000-0000-0000-000000000018','Bhagwati Hospital',         50,  15,'892830829cfffff','Western Suburbs', '+91-22-28918000',19.2340,72.8572),
('f0000001-0000-0000-0000-000000000019','Criticare Asia Hospital',   60,  18,'892830829dfffff','Western Suburbs', '+91-22-28828080',19.1883,72.8481),
('f0000001-0000-0000-0000-000000000020','Sion Hospital',            220,  55,'892830829efffff','Central Mumbai',  '+91-22-24085000',19.0415,72.8638);


-- ---------------------------------------------------------------
-- 2. AMBULANCES (30 rows)
-- ---------------------------------------------------------------
INSERT INTO ambulances (registration_number, status, driver_name, latitude, longitude) VALUES
('MH-01-AA-1001','AVAILABLE','Ramesh Patil',   18.9725,72.8200),
('MH-01-AA-1002','AVAILABLE','Sunil Kadam',    18.9810,72.8150),
('MH-01-AA-1003','BUSY',     'Vijay Naik',     18.9990,72.8200),
('MH-01-AB-2001','AVAILABLE','Anil Shinde',    18.9975,72.8450),
('MH-01-AB-2002','AVAILABLE','Deepak More',    18.9580,72.8400),
('MH-02-AC-3001','BUSY',     'Sanjay Sawant',  19.0050,72.8400),
('MH-02-AC-3002','AVAILABLE','Prakash Jadhav', 19.0100,72.8500),
('MH-02-AD-4001','AVAILABLE','Mohan Gaikwad',  19.0550,72.8400),
('MH-02-AD-4002','OFFLINE',  'Dinesh Pawar',   19.0500,72.8450),
('MH-03-AE-5001','AVAILABLE','Kiran Bonde',    19.1100,72.8650),
('MH-03-AE-5002','BUSY',     'Rahul Desai',    19.1300,72.8300),
('MH-03-AF-6001','AVAILABLE','Tushar Mane',    19.0950,72.8480),
('MH-03-AF-6002','AVAILABLE','Nilesh Bhosale', 19.1200,72.9100),
('MH-04-AG-7001','AVAILABLE','Ajay Parab',     19.1150,72.9150),
('MH-04-AG-7002','OFFLINE',  'Santosh Naik',   19.0600,72.9050),
('MH-04-AH-8001','AVAILABLE','Ganesh Dalvi',   19.0800,73.0100),
('MH-04-AH-8002','BUSY',     'Prashant Rane',  19.2900,72.8650),
('MH-05-AI-9001','AVAILABLE','Manoj Tawde',    19.2300,72.8600),
('MH-05-AI-9002','AVAILABLE','Akash Surve',    19.1900,72.8520),
('MH-05-AJ-0001','AVAILABLE','Rohit Koli',     19.0400,72.8700),
('MH-06-AK-1101','AVAILABLE','Sagar Waghmare', 18.9760,72.8100),
('MH-06-AK-1102','MAINTENANCE','Amol Khot',    18.9850,72.8200),
('MH-06-AL-1201','AVAILABLE','Yogesh Salve',   19.0080,72.8380),
('MH-07-AM-1301','AVAILABLE','Vikas Gawde',    19.1350,72.8290),
('MH-07-AM-1302','AVAILABLE','Omkar Chavan',   19.1190,72.9060),
('MH-07-AN-1401','BUSY',     'Sandesh Londhe', 19.1180,72.8590),
('MH-08-AP-1501','AVAILABLE','Nikhil Mhatre',  19.0790,73.0080),
('MH-08-AP-1502','AVAILABLE','Sumit Funde',    19.2380,72.8580),
('MH-08-AQ-1601','OFFLINE',  'Pankaj Hire',    19.1860,72.8500),
('MH-09-AR-1701','AVAILABLE','Rajan Bhoir',    19.0420,72.8650);


-- ---------------------------------------------------------------
-- 3. PATIENTS (20 rows)
-- ---------------------------------------------------------------
INSERT INTO patients (name, age, blood_group, gender, chronic_diseases, allergies, emergency_contact, latitude, longitude) VALUES
('Arjun Mehta',      65,'O-', 'MALE',  'Diabetes',        'Penicillin',   '+91-9820001001',18.9730,72.8210),
('Sunita Rao',       45,'B+', 'FEMALE','Asthma',           'Aspirin',      '+91-9820001002',19.0600,72.8370),
('Ravi Kumar',       30,'A+', 'MALE',  'None',             'None',         '+91-9820001003',19.1150,72.8610),
('Priya Nair',       28,'AB+','FEMALE','None',              'Sulfa',        '+91-9820001004',19.1340,72.8280),
('Mohammad Ansari',  55,'O+', 'MALE',  'CAD',              'Ibuprofen',    '+91-9820001005',19.0050,72.8410),
('Kavita Deshmukh',  72,'A-', 'FEMALE','Arthritis',        'Latex',        '+91-9820001006',18.9620,72.8350),
('Sachin Thakur',    40,'B-', 'MALE',  'Epilepsy',         'Phenytoin',    '+91-9820001007',19.0430,72.8620),
('Deepa Joshi',      35,'O+', 'FEMALE','None',              'None',         '+91-9820001008',19.1900,72.8490),
('Arun Pillai',      80,'AB-','MALE',  'COPD',             'Morphine',     '+91-9820001009',19.0800,73.0090),
('Neha Shah',        22,'A+', 'FEMALE','None',              'Codeine',      '+91-9820001010',19.2330,72.8590),
('Gopal Tiwari',     58,'B+', 'MALE',  'Kidney Disease',   'ACEi',         '+91-9820001011',18.9990,72.8380),
('Lalita Parekh',    48,'O-', 'FEMALE','Hypothyroidism',   'None',         '+91-9820001012',19.1160,72.9060),
('Firoz Shaikh',     33,'A-', 'MALE',  'None',             'Shellfish',    '+91-9820001013',19.0410,72.8690),
('Ananya Reddy',     26,'B+', 'FEMALE','Lupus',             'NSAIDs',       '+91-9820001014',19.0560,72.8390),
('Hemant Kulkarni',  62,'O+', 'MALE',  'Glaucoma',         'Sulfonamides', '+91-9820001015',19.2890,72.8640),
('Sonal Marathe',    19,'A+', 'FEMALE','None',              'None',         '+91-9820001016',19.0150,72.8440),
('Balram Singh',     75,'B+', 'MALE',  'Heart Failure',    'Digoxin',      '+91-9820001017',18.9720,72.8060),
('Tara Gupta',       38,'AB+','FEMALE','Migraine',          'Ergotamine',   '+91-9820001018',19.1130,72.9120),
('Aakash Shetty',     7,'O+', 'MALE',  'None',             'Peanuts',      '+91-9820001019',19.0420,72.8700),
('Meera Iyer',       44,'A+', 'FEMALE','Hypertension',     'Aspirin',      '+91-9820001020',19.1400,72.8270);


-- ---------------------------------------------------------------
-- 4. EMERGENCY REQUESTS (20 rows)  ← WAS MISSING
--    Uses fixed UUIDs so ambulance_assignments can reference them.
--    patient_id values cycle through the 20 patients inserted above.
-- ---------------------------------------------------------------
INSERT INTO emergency_requests
    (id, patient_id, symptom_category, severity_score,
     location_hexagon_id, latitude, longitude, status, notes)
SELECT
    er.req_id::UUID,
    p.id,
    er.symptom_category,
    er.severity_score,
    er.hex_id,
    er.lat,
    er.lng,
    er.status,
    er.notes
FROM (VALUES
    ('e0000001-0000-0000-0000-000000000001','Arjun Mehta',     'CARDIAC',      9, '8928308280fffff',18.9730,72.8210,'COMPLETED', 'Chest pain, diaphoresis'),
    ('e0000001-0000-0000-0000-000000000002','Sunita Rao',      'RESPIRATORY',  7, '8928308288fffff',19.0600,72.8370,'COMPLETED', 'Acute asthma attack'),
    ('e0000001-0000-0000-0000-000000000003','Ravi Kumar',      'TRAUMA',       8, '892830828afffff',19.1150,72.8610,'DISPATCHED','Road accident, open fracture'),
    ('e0000001-0000-0000-0000-000000000004','Priya Nair',      'OBSTETRIC',    6, '892830828bfffff',19.1340,72.8280,'EN_ROUTE',  'Premature labour 32 weeks'),
    ('e0000001-0000-0000-0000-000000000005','Mohammad Ansari', 'CARDIAC',      10,'8928308285fffff',19.0050,72.8410,'COMPLETED', 'STEMI confirmed on field ECG'),
    ('e0000001-0000-0000-0000-000000000006','Kavita Deshmukh', 'NEUROLOGICAL', 8, '8928308284fffff',18.9620,72.8350,'COMPLETED', 'Sudden right-sided weakness, aphasia'),
    ('e0000001-0000-0000-0000-000000000007','Sachin Thakur',   'NEUROLOGICAL', 7, '892830828efffff',19.0430,72.8620,'AT_SCENE',  'Tonic-clonic seizure, 10 min'),
    ('e0000001-0000-0000-0000-000000000008','Deepa Joshi',     'BURNS',        6, '892830829dfffff',19.1900,72.8490,'PENDING',   'Kitchen fire, 20% BSA'),
    ('e0000001-0000-0000-0000-000000000009','Arun Pillai',     'RESPIRATORY',  9, '892830829afffff',19.0800,73.0090,'COMPLETED', 'COPD exacerbation, SpO2 78%'),
    ('e0000001-0000-0000-0000-000000000010','Neha Shah',       'POISONING',    5, '892830829bfffff',19.2330,72.8590,'PENDING',   'Suspected tablet overdose'),
    ('e0000001-0000-0000-0000-000000000011','Gopal Tiwari',    'CARDIAC',      8, '8928308283fffff',18.9990,72.8380,'DISPATCHED','Palpitations, HR 180 bpm'),
    ('e0000001-0000-0000-0000-000000000012','Lalita Parekh',   'OTHER',        4, '892830828dfffff',19.1160,72.9060,'CANCELLED', 'Resolved before ambulance arrived'),
    ('e0000001-0000-0000-0000-000000000013','Firoz Shaikh',    'TRAUMA',       7, '892830828efffff',19.0410,72.8690,'COMPLETED', 'Fall from scaffolding, head injury'),
    ('e0000001-0000-0000-0000-000000000014','Ananya Reddy',    'OTHER',        5, '8928308288fffff',19.0560,72.8390,'EN_ROUTE',  'Lupus flare with high fever'),
    ('e0000001-0000-0000-0000-000000000015','Hemant Kulkarni', 'CARDIAC',      9, '892830829cfffff',19.2890,72.8640,'PENDING',   'Syncope, unresponsive 2 min'),
    ('e0000001-0000-0000-0000-000000000016','Sonal Marathe',   'TRAUMA',       6, '8928308286fffff',19.0150,72.8440,'COMPLETED', 'Bike vs car, laceration + rib pain'),
    ('e0000001-0000-0000-0000-000000000017','Balram Singh',    'CARDIAC',      10,'8928308280fffff',18.9720,72.8060,'COMPLETED', 'Acute decompensated heart failure'),
    ('e0000001-0000-0000-0000-000000000018','Tara Gupta',      'NEUROLOGICAL', 6, '892830828dfffff',19.1130,72.9120,'AT_SCENE',  'Migraine with aura, photophobia'),
    ('e0000001-0000-0000-0000-000000000019','Aakash Shetty',   'PEDIATRIC',    8, '892830828efffff',19.0420,72.8700,'DISPATCHED','Anaphylaxis after peanut ingestion'),
    ('e0000001-0000-0000-0000-000000000020','Meera Iyer',      'CARDIAC',      7, '892830828bfffff',19.1400,72.8270,'PENDING',   'Hypertensive crisis, BP 200/130')
) AS er(req_id, patient_name, symptom_category, severity_score,
         hex_id, lat, lng, status, notes)
JOIN patients p ON p.name = er.patient_name;


-- ---------------------------------------------------------------
-- 5. AMBULANCE ASSIGNMENTS (15 rows)  ← WAS MISSING
--    Covers COMPLETED, EN_ROUTE, AT_SCENE, TRANSPORTING and DISPATCHED
--    requests; links ambulances by registration number for clarity.
-- ---------------------------------------------------------------
INSERT INTO ambulance_assignments
    (request_id, ambulance_id, hospital_id, status,
     assigned_at, arrived_at, completed_at)
SELECT
    er.id,
    a.id,
    aa.hosp_id::UUID,
    aa.aa_status,
    aa.assigned_at::TIMESTAMP,
    aa.arrived_at::TIMESTAMP,
    aa.completed_at::TIMESTAMP
FROM (VALUES
    -- COMPLETED assignments
    ('e0000001-0000-0000-0000-000000000001','MH-01-AA-1002','f0000001-0000-0000-0000-000000000001','COMPLETED','2024-11-01 08:10:00','2024-11-01 08:25:00','2024-11-01 09:00:00'),
    ('e0000001-0000-0000-0000-000000000002','MH-02-AD-4001','f0000001-0000-0000-0000-000000000009','COMPLETED','2024-11-02 14:05:00','2024-11-02 14:20:00','2024-11-02 15:10:00'),
    ('e0000001-0000-0000-0000-000000000005','MH-06-AL-1201','f0000001-0000-0000-0000-000000000006','COMPLETED','2024-11-03 22:00:00','2024-11-03 22:18:00','2024-11-03 23:45:00'),
    ('e0000001-0000-0000-0000-000000000006','MH-01-AB-2002','f0000001-0000-0000-0000-000000000005','COMPLETED','2024-11-04 07:30:00','2024-11-04 07:45:00','2024-11-04 08:30:00'),
    ('e0000001-0000-0000-0000-000000000009','MH-04-AH-8001','f0000001-0000-0000-0000-000000000016','COMPLETED','2024-11-05 03:15:00','2024-11-05 03:35:00','2024-11-05 04:50:00'),
    ('e0000001-0000-0000-0000-000000000013','MH-03-AF-6001','f0000001-0000-0000-0000-000000000015','COMPLETED','2024-11-06 11:20:00','2024-11-06 11:38:00','2024-11-06 12:30:00'),
    ('e0000001-0000-0000-0000-000000000016','MH-06-AK-1101','f0000001-0000-0000-0000-000000000007','COMPLETED','2024-11-07 17:45:00','2024-11-07 17:58:00','2024-11-07 18:45:00'),
    ('e0000001-0000-0000-0000-000000000017','MH-01-AA-1001','f0000001-0000-0000-0000-000000000001','COMPLETED','2024-11-08 06:00:00','2024-11-08 06:12:00','2024-11-08 07:30:00'),

    -- EN_ROUTE / DISPATCHED / AT_SCENE assignments (no completed_at)
    ('e0000001-0000-0000-0000-000000000003','MH-03-AE-5001','f0000001-0000-0000-0000-000000000010','EN_ROUTE',  '2024-11-09 09:00:00', NULL, NULL),
    ('e0000001-0000-0000-0000-000000000004','MH-07-AM-1301','f0000001-0000-0000-0000-000000000011','EN_ROUTE',  '2024-11-09 10:30:00', NULL, NULL),
    ('e0000001-0000-0000-0000-000000000007','MH-05-AJ-0001','f0000001-0000-0000-0000-000000000020','AT_SCENE',  '2024-11-09 11:00:00','2024-11-09 11:14:00', NULL),
    ('e0000001-0000-0000-0000-000000000011','MH-06-AL-1201','f0000001-0000-0000-0000-000000000004','EN_ROUTE',  '2024-11-09 13:45:00', NULL, NULL),
    ('e0000001-0000-0000-0000-000000000014','MH-02-AC-3002','f0000001-0000-0000-0000-000000000008','TRANSPORTING','2024-11-09 14:10:00','2024-11-09 14:25:00', NULL),
    ('e0000001-0000-0000-0000-000000000018','MH-07-AM-1302','f0000001-0000-0000-0000-000000000013','AT_SCENE',  '2024-11-09 15:00:00','2024-11-09 15:18:00', NULL),
    ('e0000001-0000-0000-0000-000000000019','MH-03-AF-6002','f0000001-0000-0000-0000-000000000014','EN_ROUTE',  '2024-11-09 16:20:00', NULL, NULL)
) AS aa(req_id, amb_reg, hosp_id, aa_status, assigned_at, arrived_at, completed_at)
JOIN emergency_requests er ON er.id = aa.req_id::UUID
JOIN ambulances          a  ON a.registration_number = aa.amb_reg;


-- =============================================================
-- PHASE 3: EXECUTION OF 20 AUDIT QUERIES
-- =============================================================

-- Q1. WHERE with single condition
-- Question: Find all ambulances that are currently available.
SELECT id, registration_number, driver_name, latitude, longitude
FROM ambulances
WHERE status = 'AVAILABLE';


-- Q2. WHERE with AND / IN / BETWEEN
-- Question: Find emergency requests with severity between 7 and 10
--           that are either PENDING or DISPATCHED.
SELECT id, patient_id, symptom_category, severity_score, status, requested_at
FROM emergency_requests
WHERE severity_score BETWEEN 7 AND 10
  AND status IN ('PENDING', 'DISPATCHED');


-- Q3. WHERE with LIKE and ORDER BY
-- Question: Find all hospitals whose name contains 'Hospital',
--           ordered by available ER beds descending.
SELECT name, zone, total_er_beds, available_er_beds
FROM hospitals
WHERE name LIKE '%Hospital%'
ORDER BY available_er_beds DESC;


-- Q4. INSERT
-- Question: Register a new patient named Rohan Verma.
INSERT INTO patients (name, age, blood_group, gender, chronic_diseases,
                      allergies, emergency_contact, latitude, longitude)
VALUES ('Rohan Verma', 34, 'B+', 'MALE', 'None', 'None',
        '+91-9900112233', 19.0760, 72.8777)
RETURNING id, name, age, blood_group, gender, chronic_diseases,
          allergies, emergency_contact, latitude, longitude;


-- Q5. UPDATE with WHERE
-- Question: Mark ambulance MH-01-AA-1001 as BUSY after dispatch.
UPDATE ambulances
SET    status       = 'BUSY',
       last_updated = CURRENT_TIMESTAMP
WHERE  registration_number = 'MH-01-AA-1001'
RETURNING id, registration_number, driver_name, status, last_updated;

-- Q6. DELETE with WHERE
-- Question: Remove all CANCELLED requests older than 90 days.
DELETE FROM emergency_requests
WHERE  status       = 'CANCELLED'
  AND  requested_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
RETURNING id, patient_id, symptom_category, severity_score, status, requested_at;

-- Q7. COUNT, AVG, MAX, MIN
-- Question: What is the total number of emergency requests,
--           average severity, and highest severity recorded?
SELECT COUNT(*)                              AS total_requests,
       ROUND(AVG(severity_score)::NUMERIC,2) AS avg_severity,
       MAX(severity_score)                   AS max_severity,
       MIN(severity_score)                   AS min_severity
FROM   emergency_requests;


-- Q8. GROUP BY with aggregate
-- Question: How many emergencies per symptom category,
--           and what is the average severity each?
SELECT symptom_category,
       COUNT(*)                              AS total_cases,
       ROUND(AVG(severity_score)::NUMERIC,2) AS avg_severity
FROM   emergency_requests
GROUP BY symptom_category
ORDER BY total_cases DESC;


-- Q9. GROUP BY with HAVING
-- Question: Which symptom categories have an average severity above 7?
SELECT symptom_category,
       ROUND(AVG(severity_score)::NUMERIC,2) AS avg_severity,
       COUNT(*)                              AS total_cases
FROM   emergency_requests
GROUP BY symptom_category
HAVING AVG(severity_score) > 7
ORDER BY avg_severity DESC;


-- Q10. GROUP BY on hospitals by zone
-- Question: For each Mumbai zone, how many hospitals exist
--           and what is the total available ER bed count?
SELECT zone,
       COUNT(*)               AS hospital_count,
       SUM(available_er_beds) AS total_available_beds,
       SUM(total_er_beds)     AS total_capacity
FROM   hospitals
GROUP BY zone
ORDER BY total_available_beds DESC;


-- Q11. INNER JOIN — 2 tables
-- Question: Show each emergency request with the patient's name and age.
SELECT er.id             AS request_id,
       p.name            AS patient_name,
       p.age,
       er.symptom_category,
       er.severity_score,
       er.status,
       er.requested_at
FROM   emergency_requests er
JOIN   patients           p  ON p.id = er.patient_id
ORDER BY er.requested_at DESC;


-- Q12. INNER JOIN — 4 tables (full dispatch record)
-- Question: For every completed assignment, show the patient,
--           ambulance, driver, and destination hospital.
SELECT p.name                AS patient_name,
       a.registration_number AS ambulance,
       a.driver_name,
       h.name                AS hospital,
       aa.assigned_at,
       aa.completed_at
FROM   ambulance_assignments aa
JOIN   emergency_requests    er ON er.id = aa.request_id
JOIN   patients              p  ON p.id  = er.patient_id
JOIN   ambulances            a  ON a.id  = aa.ambulance_id
JOIN   hospitals             h  ON h.id  = aa.hospital_id
WHERE  aa.status = 'COMPLETED'
ORDER BY aa.completed_at DESC;


-- Q13. LEFT JOIN — find patients with no emergency history
-- Question: Find patients who have never made any emergency request.
SELECT p.id, p.name, p.age, p.chronic_diseases
FROM   patients              p
LEFT JOIN emergency_requests er ON er.patient_id = p.id
WHERE  er.id IS NULL;


-- Q14. LEFT JOIN — ambulances never dispatched
-- Question: Find ambulances that have never been assigned to any emergency.
SELECT a.registration_number, a.driver_name, a.status
FROM   ambulances            a
LEFT JOIN ambulance_assignments aa ON aa.ambulance_id = a.id
WHERE  aa.id IS NULL
ORDER BY a.status;


-- Q15. Subquery with IN
-- Question: List all patients who have had at least one emergency
--           with severity 9 or 10.
SELECT id, name, age, blood_group, chronic_diseases
FROM   patients
WHERE  id IN (
    SELECT patient_id
    FROM   emergency_requests
    WHERE  severity_score >= 9
)
ORDER BY name;


-- Q16. Subquery with NOT IN
-- Question: Which hospitals have never received any ambulance assignment?
SELECT id, name, zone, available_er_beds
FROM   hospitals
WHERE  id NOT IN (
    SELECT DISTINCT hospital_id
    FROM   ambulance_assignments
)
ORDER BY zone;


-- Q17. Correlated subquery
-- Question: Find hospitals with more available beds than the average
--           for their own zone.
SELECT name, zone, available_er_beds
FROM   hospitals h1
WHERE  available_er_beds > (
    SELECT AVG(available_er_beds)
    FROM   hospitals h2
    WHERE  h2.zone = h1.zone
)
ORDER BY zone, available_er_beds DESC;


-- Q18. SET operation — UNION
-- Question: Get one combined list of all hospitals and all patients
--           (city-wide coverage map).
SELECT name AS entity_name, 'Hospital' AS entity_type, zone   AS detail
FROM   hospitals
UNION
SELECT name AS entity_name, 'Patient'  AS entity_type, gender AS detail
FROM   patients
ORDER BY entity_type, entity_name;


-- Q19. CREATE VIEW — live dispatch dashboard
CREATE OR REPLACE VIEW live_dispatch_summary AS
SELECT
    er.id                  AS request_id,
    p.name                 AS patient_name,
    p.age,
    p.blood_group,
    er.symptom_category,
    er.severity_score,
    er.status              AS request_status,
    a.registration_number  AS ambulance_reg,
    a.driver_name,
    h.name                 AS destination_hospital,
    h.zone,
    h.available_er_beds,
    aa.assigned_at
FROM   emergency_requests    er
JOIN   patients              p  ON p.id  = er.patient_id
JOIN   ambulance_assignments aa ON aa.request_id = er.id
JOIN   ambulances            a  ON a.id  = aa.ambulance_id
JOIN   hospitals             h  ON h.id  = aa.hospital_id
WHERE  er.status NOT IN ('COMPLETED', 'CANCELLED');

SELECT * FROM live_dispatch_summary
ORDER BY severity_score DESC;


-- Q20. CASE expression — classify bed availability
-- Question: Label each hospital CRITICAL / LOW / ADEQUATE / GOOD
--           based on the percentage of free ER beds.
SELECT
    name,
    zone,
    available_er_beds,
    total_er_beds,
    CASE
        WHEN total_er_beds = 0                                        THEN 'N/A'
        WHEN available_er_beds::FLOAT / total_er_beds < 0.10          THEN 'CRITICAL'
        WHEN available_er_beds::FLOAT / total_er_beds < 0.25          THEN 'LOW'
        WHEN available_er_beds::FLOAT / total_er_beds < 0.50          THEN 'ADEQUATE'
        ELSE                                                                'GOOD'
    END AS bed_status
FROM  hospitals
ORDER BY (available_er_beds::FLOAT / NULLIF(total_er_beds, 0)) ASC;