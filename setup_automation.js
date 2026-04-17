const { Pool } = require('pg');

const pool = new Pool({
    database: 'emergency_db',
    user: 'postgres',
    password: 'postgres',
    port: 5432,
    host: 'localhost'
});

async function setupDatabaseAutomation() {
    try {
        console.log('Adding database automation triggers...');
        
        // 1. Create function to find nearest ambulance and hospital
        await pool.query(`
            CREATE OR REPLACE FUNCTION process_new_patient() 
            RETURNS TRIGGER AS $$
            DECLARE
                nearest_amb_id UUID;
                nearest_hosp_id UUID;
                request_id UUID;
            BEGIN
                -- 1. Create emergency request
                INSERT INTO emergency_requests (patient_id, symptom_category, severity_score, location_hexagon_id, latitude, longitude, status)
                VALUES (NEW.id, 'OTHER', 5, 'auto-detect', NEW.latitude, NEW.longitude, 'PENDING')
                RETURNING id INTO request_id;

                -- 2. Find nearest AVAILABLE ambulance
                SELECT id INTO nearest_amb_id
                FROM ambulances
                WHERE status = 'AVAILABLE'
                ORDER BY (point(longitude, latitude) <-> point(NEW.longitude, NEW.latitude)) ASC
                LIMIT 1;

                -- 3. Find nearest hospital with beds > 0
                SELECT id INTO nearest_hosp_id
                FROM hospitals
                WHERE available_er_beds > 0
                ORDER BY (point(longitude, latitude) <-> point(NEW.longitude, NEW.latitude)) ASC
                LIMIT 1;

                IF nearest_amb_id IS NOT NULL AND nearest_hosp_id IS NOT NULL THEN
                    -- 4. Update ambulance status
                    UPDATE ambulances SET status = 'BUSY' WHERE id = nearest_amb_id;

                    -- 5. Update hospital beds
                    UPDATE hospitals SET available_er_beds = available_er_beds - 1 WHERE id = nearest_hosp_id;

                    -- 6. Create assignment
                    INSERT INTO ambulance_assignments (request_id, ambulance_id, hospital_id, status)
                    VALUES (request_id, nearest_amb_id, nearest_hosp_id, 'EN_ROUTE');

                    -- 7. Update request status
                    UPDATE emergency_requests SET status = 'DISPATCHED' WHERE id = request_id;
                END IF;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        `);

        // 2. Attach trigger to patients table
        await pool.query(`
            DROP TRIGGER IF EXISTS trigger_process_patient ON patients;
            CREATE TRIGGER trigger_process_patient
            AFTER INSERT ON patients
            FOR EACH ROW
            EXECUTE FUNCTION process_new_patient();
        `);

        console.log('Database automation set up successfully!');
        
    } catch (err) {
        console.error('Automation setup failed:', err.message);
    } finally {
        await pool.end();
    }
}

setupDatabaseAutomation();