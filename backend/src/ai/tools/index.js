// Tools the AI Dorm Manager can use. Access is enforced HERE by role:
//  - tenant tools always use ctx.user.id (the model can never pick another tenant)
//  - visitor tools only read public data
//  - tools with write: true never run directly; the agent turns them into a pending action the user must confirm.
const { Op } = require('sequelize');
const { Room, Lease, Payment, MaintenanceReport, User, Announcement, VisitorInquiry, DormInfo } = require('../../models');
const { presentPayment, currentPeriod, isPeriod, todayStr, httpError } = require('../../utils/helpers');
const { notifyLandlords } = require('../../utils/notify');
const { landlordSummary } = require('../../services/dashboard');
const { generateBills, markPaid } = require('../../services/billing');
const { createReport, updateReport, CATEGORIES, URGENCIES, STATUSES } = require('../../services/maintenance');
const { createAnnouncement } = require('../../services/announcements');

const PAY_FILTERS = ['paid', 'unpaid', 'overdue', 'pending_confirmation'];
const ALL = ['landlord', 'tenant', 'visitor'];

/* ---------- small validators (throw 400 errors the model can read and fix) ---------- */
const bad = (msg) => httpError(400, msg);
const str = (v, name, { max = 255, min = 1, required = false } = {}) => {
  if (v === undefined || v === null || v === '') { if (required) throw bad(`${name} is required`); return undefined; }
  if (typeof v !== 'string') throw bad(`${name} must be text`);
  const s = v.trim();
  if (!s) { if (required) throw bad(`${name} is required`); return undefined; }
  if (s.length < min) throw bad(`${name} is too short`);
  return s.slice(0, max);
};
const oneOf = (v, list, name, required = false) => {
  if (v === undefined || v === null || v === '') { if (required) throw bad(`${name} is required`); return undefined; }
  if (!list.includes(v)) throw bad(`${name} must be one of: ${list.join(', ')}`);
  return v;
};
const posInt = (v, name) => {
  const n = Number(v);
  if (!Number.isInteger(n) || n < 1) throw bad(`${name} must be a positive whole number`);
  return n;
};
const periodOrNow = (v) => {
  if (v === undefined || v === null || v === '') return currentPeriod();
  if (!isPeriod(v)) throw bad('period must be YYYY-MM');
  return v;
};
const peso = (n) => `₱${Number(n).toLocaleString('en-PH', { maximumFractionDigits: 2 })}`;
const obj = (properties = {}, required = []) => ({ type: 'object', properties, required });
const clip = (s, n) => (s && s.length > n ? `${s.slice(0, n)}…` : s || null);

const getInfo = async () => DormInfo.findOne({ order: [['id', 'ASC']] });

const occupancyOf = (room) => {
  const occupants = (room.leases || []).length;
  return { occupants, status: occupants === 0 ? 'vacant' : occupants >= room.capacity ? 'full' : 'occupied' };
};

