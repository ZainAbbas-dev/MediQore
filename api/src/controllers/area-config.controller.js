const areaConfig = require('../services/area-config.service');

async function contactOptions(req, res) {
  res.json(await areaConfig.contactOptions(req.user));
}

async function listContacts(req, res) {
  res.json({ contacts: await areaConfig.listContacts(req.user) });
}

async function getContact(req, res) {
  res.json({ contact: await areaConfig.getContact(req.user, req.params.areaId) });
}

async function saveContact(req, res) {
  const { contact, created } = await areaConfig.saveContact(req.user, req.params.areaId, req.body);
  res.status(created ? 201 : 200).json({ contact });
}

async function deleteContact(req, res) {
  await areaConfig.deleteContact(req.user, req.params.areaId);
  res.sendStatus(204);
}

async function campaignOptions(req, res) {
  res.json({ areas: await areaConfig.campaignOptions(req.user) });
}

async function listRounds(req, res) {
  res.json({ rounds: await areaConfig.listRounds(req.user) });
}

async function createRound(req, res) {
  res.status(201).json({ round: await areaConfig.createRound(req.user, req.body) });
}

async function updateRound(req, res) {
  res.json({ round: await areaConfig.updateRound(req.user, req.params.roundId, req.body) });
}

async function deleteRound(req, res) {
  await areaConfig.deleteRound(req.user, req.params.roundId);
  res.sendStatus(204);
}

module.exports = {
  contactOptions, listContacts, getContact, saveContact, deleteContact,
  campaignOptions, listRounds, createRound, updateRound, deleteRound,
};
