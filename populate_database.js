const fs = require('fs');
const { Pool } = require('pg');

const pool = new Pool({
    database: 'emergency_db',
    user: 'postgres',
    password: 'postgres',
    port: 5432,
    host: 'localhost'
});

async function populateDatabase() {
    const client = await pool.connect();
    try {
        console.log('Reading SQL file...');
        const sqlFile = fs.readFileSync('VitalPathFullExecution.sql', 'utf8');
        
        console.log('Executing SQL file...');
        await client.query(sqlFile);
        
        console.log('Database populated successfully!');
        
        // Verify data was inserted
        const patientCount = await client.query('SELECT COUNT(*) FROM patients');
        console.log(`Patients inserted: ${patientCount.rows[0].count}`);
        
        const hospitalCount = await client.query('SELECT COUNT(*) FROM hospitals');
        console.log(`Hospitals inserted: ${hospitalCount.rows[0].count}`);
        
        const ambulanceCount = await client.query('SELECT COUNT(*) FROM ambulances');
        console.log(`Ambulances inserted: ${ambulanceCount.rows[0].count}`);
        
        const requestCount = await client.query('SELECT COUNT(*) FROM emergency_requests');
        console.log(`Emergency requests inserted: ${requestCount.rows[0].count}`);
        
        // Show sample patient data
        const samplePatients = await client.query('SELECT name, age, blood_group FROM patients LIMIT 3');
        console.log('Sample patients:');
        samplePatients.rows.forEach(p => {
            console.log(`  - ${p.name}, ${p.age} years old, ${p.blood_group} blood group`);
        });
        
    } catch (error) {
        console.error('Error populating database:', error.message);
    } finally {
        client.release();
        await pool.end();
    }
}

populateDatabase();
