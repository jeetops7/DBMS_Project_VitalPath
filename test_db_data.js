const { Pool } = require('pg');

const pool = new Pool({
    database: 'emergency_db',
    user: 'postgres',
    password: 'postgres',
    port: 5432,
    host: 'localhost'
});

async function checkDatabase() {
    try {
        console.log('Checking patients table...');
        const patientCount = await pool.query('SELECT COUNT(*) FROM patients');
        console.log('Patients count:', patientCount.rows[0].count);
        
        if (parseInt(patientCount.rows[0].count) > 0) {
            const patients = await pool.query('SELECT name, age FROM patients LIMIT 5');
            console.log('Sample patients:', patients.rows);
        }
        
        console.log('Checking emergency_requests table...');
        const requestCount = await pool.query('SELECT COUNT(*) FROM emergency_requests');
        console.log('Emergency requests count:', requestCount.rows[0].count);
        
        console.log('Checking hospitals table...');
        const hospitalCount = await pool.query('SELECT COUNT(*) FROM hospitals');
        console.log('Hospitals count:', hospitalCount.rows[0].count);
        
        console.log('Checking ambulances table...');
        const ambulanceCount = await pool.query('SELECT COUNT(*) FROM ambulances');
        console.log('Ambulances count:', ambulanceCount.rows[0].count);
        
    } catch (error) {
        console.error('Database error:', error.message);
    } finally {
        await pool.end();
    }
}

checkDatabase();
