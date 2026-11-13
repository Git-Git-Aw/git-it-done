const router = require('express').Router();
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { Op } = require('sequelize');
const { User } = require('../models');
const { auth, signToken } = require('../middleware/auth');
const { asyncHandler, sha256 } = require('../utils/helpers');
const { notifyLandlords } = require('../utils/notify');

const strongEnough = (p) => typeof p === 'string' && p.length >= 8;

// Tenant self-registration -> status "pending" until landlord approves
router.post('/register', asyncHandler(async (req, res) => {
  const { fullName, email, password, contactNumber } = req.body;
  if (!fullName || !email || !password) return res.status(400).json({ message: 'fullName, email and password are required' });
  if (!strongEnough(password)) return res.status(400).json({ message: 'Password must be at least 8 characters' });
  const user = await User.create({
    fullName, email: String(email).toLowerCase().trim(), contactNumber,
    passwordHash: await bcrypt.hash(password, 10), role: 'tenant', status: 'pending',
  });
  await notifyLandlords('registration', `New tenant registration awaiting approval: ${user.fullName}`, 'user', user.id);
  res.status(201).json({ message: 'Registration submitted. Please wait for the landlord to approve your account.', user });
}));

router.post('/login', asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ message: 'email and password are required' });
  const user = await User.findOne({ where: { email: String(email).toLowerCase().trim() } });
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) return res.status(401).json({ message: 'Invalid email or password' });
  if (user.status === 'pending') return res.status(403).json({ message: 'Your account is still waiting for landlord approval' });
  if (user.status === 'archived') return res.status(403).json({ message: 'Your account has been archived' });
  res.json({ token: signToken(user), user });
}));

// JWTs are stateless: the client discards the token. Endpoint exists for a uniform logout flow.
router.post('/logout', auth, (req, res) => res.json({ message: 'Logged out' }));

router.get('/me', auth, (req, res) => res.json({ user: req.user }));

// No email delivery (out of scope): in development the reset token is returned in the response.
router.post('/forgot-password', asyncHandler(async (req, res) => {
  const { email } = req.body;
  const user = email && await User.findOne({ where: { email: String(email).toLowerCase().trim(), status: 'active' } });
  const body = { message: 'If the account exists, a reset token has been generated.' };
  if (user) {
    const token = crypto.randomBytes(24).toString('hex');
    await user.update({ resetTokenHash: sha256(token), resetExpires: new Date(Date.now() + 60 * 60 * 1000) });
    if (process.env.NODE_ENV !== 'production') body.resetToken = token;
  }
  res.json(body);
}));

router.post('/reset-password', asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  if (!token || !strongEnough(newPassword)) return res.status(400).json({ message: 'token and a newPassword of at least 8 characters are required' });
  const user = await User.findOne({ where: { resetTokenHash: sha256(token), resetExpires: { [Op.gt]: new Date() } } });
  if (!user) return res.status(400).json({ message: 'Reset token is invalid or expired' });
  await user.update({ passwordHash: await bcrypt.hash(newPassword, 10), resetTokenHash: null, resetExpires: null });
  res.json({ message: 'Password updated. You can now log in.' });
}));

router.post('/change-password', auth, asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!(await bcrypt.compare(currentPassword || '', req.user.passwordHash))) return res.status(400).json({ message: 'Current password is incorrect' });
  if (!strongEnough(newPassword)) return res.status(400).json({ message: 'New password must be at least 8 characters' });
  await req.user.update({ passwordHash: await bcrypt.hash(newPassword, 10) });
  res.json({ message: 'Password changed' });
}));

module.exports = router;
