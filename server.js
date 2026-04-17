const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = 3000;

const pool = new Pool({
    database: 'emergency_db',
    user: 'postgres',
    password: 'postgres',
    port: 5432,
    host: 'localhost'
});

app.use(cors());
app.use(express.json());
app.use(express.static('.', { 
    setHeaders: (res) => {
        res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
    }
}));

// Helper function to find best ambulance and hospital for a patient
async function processEmergency(patientId, lat, lng) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        // 1. Create emergency request
        const erResult = await client.query(`
            INSERT INTO emergency_requests (patient_id, symptom_category, severity_score, location_hexagon_id, latitude, longitude, status)
            VALUES ($1, 'OTHER', 5, 'manual', $2, $3, 'PENDING')
            RETURNING id
        `, [patientId, lat, lng]);
        const requestId = erResult.rows[0].id;

        // 2. Find nearest AVAILABLE ambulance
        const ambResult = await client.query(`
            SELECT id, registration_number, latitude, longitude,
            (point(longitude, latitude) <-> point($1, $2)) as distance
            FROM ambulances
            WHERE status = 'AVAILABLE'
            ORDER BY distance ASC
            LIMIT 1
        `, [lng, lat]);

        // 3. Find nearest hospital with beds > 0
        const hospResult = await client.query(`
            SELECT id, name, latitude, longitude,
            (point(longitude, latitude) <-> point($1, $2)) as distance
            FROM hospitals
            WHERE available_er_beds > 0
            ORDER BY distance ASC
            LIMIT 1
        `, [lng, lat]);

        if (ambResult.rows.length > 0 && hospResult.rows.length > 0) {
            const ambulanceId = ambResult.rows[0].id;
            const hospitalId = hospResult.rows[0].id;

            // 4. Update ambulance status
            await client.query(`UPDATE ambulances SET status = 'BUSY' WHERE id = $1`, [ambulanceId]);

            // 5. Update hospital beds
            await client.query(`UPDATE hospitals SET available_er_beds = available_er_beds - 1 WHERE id = $1`, [hospitalId]);

            // 6. Create assignment
            await client.query(`
                INSERT INTO ambulance_assignments (request_id, ambulance_id, hospital_id, status)
                VALUES ($1, $2, $3, 'EN_ROUTE')
            `, [requestId, ambulanceId, hospitalId]);

            // 7. Update request status
            await client.query(`UPDATE emergency_requests SET status = 'DISPATCHED' WHERE id = $1`, [requestId]);
        }

        await client.query('COMMIT');
        return requestId;
    } catch (e) {
        await client.query('ROLLBACK');
        throw e;
    } finally {
        client.release();
    }
}

app.post('/api/patients', async (req, res) => {
    try {
        const { name, age, blood_group, gender, latitude, longitude, emergency_contact } = req.body;
        
        const result = await pool.query(`
            INSERT INTO patients (name, age, blood_group, gender, latitude, longitude, emergency_contact)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        `, [name, age, blood_group, gender, latitude, longitude, emergency_contact]);
        
        const patient = result.rows[0];
        
        // No need to manually process emergency anymore as database trigger handles it!
        
        res.status(201).json(patient);
    } catch (err) {
        console.error('API Error:', err.message);
        res.status(500).json({ error: 'Database error: ' + err.message });
    }
});

app.get('/api/system-state', async (req, res) => {
    try {
        const hospitals = await pool.query(`SELECT id, name, available_er_beds, total_er_beds, latitude, longitude FROM hospitals`);
        const ambulances = await pool.query(`SELECT id, registration_number, status, driver_name, latitude, longitude FROM ambulances`);
        const requests = await pool.query(`
            SELECT er.id, p.latitude, p.longitude, er.status, p.name as patient_name,
                   aa.ambulance_id, aa.hospital_id,
                   a.latitude as amb_lat, a.longitude as amb_lng,
                   h.latitude as hosp_lat, h.longitude as hosp_lng
            FROM emergency_requests er
            JOIN patients p ON er.patient_id = p.id
            LEFT JOIN ambulance_assignments aa ON aa.request_id = er.id
            LEFT JOIN ambulances a ON aa.ambulance_id = a.id
            LEFT JOIN hospitals h ON aa.hospital_id = h.id
            WHERE er.status != 'COMPLETED' AND er.status != 'CANCELLED'
            ORDER BY er.requested_at DESC
        `);

        res.json({
            hospitals: hospitals.rows,
            ambulances: ambulances.rows,
            requests: requests.rows
        });
    } catch (err) {
        console.error('API Error:', err.message);
        res.status(500).json({ error: 'Database error: ' + err.message });
    }
});

app.post('/api/sql-query', async (req, res) => {
    try {
        const { query } = req.body;
        
        if (!query) {
            return res.status(400).json({ error: 'SQL query is required' });
        }
        
        // Basic SQL injection protection - allow safe query types
        const trimmedQuery = query.trim().toLowerCase();
        const allowedStarts = ['select', 'with', 'show', 'describe', 'explain'];
        const isAllowed = allowedStarts.some(start => trimmedQuery.startsWith(start));
        
        if (!isAllowed) {
            return res.status(400).json({ 
                error: 'Only safe queries are allowed (SELECT, WITH, SHOW, DESCRIBE, EXPLAIN). INSERT, UPDATE, DELETE, DROP are not permitted for security reasons.' 
            });
        }
        
        const result = await pool.query(query);
        
        res.json({
            columns: result.fields.map(field => field.name),
            rows: result.rows,
            rowCount: result.rowCount
        });
    } catch (err) {
        console.error('SQL Query Error:', err.message);
        res.status(500).json({ error: 'Database error: ' + err.message });
    }
});

app.listen(port, () => {
    console.log(`VitalPath Command Center running at http://localhost:${port}`);
});