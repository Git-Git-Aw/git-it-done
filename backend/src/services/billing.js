const { Lease, Payment } = require('../models');
const { dueDateFor } = require('../utils/helpers');
const { notify } = require('../utils/notify');

// Create the monthly bill for every active lease (skips leases already billed or not yet started)
exports.generateBills = async (period) => {
  const leases = await Lease.findAll({ where: { status: 'active' } });
  let created = 0;
  let alreadyBilled = 0;
  let notYetStarted = 0;
  for (const l of leases) {
    if (l.startDate.slice(0, 7) > period) { notYetStarted++; continue; }
    const [p, isNew] = await Payment.findOrCreate({
      where: { leaseId: l.id, period },
      defaults: { tenantId: l.tenantId, dueDate: dueDateFor(period, l.dueDay), amountDue: l.monthlyRent },
    });
    if (isNew) {
      created++;
      await notify(l.tenantId, 'billing', `Your bill for ${period} (due ${p.dueDate}) is ready.`, 'payment', p.id);
    } else {
      alreadyBilled++;
    }
  }
  return { period, created, alreadyBilled, notYetStarted };
};

exports.markPaid = async (p, amount, extra = {}) => {
  const total = p.amountPaid + amount;
  const paid = total >= p.amountDue;
  await p.update({ amountPaid: total, status: paid ? 'paid' : 'unpaid', paidAt: paid ? new Date() : null, ...extra });
  await notify(
    p.tenantId, 'payment',
    paid ? `Your payment for ${p.period} was confirmed. Thank you!` : `A partial payment was recorded for ${p.period}. Balance: ${p.amountDue - total}.`,
    'payment', p.id
  );
  return p;
};
