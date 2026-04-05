const db = require('../config/db');

// Explicitly Whitelisted tables strictly preventing SQL execution vulnerabilities
const ALLOWED_TABLES = [
    'users', 'students', 'staff', 'staff_assignments', 'attendance', 'marks', 'fees', 'notices', 'timetable', 'classes',
    'student_fees', 'alerts', 'subjects', 'parent_student_map', 'fee_structure'
];

exports.syncPush = async (req, res) => {
    try {
        const payload = req.body; // e.g., { students: [...], attendance: [...] }
        const syncResults = {};

        // Execute sequentially keeping transaction constraints straightforward
        for (const [tableName, records] of Object.entries(payload)) {
            if (!ALLOWED_TABLES.includes(tableName)) continue;
            if (!Array.isArray(records) || records.length === 0) continue;

            let validColumns = [];
            try {
                const colResult = await db.query(`SELECT column_name FROM information_schema.columns WHERE table_name = $1`, [tableName]);
                validColumns = colResult.rows.map(r => r.column_name);
            } catch (e) {
                continue; // Database failure fetching columns
            }
            if (validColumns.length === 0) continue; // Table doesn't exist remotely

            let successfulUpserts = 0;
            let errors = [];

            for (const rawRecord of records) {
                let record = {};
                try {
                    // Pre-filter: Explicitly strip payload keeping only columns known exactly natively to Postgres
                    Object.keys(rawRecord).forEach(k => {
                        if (validColumns.includes(k)) record[k] = rawRecord[k];
                    });

                    // Server-side strict constraint enforcement (Flutter typically omits created_at from sync queues)
                    if (validColumns.includes('created_at') && !record['created_at']) {
                        record['created_at'] = new Date().toISOString();
                    }
                    if (validColumns.includes('updated_at') && !record['updated_at']) {
                        record['updated_at'] = new Date().toISOString();
                    }

                    const columns = Object.keys(record);
                    if (columns.length === 0) throw new Error("No matching columns");
                    
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
                    if (e.code === '23502' && record.id) {
                        try {
                            // Partial payload (delta) triggered INSERT NOT NULL fail. Degrade to standard UPDATE.
                            const columns = Object.keys(record);
                            const updateCols = columns.filter(col => col !== 'id');
                            if (updateCols.length > 0) {
                                const setClause = updateCols.map((col, i) => `"${col}" = $${i + 2}`).join(', ');
                                const updateVals = [record.id, ...updateCols.map(col => record[col])];
                                const updateQuery = `UPDATE "${tableName}" SET ${setClause} WHERE id = $1`;
                                await db.query(updateQuery, updateVals);
                            }
                            successfulUpserts++;
                        } catch (updateErr) {
                            errors.push({ recordId: rawRecord.id, error: updateErr.message });
                        }
                    } else {
                        errors.push({ recordId: rawRecord.id, error: e.message });
                    }
                }
            }

            syncResults[tableName] = { upserted: successfulUpserts, errors };
            if (errors.length > 0) {
                return res.status(400).json({ 
                    status: 'error', 
                    message: `Postgres rejected records in ${tableName}`,
                    details: errors 
                });
            }
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
            try {
                // Try pulling with updated_at delta
                const result = await db.query(
                    `SELECT * FROM "${table}" WHERE updated_at > $1`, 
                    [lastSync]
                );
                pullPayload[table] = result.rows.length > 0 ? result.rows : [];
            } catch (err) {
                // Fallback for tables missing updated_at or missing table entirely 
                // e.g. parent_student_map, alerts, classes which might not have updated_at
                try {
                    const fallbackResult = await db.query(`SELECT * FROM "${table}"`);
                    pullPayload[table] = fallbackResult.rows.length > 0 ? fallbackResult.rows : [];
                } catch (fallbackErr) {
                    // If table doesn't exist at all, ignore it safely rather than crashing the whole pull sync
                    pullPayload[table] = [];
                }
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
