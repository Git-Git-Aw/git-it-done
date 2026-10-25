const { Announcement, User } = require('../models');
const { httpError } = require('../utils/helpers');
const { notify } = require('../utils/notify');

exports.createAnnouncement = async (author, { title, body, pinned }) => {
  if (!title || !body) throw httpError(400, 'title and body are required');
  const a = await Announcement.create({ authorId: author.id, title, body, pinned: !!pinned });
  const tenants = await User.findAll({ where: { role: 'tenant', status: 'active' }, attributes: ['id'] });
  await Promise.all(tenants.map((t) => notify(t.id, 'announcement', `New announcement: ${a.title}`, 'announcement', a.id)));
  return Announcement.findByPk(a.id, { include: [{ model: User, as: 'author', attributes: ['id', 'fullName'] }] });
};
