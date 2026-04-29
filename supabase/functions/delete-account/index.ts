// Edge Function: delete-account
//
// Deletes the signed-in user's account and all associated data.
// Required by App Store Review Guideline 5.1.1(v) — apps that support
// account creation must let users delete their account from inside the app.
//
// Auth user deletion requires the service-role key, which can never live
// in the iOS app — that's why this runs as an Edge Function.
//
// Deploy:
//   supabase functions deploy delete-account
//
// The function expects an Authorization: Bearer <user_jwt> header. Supabase
// passes this through automatically when the iOS client invokes it.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  // CORS preflight (harmless if called from iOS, needed if you ever call from web)
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing auth" }), { status: 401 });
  }

  // Verify the caller's JWT and pull their user id.
  const userClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: "invalid token" }), { status: 401 });
  }

  const userId = user.id;

  // Admin client — has service-role privileges. Use only inside this function.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Delete user-owned rows. Add tables here as you add them.
  // ON DELETE CASCADE on the FK to auth.users would handle this automatically;
  // we do it explicitly so a failure surfaces clearly instead of silently leaking.
  const tables: { name: string; column: string }[] = [
    { name: "venue_suggestions", column: "user_id" },
    { name: "outdated_reports",  column: "user_id" },
    { name: "venue_managers",    column: "user_id" },
  ];

  for (const t of tables) {
    const { error } = await admin.from(t.name).delete().eq(t.column, userId);
    if (error) {
      console.error("delete from", t.name, "failed:", error);
      return new Response(
        JSON.stringify({ error: `failed to delete ${t.name}: ${error.message}` }),
        { status: 500 },
      );
    }
  }

  // Finally delete the auth user.
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    console.error("auth.admin.deleteUser failed:", delErr);
    return new Response(
      JSON.stringify({ error: `failed to delete auth user: ${delErr.message}` }),
      { status: 500 },
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
