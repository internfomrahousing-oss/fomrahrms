/**
 * FOMRA HRMS — eSSL x990 ADMS endpoint
 * Deployed automatically by Vercel at: /api/iclock/cdata
 * Rewritten to /iclock/cdata via vercel.json
 *
 * Environment variables (set in Vercel project settings):
 *   SUPABASE_URL  — https://YOURREF.supabase.co
 *   SUPABASE_KEY  — service_role key (NOT anon key)
 */

async function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => { data += chunk.toString(); });
    req.on('end',  () => resolve(data));
    req.on('error', reject);
  });
}

// ── Supabase REST helpers ─────────────────────────────────────────────────────

function sbHeaders() {
  const key = process.env.SUPABASE_KEY;
  return {
    apikey:          key,
    Authorization:   `Bearer ${key}`,
    'Content-Type':  'application/json',
  };
}

async function sbGet(path) {
  const res = await fetch(`${process.env.SUPABASE_URL}/rest/v1/${path}`, {
    headers: sbHeaders(),
  });
  return res.ok ? res.json() : [];
}

async function sbPost(table, body) {
  return fetch(`${process.env.SUPABASE_URL}/rest/v1/${table}`, {
    method:  'POST',
    headers: { ...sbHeaders(), Prefer: 'return=minimal' },
    body:    JSON.stringify(body),
  });
}

async function sbPatch(path, body) {
  return fetch(`${process.env.SUPABASE_URL}/rest/v1/${path}`, {
    method:  'PATCH',
    headers: { ...sbHeaders(), Prefer: 'return=minimal' },
    body:    JSON.stringify(body),
  });
}

// ── Punch processing ──────────────────────────────────────────────────────────

async function processLogs(rawBody) {
  const lines = rawBody.trim().split('\n').filter((l) => l.trim().length > 0);

  for (const line of lines) {
    // ADMS log: PIN\tDateTime\tStatus\tVerify\tWorkCode
    // Example:  0001\t2026-07-02 09:15:00\t0\t1\t0
    const parts = line.split('\t');
    if (parts.length < 2) continue;

    const pinId = parts[0].trim();
    const dt    = parts[1].trim();
    if (!pinId || !dt.includes(' ')) continue;

    const [dateISO, timeISO] = dt.split(' ');
    const [year, month, day] = dateISO.split('-');

    const date  = `${day}/${month}/${year}`;            // DD/MM/YYYY
    const time  = timeISO.substring(0, 5);               // HH:MM
    const recId = `${pinId}_${day}-${month}-${year}`;   // e.g. EMP001_02-07-2026

    // Look up employee name by biometric_id (device PIN)
    const users = await sbGet(
      `app_users?biometric_id=eq.${encodeURIComponent(pinId)}&select=name,employee_id&limit=1`
    );
    if (!users.length) {
      console.log(`ADMS: unknown biometric PIN "${pinId}" — set Biometric ID in HR employee records`);
      continue;
    }
    const employeeName = users[0].name;
    const empId        = users[0].employee_id || pinId;

    // Check today's existing attendance record
    const existing = await sbGet(
      `attendance_records?id=eq.${encodeURIComponent(recId)}&select=check_in_time,check_out_time&limit=1`
    );

    if (!existing.length) {
      // First punch → check-in
      await sbPost('attendance_records', {
        id:             recId,
        employee_name:  employeeName,
        employee_id:    empId,
        date,
        check_in_time:  time,
        check_out_time: '',
        location:       'Biometric device',
      });
      console.log(`ADMS: check-in  ${employeeName} ${date} ${time}`);
    } else {
      const rec = existing[0];
      if (rec.check_in_time && !rec.check_out_time) {
        // Has check-in, no check-out → second punch is check-out
        await sbPatch(
          `attendance_records?id=eq.${encodeURIComponent(recId)}`,
          { check_out_time: time }
        );
        console.log(`ADMS: check-out ${employeeName} ${date} ${time}`);
      }
      // Both already set (device resend) → ignore
    }
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

module.exports = async (req, res) => {
  const sn    = req.query.SN    ?? 'X990';
  const table = req.query.table ?? '';

  res.setHeader('Content-Type', 'text/plain');

  // GET — device handshake / heartbeat
  if (req.method === 'GET') {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    return res.status(200).send(
      [
        `GET OPTION FROM: ${sn}`,
        'ATTLOGStamp=0',
        'OPERLOGStamp=9999',
        'ATTPHOTOStamp=None',
        'ErrorDelay=30',
        'Delay=10',
        'TransTimes=00:00;14:05',
        'TransInterval=1',
        'TransFlag=TransData AttLog OpLog',
        'TimeZone=5.5',
        'Realtime=1',
        'Encrypt=0',
      ].join('\r\n') + '\r\n'
    );
  }

  // POST + table=ATTLOG — attendance punch records
  if (req.method === 'POST' && table === 'ATTLOG') {
    try {
      const body = await readBody(req);
      await processLogs(body);
    } catch (e) {
      console.error('ADMS error:', e);
    }
    return res.status(200).send('OK');
  }

  return res.status(200).send('OK');
};