const TOOLS = [
  /* ================= shared ================= */
  {
    name: 'get_dorm_info', roles: ALL, write: false,
    description: 'Get the dormitory name, address, contact number, description, house rules, and requirements for renting.',
    input_schema: obj(),
    run: async () => {
      const i = await getInfo();
      if (!i) return { message: 'The landlord has not filled in the dormitory information yet.' };
      return { dormName: i.dormName, address: i.address, contactNumber: i.contactNumber, about: i.about, houseRules: i.houseRules, requirements: i.requirements };
    },
  },
  {
    name: 'list_announcements', roles: ['landlord', 'tenant'], write: false,
    description: 'Get the latest dormitory announcements.',
    input_schema: obj(),
    run: async () => (await Announcement.findAll({ where: { isArchived: false }, order: [['pinned', 'DESC'], ['createdAt', 'DESC']], limit: 5 }))
      .map((a) => ({ title: a.title, body: clip(a.body, 400), pinned: a.pinned, postedAt: a.createdAt })),
  },

  /* ================= landlord: read ================= */
  {
    name: 'get_dashboard_summary', roles: ['landlord'], write: false,
    description: 'Get the dormitory summary for a month: total collections, outstanding balance, occupancy, how many tenants are paid/unpaid/overdue, and open maintenance. Omit period for the current month.',
    input_schema: obj({ period: { type: 'string', description: 'Month as YYYY-MM' } }),
    run: async (ctx, i) => {
      const s = await landlordSummary(periodOrNow(i.period));
      return {
        ...s,
        maintenance: {
          openCount: s.maintenance.openCount,
          roomsNeedingMaintenance: s.maintenance.roomsNeedingMaintenance.map((r) => r.roomNumber),
          recent: s.maintenance.recent.map((r) => ({ id: r.id, room: r.room && r.room.roomNumber, category: r.category, urgency: r.urgency, status: r.status })),
        },
      };
    },
  },
  {
    name: 'list_payments', roles: ['landlord'], write: false,
    description: 'List tenant payments/bills (max 50). Filter by status (paid, unpaid = not yet due, overdue, pending_confirmation) and/or month. Omit period to include all months. Each row has the payment id.',
    input_schema: obj({ status: { type: 'string', enum: PAY_FILTERS }, period: { type: 'string', description: 'Month as YYYY-MM' } }),
    run: async (ctx, i) => {
      const status = oneOf(i.status, PAY_FILTERS, 'status');
      const where = {};
      if (i.period !== undefined) where.period = periodOrNow(i.period);
      if (status === 'overdue') { where.status = 'unpaid'; where.dueDate = { [Op.lt]: todayStr() }; }
      else if (status === 'unpaid') { where.status = 'unpaid'; where.dueDate = { [Op.gte]: todayStr() }; }
      else if (status) where.status = status;
      const rows = await Payment.findAll({
        where, limit: 50, order: [['period', 'DESC'], ['dueDate', 'ASC']],
        include: [
          { model: User, as: 'tenant', attributes: ['fullName'] },
          { model: Lease, as: 'lease', include: [{ model: Room, as: 'room', attributes: ['roomNumber'] }] },
        ],
      });
      return rows.map((r) => {
        const p = presentPayment(r);
        return { paymentId: p.id, tenant: r.tenant && r.tenant.fullName, room: r.lease && r.lease.room && r.lease.room.roomNumber, period: p.period, dueDate: p.dueDate, amountDue: p.amountDue, amountPaid: p.amountPaid, balance: p.balance, status: p.displayStatus };
      });
    },
  },
  {
    name: 'list_rooms', roles: ['landlord'], write: false,
    description: 'List active rooms with rate, capacity, occupants, and status (vacant, occupied, full).',
    input_schema: obj({ status: { type: 'string', enum: ['vacant', 'occupied', 'full'] } }),
    run: async (ctx, i) => {
      const status = oneOf(i.status, ['vacant', 'occupied', 'full'], 'status');
      const rooms = await Room.findAll({
        where: { isArchived: false }, order: [['roomNumber', 'ASC']],
        include: [{ model: Lease, as: 'leases', where: { status: 'active' }, required: false, include: [{ model: User, as: 'tenant', attributes: ['fullName'] }] }],
      });
      return rooms.map((r) => ({ r, o: occupancyOf(r) })).filter(({ o }) => !status || o.status === status)
        .map(({ r, o }) => ({ roomNumber: r.roomNumber, description: r.description, monthlyRate: r.monthlyRate, capacity: r.capacity, occupants: o.occupants, status: o.status, tenants: r.leases.map((l) => l.tenant && l.tenant.fullName) }));
    },
  },
  {
    name: 'list_maintenance_reports', roles: ['landlord'], write: false,
    description: 'List maintenance reports (max 30, newest first). Filter by status (Pending, In Progress, Resolved) and/or room number. Each row has the report id.',
    input_schema: obj({ status: { type: 'string', enum: STATUSES }, room_number: { type: 'string' } }),
    run: async (ctx, i) => {
      const status = oneOf(i.status, STATUSES, 'status');
      const roomNumber = str(i.room_number, 'room_number', { max: 20 });
      const rows = await MaintenanceReport.findAll({
        where: status ? { status } : {}, limit: 30, order: [['createdAt', 'DESC']],
        include: [
          { model: Room, as: 'room', attributes: ['roomNumber'], ...(roomNumber ? { where: { roomNumber } } : {}) },
          { model: User, as: 'tenant', attributes: ['fullName'] },
        ],
      });
      return rows.map((r) => ({ reportId: r.id, room: r.room && r.room.roomNumber, tenant: r.tenant && r.tenant.fullName, category: r.category, urgency: r.urgency, status: r.status, description: clip(r.description, 200), assignedTo: r.assignedTo, remarks: r.remarks, reportedAt: r.createdAt }));
    },
  },
  {
    name: 'list_tenants', roles: ['landlord'], write: false,
    description: 'List tenants (max 50) with account status (pending, active, archived) and current room.',
    input_schema: obj({ status: { type: 'string', enum: ['pending', 'active', 'archived'] } }),
    run: async (ctx, i) => {
      const status = oneOf(i.status, ['pending', 'active', 'archived'], 'status');
      const rows = await User.findAll({
        where: { role: 'tenant', ...(status ? { status } : {}) }, limit: 50, order: [['fullName', 'ASC']],
        include: [{ model: Lease, as: 'leases', where: { status: 'active' }, required: false, include: [{ model: Room, as: 'room', attributes: ['roomNumber'] }] }],
      });
      return rows.map((t) => ({ name: t.fullName, status: t.status, contactNumber: t.contactNumber, room: t.leases[0] && t.leases[0].room ? t.leases[0].room.roomNumber : null }));
    },
  },
  {
    name: 'list_inquiries', roles: ['landlord'], write: false,
    description: 'List inquiries left by visitors (prospective tenants), newest first (max 30).',
    input_schema: obj({ status: { type: 'string', enum: ['new', 'contacted'] } }),
    run: async (ctx, i) => {
      const status = oneOf(i.status, ['new', 'contacted'], 'status');
      return (await VisitorInquiry.findAll({ where: status ? { status } : {}, order: [['createdAt', 'DESC']], limit: 30 }))
        .map((q) => ({ name: q.name, contactNumber: q.contactNumber, message: clip(q.message, 200), status: q.status, receivedAt: q.createdAt }));
    },
  },

  /* ================= landlord: write (need confirmation) ================= */
  {
    name: 'generate_bills', roles: ['landlord'], write: true,
    description: 'PROPOSE generating the monthly rent bills for all active leases for a month (omit period for the current month). Needs the landlord\'s confirmation.',
    input_schema: obj({ period: { type: 'string', description: 'Month as YYYY-MM' } }),
    prepare: (i) => ({ period: periodOrNow(i.period) }),
    describe: async (i) => `Generate rent bills for ${i.period} for all active leases`,
    run: async (ctx, i) => generateBills(i.period),
    successMessage: (r) => `Bills for ${r.period}: ${r.created} created, ${r.alreadyBilled} already existed${r.notYetStarted ? `, ${r.notYetStarted} lease(s) not started yet` : ''}.`,
  },
  {
    name: 'record_payment', roles: ['landlord'], write: true,
    description: 'PROPOSE recording a payment received for a bill. Use the paymentId from list_payments. Omit amount to record the full remaining balance. Needs the landlord\'s confirmation.',
    input_schema: obj({ payment_id: { type: 'integer' }, amount: { type: 'number' }, method: { type: 'string', description: 'e.g. cash, GCash' } }, ['payment_id']),
    prepare: (i) => {
      const out = { paymentId: posInt(i.payment_id, 'payment_id'), method: str(i.method, 'method', { max: 30 }) };
      if (i.amount !== undefined && i.amount !== null) {
        const a = Number(i.amount);
        if (!(a > 0)) throw bad('amount must be greater than 0');
        out.amount = a;
      }
      return out;
    },
    describe: async (i) => {
      const p = await Payment.findByPk(i.paymentId, { include: [{ model: User, as: 'tenant', attributes: ['fullName'] }] });
      if (!p) throw httpError(404, 'Payment not found');
      if (p.status === 'paid') throw httpError(409, 'That payment is already fully paid');
      const amt = i.amount ?? (p.amountDue - p.amountPaid);
      return `Record ${peso(amt)}${i.method ? ` (${i.method})` : ''} for ${p.tenant ? p.tenant.fullName : 'tenant'}, bill ${p.period}`;
    },
    run: async (ctx, i) => {
      const p = await Payment.findByPk(i.paymentId);
      if (!p) throw httpError(404, 'Payment not found');
      if (p.status === 'paid') throw httpError(409, 'That payment is already fully paid');
      await markPaid(p, i.amount ?? (p.amountDue - p.amountPaid), { method: i.method || p.method });
      const fresh = presentPayment(await Payment.findByPk(p.id));
      return { paymentId: fresh.id, period: fresh.period, status: fresh.displayStatus, amountPaid: fresh.amountPaid, balance: fresh.balance };
    },
    successMessage: (r) => `Payment recorded for ${r.period}. Status: ${r.status}${r.balance ? `, balance ${peso(r.balance)}` : ''}.`,
  },
  {
    name: 'update_maintenance_report', roles: ['landlord'], write: true,
    description: 'PROPOSE updating a maintenance report: status (Pending, In Progress, Resolved), remarks, and/or who it is assigned to. Use the reportId from list_maintenance_reports. Needs the landlord\'s confirmation.',
    input_schema: obj({ report_id: { type: 'integer' }, status: { type: 'string', enum: STATUSES }, remarks: { type: 'string' }, assigned_to: { type: 'string' } }, ['report_id']),
    prepare: (i) => {
      const out = {
        reportId: posInt(i.report_id, 'report_id'),
        status: oneOf(i.status, STATUSES, 'status'),
        remarks: str(i.remarks, 'remarks', { max: 500 }),
        assignedTo: str(i.assigned_to, 'assigned_to', { max: 120 }),
      };
      if (!out.status && !out.remarks && !out.assignedTo) throw bad('Provide at least one of status, remarks, or assigned_to');
      return out;
    },
    describe: async (i) => {
      const parts = [];
      if (i.status) parts.push(`status → ${i.status}`);
      if (i.assignedTo) parts.push(`assigned to ${i.assignedTo}`);
      if (i.remarks) parts.push(`remarks: "${clip(i.remarks, 80)}"`);
      return `Update maintenance report #${i.reportId}: ${parts.join(', ')}`;
    },
    run: async (ctx, i) => {
      const r = await updateReport(i.reportId, { status: i.status, remarks: i.remarks, assignedTo: i.assignedTo });
      return { reportId: r.id, status: r.status, assignedTo: r.assignedTo, remarks: r.remarks };
    },
    successMessage: (r) => `Report #${r.reportId} updated (status: ${r.status}).`,
  },
  {
    name: 'post_announcement', roles: ['landlord'], write: true,
    description: 'PROPOSE posting a dormitory announcement to all tenants. Needs the landlord\'s confirmation.',
    input_schema: obj({ title: { type: 'string' }, body: { type: 'string' }, pinned: { type: 'boolean' } }, ['title', 'body']),
    prepare: (i) => ({ title: str(i.title, 'title', { max: 160, required: true }), body: str(i.body, 'body', { max: 2000, required: true }), pinned: i.pinned === true }),
    describe: async (i) => `Post announcement "${i.title}"${i.pinned ? ' (pinned)' : ''}: ${clip(i.body, 150)}`,
    run: async (ctx, i) => {
      const a = await createAnnouncement(ctx.user, i);
      return { announcementId: a.id, title: a.title };
    },
    successMessage: (r) => `Announcement "${r.title}" posted. Tenants were notified.`,
  },

  /* ================= tenant: read (own data only) ================= */
  {
    name: 'get_my_balance', roles: ['tenant'], write: false,
    description: 'Get the tenant\'s unpaid balance, the next due date, and their unpaid or pending bills.',
    input_schema: obj(),
    run: async (ctx) => {
      const open = (await Payment.findAll({ where: { tenantId: ctx.user.id, status: { [Op.ne]: 'paid' } }, order: [['dueDate', 'ASC']] })).map(presentPayment);
      const next = open.find((p) => p.status === 'unpaid') || open[0] || null;
      return {
        totalBalance: open.reduce((s, p) => s + p.balance, 0),
        nextDue: next ? { period: next.period, dueDate: next.dueDate, balance: next.balance, status: next.displayStatus } : null,
        bills: open.map((p) => ({ period: p.period, dueDate: p.dueDate, amountDue: p.amountDue, amountPaid: p.amountPaid, balance: p.balance, status: p.displayStatus })),
      };
    },
  },
  {
    name: 'get_my_payments', roles: ['tenant'], write: false,
    description: 'Get the tenant\'s payment history (latest 12 months).',
    input_schema: obj(),
    run: async (ctx) => (await Payment.findAll({ where: { tenantId: ctx.user.id }, order: [['period', 'DESC']], limit: 12 }))
      .map(presentPayment).map((p) => ({ period: p.period, dueDate: p.dueDate, amountDue: p.amountDue, amountPaid: p.amountPaid, balance: p.balance, status: p.displayStatus, paidAt: p.paidAt })),
  },
  {
    name: 'get_my_room', roles: ['tenant'], write: false,
    description: 'Get the tenant\'s room and lease details.',
    input_schema: obj(),
    run: async (ctx) => {
      const l = await Lease.findOne({ where: { tenantId: ctx.user.id, status: 'active' }, include: [{ model: Room, as: 'room' }] });
      if (!l) return { message: 'You have no active room assignment yet.' };
      return { roomNumber: l.room.roomNumber, description: l.room.description, monthlyRent: l.monthlyRent, dueDay: l.dueDay, startDate: l.startDate, endDate: l.endDate };
    },
  },
  {
    name: 'list_my_reports', roles: ['tenant'], write: false,
    description: 'List the tenant\'s own repair reports and their status.',
    input_schema: obj(),
    run: async (ctx) => (await MaintenanceReport.findAll({ where: { tenantId: ctx.user.id }, order: [['createdAt', 'DESC']], limit: 10 }))
      .map((r) => ({ reportId: r.id, category: r.category, urgency: r.urgency, status: r.status, description: clip(r.description, 150), remarks: r.remarks, assignedTo: r.assignedTo, reportedAt: r.createdAt })),
  },

  /* ================= tenant: write ================= */
  {
    name: 'submit_maintenance_report', roles: ['tenant'], write: true,
    description: 'PROPOSE submitting a repair report for the tenant\'s room. You must choose the category and the urgency (low, medium, high). The tenant confirms before it is sent.',
    input_schema: obj({
      category: { type: 'string', enum: CATEGORIES },
      urgency: { type: 'string', enum: URGENCIES },
      description: { type: 'string', description: 'What is wrong, in the tenant\'s words, clear and short' },
    }, ['category', 'urgency', 'description']),
    prepare: (i) => ({
      category: oneOf(i.category, CATEGORIES, 'category', true),
      urgency: oneOf(i.urgency, URGENCIES, 'urgency', true),
      description: str(i.description, 'description', { max: 1000, min: 5, required: true }),
    }),
    describe: async (i) => `Submit a ${i.urgency}-urgency ${i.category} repair report: "${clip(i.description, 150)}"`,
    run: async (ctx, i) => {
      const r = await createReport(ctx.user, i);
      return { reportId: r.id, room: r.room && r.room.roomNumber, category: r.category, urgency: r.urgency };
    },
    successMessage: (r) => `Report #${r.reportId} submitted (${r.category}, ${r.urgency} urgency). The landlord has been notified.`,
  },

  /* ================= visitor ================= */
  {
    name: 'get_available_rooms', roles: ['visitor'], write: false,
    description: 'List rooms that still have a free slot, with monthly rate and number of free slots. Public information only.',
    input_schema: obj(),
    run: async () => {
      const rooms = await Room.findAll({
        where: { isArchived: false }, order: [['roomNumber', 'ASC']],
        include: [{ model: Lease, as: 'leases', where: { status: 'active' }, required: false, attributes: ['id'] }],
      });
      const open = rooms.map((r) => ({ r, free: r.capacity - r.leases.length })).filter((x) => x.free > 0);
      if (!open.length) return { message: 'No rooms are available right now.' };
      return open.map(({ r, free }) => ({ roomNumber: r.roomNumber, description: r.description, monthlyRate: r.monthlyRate, availableSlots: free }));
    },
  },
  {
    name: 'submit_inquiry', roles: ['visitor'], write: true,
    description: 'PROPOSE sending the visitor\'s inquiry (name, contact number, optional message) to the landlord. Only after the visitor gave their name and contact number. The visitor confirms before it is sent.',
    input_schema: obj({ name: { type: 'string' }, contact_number: { type: 'string' }, message: { type: 'string' } }, ['name', 'contact_number']),
    prepare: (i) => {
      const contactNumber = str(i.contact_number, 'contact_number', { max: 30, required: true });
      if (!/^[0-9+()\-\s]{7,30}$/.test(contactNumber)) throw bad('contact_number must be a valid phone number');
      return { name: str(i.name, 'name', { max: 120, required: true }), contactNumber, message: str(i.message, 'message', { max: 500 }) };
    },
    describe: async (i) => `Send an inquiry to the landlord: ${i.name}, ${i.contactNumber}${i.message ? `, "${clip(i.message, 100)}"` : ''}`,
    run: async (ctx, i) => {
      const q = await VisitorInquiry.create({ name: i.name, contactNumber: i.contactNumber, message: i.message || null });
      await notifyLandlords('inquiry', `New inquiry from ${i.name} (${i.contactNumber}).`, 'inquiry', q.id);
      return { inquiryId: q.id };
    },
    successMessage: () => 'Your inquiry was sent. The landlord will contact you.',
  },
];

exports.toolsForRole = (role) => TOOLS.filter((t) => t.roles.includes(role));
exports.getTool = (name, role) => TOOLS.find((t) => t.name === name && t.roles.includes(role));
