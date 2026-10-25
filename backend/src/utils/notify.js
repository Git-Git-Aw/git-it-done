const { Notification, User } = require('../models');

exports.notify = (userId, type, message, refType = null, refId = null) =>
  Notification.create({ userId, type, message: String(message).slice(0, 255), refType, refId });

exports.notifyLandlords = async (type, message, refType = null, refId = null) => {
  const landlords = await User.findAll({ where: { role: 'landlord', status: 'active' }, attributes: ['id'] });
  await Promise.all(landlords.map((l) => exports.notify(l.id, type, message, refType, refId)));
};
