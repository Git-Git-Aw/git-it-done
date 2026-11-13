require('dotenv').config();
const app = require('./src/app');
const { sequelize } = require('./src/models');

const PORT = process.env.PORT || 3000;

(async () => {
  try {
    await sequelize.authenticate();
    if (process.env.DB_SYNC === 'true') await sequelize.sync();
    console.log('MySQL connected');
    app.listen(PORT, '0.0.0.0', () => console.log(`Git-Inside API running at http://localhost:${PORT}`));
  } catch (err) {
    console.error('Failed to start server:', err.message);
    process.exit(1);
  }
})();
