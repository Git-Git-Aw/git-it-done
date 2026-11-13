const { Op } = require('sequelize');
const { Room, Lease, Payment, MaintenanceReport } = require('../models');
const { presentPayment, todayStr } = require('../utils/helpers');

exports.landlordSummary = async (period) => {
  const rooms = await Room.findAll({ where: { isArchived: false }, include: [{ model: Lease, as: 'leases', where: { status: 'active' }, required: false, attributes: ['id'] }] });
  const totalCapacity = rooms.reduce((s, r) => s + r.capacity, 0);
  const occupiedSlots = rooms.reduce((s, r) => s + r.leases.length, 0);
  const occupiedRooms = rooms.filter((r) => r.leases.length > 0).length;

  const monthPayments = (await Payment.findAll({ where: { period } })).map(presentPayment);
  const allOpen = await Payment.findAll({ where: { status: { [Op.ne]: 'paid' } } });

  const openReports = await MaintenanceReport.findAll({
    where: { status: { [Op.ne]: 'Resolved' } },
    include: [{ model: Room, as: 'room', attributes: ['id', 'roomNumber'] }],
    order: [['createdAt', 'DESC']],
  });
  const roomsNeedingMaintenance = [...new Map(openReports.map((r) => [r.room.id, r.room])).values()];

  return {
    period,
    totalCollections: monthPayments.reduce((s, p) => s + p.amountPaid, 0),
    outstandingBalance: allOpen.reduce((s, p) => s + (p.amountDue - p.amountPaid), 0),
    occupancy: {
      rate: totalCapacity ? Math.round((occupiedSlots / totalCapacity) * 100) : 0,
      occupiedSlots, totalCapacity, totalRooms: rooms.length, occupiedRooms, vacantRooms: rooms.length - occupiedRooms,
    },
    tenantsByPayment: {
      paid: monthPayments.filter((p) => p.displayStatus === 'paid').length,
      pendingConfirmation: monthPayments.filter((p) => p.displayStatus === 'pending_confirmation').length,
      unpaid: monthPayments.filter((p) => p.displayStatus === 'unpaid').length,
      overdue: monthPayments.filter((p) => p.displayStatus === 'overdue').length,
    },
    maintenance: { openCount: openReports.length, roomsNeedingMaintenance, recent: openReports.slice(0, 5) },
    asOf: todayStr(),
  };
};
