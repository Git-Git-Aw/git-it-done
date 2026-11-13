exports.notFound = (req, res) => res.status(404).json({ message: `Route not found: ${req.method} ${req.originalUrl}` });

exports.errorHandler = (err, req, res, next) => {
  if (err.name === 'SequelizeValidationError') return res.status(400).json({ message: err.errors.map((e) => e.message).join(', ') });
  if (err.name === 'SequelizeUniqueConstraintError') return res.status(409).json({ message: 'Record already exists (duplicate value)' });
  if (err.name === 'MulterError' || /images are allowed/.test(err.message)) return res.status(400).json({ message: err.message });
  console.error(err);
  res.status(err.status || 500).json({ message: err.status ? err.message : 'Internal server error' });
};
