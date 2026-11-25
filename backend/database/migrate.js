// Migration runner. Manual only: `npm run migrate` (apply pending) or `npm run migrate:undo` (undo the last one).
// Applied migrations are remembered in the schema_migrations table.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const sequelize = require('../src/config/db');

const DIR = path.join(__dirname, 'migrations');

(async () => {
  const undo = process.argv[2] === 'down';
  try {
    const queryInterface = sequelize.getQueryInterface();
    await sequelize.query('CREATE TABLE IF NOT EXISTS schema_migrations (name VARCHAR(120) PRIMARY KEY, run_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    const [rows] = await sequelize.query('SELECT name FROM schema_migrations ORDER BY name');
    const done = new Set(rows.map((r) => r.name));
    const files = fs.readdirSync(DIR).filter((f) => /^\d+_.+\.js$/.test(f)).sort();

    if (undo) {
      const last = [...done].sort().pop();
      if (!last) { console.log('Nothing to undo.'); return; }
      if (!files.includes(last)) throw new Error(`Migration file ${last} not found`);
      await require(path.join(DIR, last)).down(queryInterface);
      await sequelize.query('DELETE FROM schema_migrations WHERE name = ?', { replacements: [last] });
      console.log(`Undone: ${last}`);
      return;
    }

    let applied = 0;
    for (const file of files) {
      if (done.has(file)) continue;
      await require(path.join(DIR, file)).up(queryInterface);
      await sequelize.query('INSERT INTO schema_migrations (name) VALUES (?)', { replacements: [file] });
      console.log(`Applied: ${file}`);
      applied += 1;
    }
    if (!applied) console.log('No pending migrations.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
})();
