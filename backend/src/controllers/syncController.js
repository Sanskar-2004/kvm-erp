const db = require('../config/db');

// Explicitly Whitelisted tables strictly preventing SQL execution vulnerabilities
const ALLOWED_TABLES = [
    'users', 'students', 'attendance', 'marks', 'fees', 'notices', 'timetable', 'classes'
];

exports.syncPush = async (req, res) => {
    try {
        const payload = req.body; // e.g., { students: [...], attendance: [...] }
        const syncResults = {};

        // Execute sequentially keeping transaction constraints straightforward
        for (const [tableName, records] of Object.entries(payload)) {
            if (!ALLOWED_TABLES.includes(tableName)) continue;
            if (!Array.isArray(records) || records.length === 0) continue;

            let successfulUpserts = 0;
            let errors = [];

            for (const record of records) {
                try {
                    const columns = Object.keys(record);
                    const values = Object.values(record);
                    
                    // Parameters: $1, $2, $3...
                    const placeholders = values.map((_, i) => `$${i + 1}`).join(', ');
                    
                    // Excluded blocks: name = EXCLUDED.name, class_id = EXCLUDED.class_id...
                    const updates = columns
                        .filter(col => col !== 'id') // Cannot update Primary Key natively
                        .map(col => `"${col}" = EXCLUDED."${col}"`)
                        .join(', ');

                    const query = `
                        INSERT INTO "${tableName}" ("${columns.join('", "')}")
                        VALUES (${placeholders})
                        ON CONFLICT (id)
                        DO UPDATE SET
                          ${updates}
                        WHERE "${tableName}".updated_at < EXCLUDED.updated_at
                    `;

                    await db.query(query, values);
                    successfulUpserts++;
                } catch (e) {
                    errors.push({ recordId: record.id, error: e.message });
                }
            }

            syncResults[tableName] = { upserted: successfulUpserts, errors };
        }

        res.json({
            status: 'success',
            message: 'Push Processed',
            details: syncResults
        });

    } catch (e) {
        console.error('[Sync Push Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};

exports.syncPull = async (req, res) => {
    try {
        const lastSync = req.query.lastSync; 
        if (!lastSync) {
             return res.status(400).json({ status: 'error', message: 'Missing lastSync parameter' });
        }

        const pullPayload = {};
        
        // Loop purely through mapped specific tables dynamically dumping data
        for (const table of ALLOWED_TABLES) {
            // Note: date logic assumes lastSync string parses correctly depending on SQLite precision
            const result = await db.query(
                `SELECT * FROM "${table}" WHERE updated_at > $1`, 
                [lastSync]
            );
            
            if (result.rows.length > 0) {
                pullPayload[table] = result.rows;
            } else {
                pullPayload[table] = [];
            }
        }
        
        // Expose Master server time explicitly providing client-side tracking hooks natively
        pullPayload.serverTime = new Date().toISOString();

        res.json({
            status: 'success',
            data: pullPayload
        });

    } catch (e) {
        console.error('[Sync Pull Error]', e);
        res.status(500).json({ status: 'error', message: e.message });
    }
};
