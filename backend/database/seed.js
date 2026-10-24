// WARNING: drops and recreates all tables, then inserts demo data. Development only.
require('dotenv').config();
const bcrypt = require('bcrypt');
const { sequelize, User, Room, Lease, Payment, MaintenanceReport, Announcement, DormInfo, VisitorInquiry } = require('../src/models');
const { currentPeriod, dueDateFor } = require('../src/utils/helpers');

const prevPeriod = () => {
  const d = new Date(); d.setMonth(d.getMonth() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
};

(async () => {
  await sequelize.sync({ force: true });
  const hash = (p) => bcrypt.hash(p, 10);

  const landlord = await User.create({ fullName: 'Demo Landlord', email: 'landlord@gitinside.test', passwordHash: await hash('Landlord123!'), role: 'landlord', status: 'active', contactNumber: '09170000000' });
  const tenants = [];
  for (const [name, email] of [['Ana Reyes', 'ana@gitinside.test'], ['Ben Cruz', 'ben@gitinside.test'], ['Carla Diaz', 'carla@gitinside.test']]) {
    tenants.push(await User.create({ fullName: name, email, passwordHash: await hash('Tenant123!'), role: 'tenant', status: 'active', contactNumber: '09171111111' }));
  }
  await User.create({ fullName: 'Pending Tenant', email: 'pending@gitinside.test', passwordHash: await hash('Tenant123!'), role: 'tenant', status: 'pending' });

  const rooms = await Room.bulkCreate([
    { roomNumber: '101', description: 'Ground floor, single bed', monthlyRate: 2500, capacity: 1 },
    { roomNumber: '102', description: 'Ground floor, double deck', monthlyRate: 3500, capacity: 2 },
    { roomNumber: '201', description: 'Second floor, with window', monthlyRate: 3000, capacity: 1 },
    { roomNumber: '202', description: 'Second floor, vacant', monthlyRate: 3000, capacity: 1 },
  ]);

  const start = '2026-08-01';
  const leases = [];
  leases.push(await Lease.create({ tenantId: tenants[0].id, roomId: rooms[0].id, startDate: start, monthlyRent: 2500, dueDay: 5 }));
  leases.push(await Lease.create({ tenantId: tenants[1].id, roomId: rooms[1].id, startDate: start, monthlyRent: 1750, dueDay: 10 }));
  leases.push(await Lease.create({ tenantId: tenants[2].id, roomId: rooms[2].id, startDate: start, monthlyRent: 3000, dueDay: 15 }));

  const prev = prevPeriod(); const cur = currentPeriod();
  for (const l of leases) {
    await Payment.create({ leaseId: l.id, tenantId: l.tenantId, period: prev, dueDate: dueDateFor(prev, l.dueDay), amountDue: l.monthlyRent, amountPaid: l.id === leases[2].id ? 0 : l.monthlyRent, status: l.id === leases[2].id ? 'unpaid' : 'paid', paidAt: l.id === leases[2].id ? null : new Date(), method: 'cash' });
    await Payment.create({ leaseId: l.id, tenantId: l.tenantId, period: cur, dueDate: dueDateFor(cur, l.dueDay), amountDue: l.monthlyRent });
  }

  await MaintenanceReport.create({ tenantId: tenants[0].id, roomId: rooms[0].id, category: 'plumbing', description: 'Leaking faucet in the comfort room.' });
  await Announcement.create({ authorId: landlord.id, title: 'House rules reminder', body: 'Quiet hours are from 10:00 PM to 6:00 AM. Please keep common areas clean.', pinned: true });

  await DormInfo.create({ dormName: 'Git-Inside Dormitory', address: '123 Sample Street, Cagayan de Oro City', contactNumber: '09170000000', about: 'A quiet, student-friendly dormitory near the university.', houseRules: 'Quiet hours 10:00 PM to 6:00 AM. No overnight guests without the landlord\'s permission. Keep common areas clean. Rent is due on the date shown in your lease.', requirements: 'Valid ID, one month deposit, and one month advance payment.' });
  await VisitorInquiry.create({ name: 'Sample Visitor', contactNumber: '09181234567', message: 'Is Room 202 still available?' });

  console.log('Seed complete.\n  Landlord: landlord@gitinside.test / Landlord123!\n  Tenant:   ana@gitinside.test / Tenant123!');
  await sequelize.close();
})().catch((e) => { console.error(e); process.exit(1); });
