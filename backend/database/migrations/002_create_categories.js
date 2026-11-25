// Migration 002: creates the missing categories table (matches the Category model).
// Run with `npm run migrate` (backend folder). Nothing runs it automatically.

module.exports = {
  async up(queryInterface) {
    await queryInterface.sequelize.query(`
CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)`);
  },

  async down(queryInterface) {
    await queryInterface.sequelize.query('DROP TABLE IF EXISTS categories');
  },
};
