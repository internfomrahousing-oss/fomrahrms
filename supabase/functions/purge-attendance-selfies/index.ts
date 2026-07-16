// Daily retention sweep for attendance selfies. Deletes any check-in/
// check-out selfie older than 30 days from the private `attendance-selfies`
// storage bucket and clears the corresponding path columns on
// attendance_records. Deleting storage objects has to go through the
// Storage API (not a plain SQL delete on storage.objects), which is why
// this lives in an Edge Function rather than a pure-SQL cron job — see
// supabase/migrations/20260716020000_attendance_selfies.sql for how it's
// scheduled (pg_cron + pg_net, calling this function once a day) and for
// the one-time manual setup steps.
//
// Runs as service_role, so it bypasses the storage RLS policies that
// otherwise restrict reads to HR/Management and uploads to the owning
// employee — this function is the one thing allowed to delete selfies.
//
// Required secrets (set with `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const RETENTION_DAYS = 30;
const BUCKET = "attendance-selfies";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  // Only the scheduled cron call (bearer = service role key) should ever
  // reach this — no CORS/browser access is expected or allowed.
  try {
    const cutoff = new Date(
      Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000,
    ).toISOString();

    const { data: rows, error: selectError } = await supabase
      .from("attendance_records")
      .select("id, check_in_selfie_path, check_out_selfie_path")
      .lt("created_at", cutoff)
      .or("check_in_selfie_path.neq.,check_out_selfie_path.neq.");

    if (selectError) {
      console.error("select failed", selectError);
      return json({ error: selectError.message }, 500);
    }
    if (!rows || rows.length === 0) {
      return json({ purged: 0 });
    }

    const paths: string[] = [];
    const ids: string[] = [];
    for (const row of rows) {
      if (row.check_in_selfie_path) paths.push(row.check_in_selfie_path);
      if (row.check_out_selfie_path) paths.push(row.check_out_selfie_path);
      ids.push(row.id as string);
    }

    if (paths.length > 0) {
      const { error: removeError } = await supabase.storage
        .from(BUCKET)
        .remove(paths);
      // Keep going even if some objects were already gone — we still want
      // to clear the columns so the UI stops pointing at dead paths.
      if (removeError) console.error("storage remove failed", removeError);
    }

    const { error: updateError } = await supabase
      .from("attendance_records")
      .update({ check_in_selfie_path: "", check_out_selfie_path: "" })
      .in("id", ids);
    if (updateError) {
      console.error("column clear failed", updateError);
      return json({ error: updateError.message }, 500);
    }

    return json({ purged: ids.length });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
