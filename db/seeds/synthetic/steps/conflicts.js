// M3 FE-2, M10 FE-3: a few possible duplicates waiting on the supervisors'
// Conflict Review page. Each is a woman registered a second time in the same
// household with the same name and husband's name, as a second phone or a new
// activation of the same phone would send her (activation number 02). Both
// records are stored, as the server keeps them, and the newer one is listed for
// the supervisor, so the portal's review page has something to show in demos.
const DAY = 24 * 60 * 60 * 1000;

function build({ random, now }, pregnant) {
  const pregnancyOf = new Map(pregnant.pregnancies.map((p) => [p.woman_id, p]));
  const historyOf = new Map(pregnant.obstetricHistory.map((h) => [h.woman_id, h]));

  const women = [];
  const pregnancies = [];
  const obstetricHistory = [];
  const conflicts = [];
  for (const existing of pregnant.women) {
    if (!random.chance(0.05)) continue;
    const registeredAt = new Date(Math.min(now.getTime() - DAY, existing.created_on_device.getTime() + random.int(1, 10) * DAY));
    const base = { area_id: existing.area_id, created_by: existing.created_by, created_on_device: registeredAt };

    const woman = {
      ...existing,
      ...base,
      id: random.uuid(),
      patient_code: existing.patient_code.replace(/-01-(\d{4})$/, '-02-$1'),
      age: existing.age + random.int(-1, 1),
      contact_number: existing.contact_number,
    };
    women.push(woman);
    pregnancies.push({ ...pregnancyOf.get(existing.id), ...base, id: random.uuid(), woman_id: woman.id, registered_on: registeredAt.toISOString().slice(0, 10) });
    obstetricHistory.push({ ...historyOf.get(existing.id), ...base, id: random.uuid(), woman_id: woman.id });

    const { id: _id, area_id: areaId, created_by: _by, created_on_device: createdOnDevice, ...fields } = woman;
    conflicts.push({
      id: random.uuid(),
      area_id: areaId,
      table_name: 'women',
      incoming_record_id: woman.id,
      existing_record_id: existing.id,
      incoming_payload: JSON.stringify({
        table: 'women',
        id: woman.id,
        areaId,
        createdOnDevice: createdOnDevice.toISOString(),
        deleted: false,
        data: {
          householdId: fields.household_id,
          patientCode: fields.patient_code,
          name: fields.name,
          age: fields.age,
          husbandName: fields.husband_name,
          contactNumber: fields.contact_number,
        },
      }),
      reason: 'possible_duplicate',
      submitted_by: existing.created_by,
      status: 'pending',
      created_at: registeredAt,
    });
  }
  return { women, pregnancies, obstetricHistory, conflicts };
}

module.exports = { build };
