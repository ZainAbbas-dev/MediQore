// M3 FE-2: a few visits waiting in the supervisors' conflict queue. Each is a
// second visit to a pregnancy on the same day (Pakistan time) as a visit
// already on the server, as two phones, or a phone that saved a visit twice,
// would send it. The held visit is stored as the device sent it, so the
// portal's review page has something to show in demos.
const PAKISTAN_OFFSET = 5 * 60 * 60 * 1000;
const MINUTE = 60 * 1000;

const pakistanDay = (date) => new Date(date.getTime() + PAKISTAN_OFFSET).toISOString().slice(0, 10);

function build({ random }, pregnant) {
  const lastVisit = new Map(); // pregnancy -> its latest visit
  for (const visit of pregnant.visits) lastVisit.set(visit.pregnancy_id, visit);

  const conflicts = [];
  for (const existing of lastVisit.values()) {
    if (!random.chance(0.08)) continue;

    // Later the same day if possible, otherwise earlier.
    let visitedAt = new Date(existing.visited_at.getTime() + random.int(30, 240) * MINUTE);
    if (pakistanDay(visitedAt) !== pakistanDay(existing.visited_at)) {
      visitedAt = new Date(existing.visited_at.getTime() - random.int(30, 240) * MINUTE);
    }
    const incoming = {
      table: 'visits',
      id: random.uuid(),
      areaId: existing.area_id,
      createdOnDevice: visitedAt.toISOString(),
      deleted: false,
      data: {
        pregnancyId: existing.pregnancy_id,
        visitedAt: visitedAt.toISOString(),
        systolicBpMmhg: existing.systolic_bp_mmhg + random.int(-6, 6),
        diastolicBpMmhg: existing.diastolic_bp_mmhg + random.int(-4, 4),
        weightKg: existing.weight_kg,
        temperatureC: existing.temperature_c,
        pulseBpm: existing.pulse_bpm,
        bloodSugarMmolL: existing.blood_sugar_mmol_l,
        fetalMovement: existing.fetal_movement,
        swelling: existing.swelling,
        bleeding: existing.bleeding,
        fever: existing.fever,
        anaemiaSigns: existing.anaemia_signs,
        urineSymptoms: existing.urine_symptoms,
      },
    };
    conflicts.push({
      id: random.uuid(),
      area_id: existing.area_id,
      table_name: 'visits',
      incoming_record_id: incoming.id,
      existing_record_id: existing.id,
      incoming_payload: JSON.stringify(incoming),
      reason: 'same_parent_same_day',
      submitted_by: existing.created_by,
      status: 'pending',
      created_at: visitedAt,
    });
  }
  return { conflicts };
}

module.exports = { build };
