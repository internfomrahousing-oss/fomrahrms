/**
 * FOMRA HRMS — eSSL x990 ADMS Attendance Worker
 * Deploy at: dash.cloudflare.com → Workers & Pages → Create Worker
 *
 * Required environment variables (set in Worker Settings → Variables):
 *   SUPABASE_URL   e.g. https://abcdefgh.supabase.co
 *   SUPABASE_KEY   service_role secret key (not anon key)
 *
 * Device settings (ADMS / PUSH):
 *   Server Address : <your-worker-name>.workers.dev
 *   Server Port    : 443
 *   (leave path empty — device appends /iclock/cdata automatically)
 */

export default {
  async fetch(request, env) {
    const url   = new URL(request.url);
    const sn    = url.searchParams.get('SN')    ?? 'X990';
    const table = url.searchParams.get('table') ?? '';
    const ct    = { 'Content-Type': 'text/plain' };

    // Only handle /iclock/cdata
    if (!url.pathname.includes('/iclock/cdata')) {
      return new Response('Not Found', { status: 404 });
    }

    // GET → device handshake / heartbeat
    if (request.method === 'GET') {
      return new Response(
        [
          `GET OPTION FROM: ${sn}`,
          'ATTLOGStamp=9999',
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
        ].join('\n') + '\n',
        { headers: ct }
      );
    }

    // POST + table=ATTLOG → attendance punch records
    if (request.method === 'POST' && table === 'ATTLOG') {
      try {
        const body = await request.text();
        await processLogs(body, env);
      } catch (e) {
        console.error('ADMS processing error:', e);
      }
      return new Response('OK', { headers: ct });
    }

    return new Response('OK', { headers: ct });
  },
};

// ── Core punch processing ─────────────────────────────────────────────────────

async function processLogs(body, env) {
  const lines = body.trim().split('\n').filter((l) => l.trim().length > 0);

  for (const line of lines) {
    // ADMS log format: PIN\tDateTime\tStatus\tVerify\tWorkCode\n
    // Example:         0001\t2026-07-02 09:15:00\t0\t1\t0
    const parts = line.split('\t');
    if (parts.length < 2) continue;

    const pinId = parts[0].trim(); // employee_id stored on device
    const dt    = parts[1].trim(); // "YYYY-MM-DD HH:MM:SS"

    if (!pinId || !dt.includes(' ')) continue;

    const [dateISO, timeISO] = dt.split(' ');
    const [year, month, day] = dateISO.split('-');

    const date  = `${day}/${month}/${year}`;           // DD/MM/YYYY  (HRMS format)
    const time  = timeISO.substring(0, 5);              // HH:MM
    const recId = `${pinId}_${day}-${month}-${year}`;  // e.g. EMP001_02-07-2026

    // 1. Resolve employee name from app_users
    const empRes = await sbGet(
      env,
      `app_users?employee_id=eq.${enc(pinId)}&select=name&limit=1`
    );
    if (!empRes.length) {
      console.log(`ADMS: unknown PIN "${pinId}" — skipping`);
      continue;
    }
    const employeeName = empRes[0].name;

    // 2. Check for existing record today
    const existing = await sbGet(
      env,
      `attendance_records?id=eq.${enc(recId)}&select=check_in_time,check_out_time&limit=1`
    );

    if (!existing.length) {
      // First punch of the day → check-in
      await sbPost(env, 'attendance_records', {
        id:             recId,
        employee_name:  employeeName,
        employee_id:    pinId,
        date,
        check_in_time:  time,
        check_out_time: '',
        location:       'Biometric device',
      });
      console.log(`ADMS: check-in ${employeeName} @ ${time}`);

    } else {
      const rec = existing[0];
      if (rec.check_in_time && !rec.check_out_time) {
        // Already checked in, no check-out → this punch is check-out
        await sbPatch(
          env,
          `attendance_records?id=eq.${enc(recId)}`,
          { check_out_time: time }
        );
        console.log(`ADMS: check-out ${employeeName} @ ${time}`);
      }
      // Both filled (resend) or neither filled: ignore
    }
  }
}

// ── Supabase REST API helpers ─────────────────────────────────────────────────

const enc = encodeURIComponent;

function sbHeaders(env) {
  return {
    apikey:        env.SUPABASE_KEY,
    Authorization: `Bearer ${env.SUPABASE_KEY}`,
    'Content-Type': 'application/json',
  };
}

async function sbGet(env, path) {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, {
    headers: sbHeaders(env),
  });
  return res.ok ? res.json() : [];
}

async function sbPost(env, table, body) {
  return fetch(`${env.SUPABASE_URL}/rest/v1/${table}`, {
    method:  'POST',
    headers: { ...sbHeaders(env), Prefer: 'return=minimal' },
    body:    JSON.stringify(body),
  });
}

async function sbPatch(env, path, body) {
  return fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, {
    method:  'PATCH',
    headers: { ...sbHeaders(env), Prefer: 'return=minimal' },
    body:    JSON.stringify(body),
  });
}
