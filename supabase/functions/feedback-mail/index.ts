// Emails each new piece of player feedback to the team.
//
// A trigger on public.feedback (migration 0012) calls this with just the
// new row's id. The function claims the row with the service role (it
// stamps emailed_at only if it was still unsent), so a stray or repeated
// call can never send anything that isn't real, unsent feedback. That's
// why it runs without JWT verification.
//
// Secrets (Dashboard → Edge Functions → Secrets):
//   FEEDBACK_TO                       where feedback goes (defaults to GMAIL_USER)
// and one way to send:
//   GMAIL_USER + GMAIL_APP_PASSWORD   through Gmail (an app password, like Auth's SMTP)
//   RESEND_API_KEY                    through Resend

import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6";

// Kept out of the code: the repository is public.
const TO = Deno.env.get("FEEDBACK_TO") ?? Deno.env.get("GMAIL_USER");

type Feedback = {
  id: number;
  kind: "bug" | "idea" | "question";
  message: string;
  email: string | null;
  platform: string;
  context: Record<string, unknown>;
  player: Record<string, unknown>;
  created_at: string;
};

const KINDS = {
  bug: { icon: "🐞", label: "Problem report" },
  idea: { icon: "💡", label: "Feature idea" },
  question: { icon: "❓", label: "Question report" },
};

const PLATFORMS: Record<string, string> = { web: "Web", ios: "iOS", android: "Android" };

function escape(s: unknown) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

function compose(f: Feedback) {
  const kind = KINDS[f.kind] ?? KINDS.bug;
  const name = String(f.player.name ?? "A player");
  const subject = `[Apticks] ${kind.icon} ${kind.label} · ${PLATFORMS[f.platform] ?? f.platform} · ${name}`;
  const rows: [string, unknown][] = [
    ["From", `${name}${f.player.rating ? ` (${f.player.rating})` : ""}${f.player.college ? `, ${f.player.college}` : ""}`],
    ["Reply to", f.email ?? "not given"],
    ["Platform", PLATFORMS[f.platform] ?? f.platform],
    ...Object.entries(f.context),
    ["Sent", new Date(f.created_at).toUTCString()],
    ["Feedback #", f.id],
  ];
  const text = `${kind.label}\n\n${f.message}\n\n${rows.map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : v}`).join("\n")}`;
  const html = `
<div style="font-family:system-ui,sans-serif;max-width:560px;color:#0b0e17">
  <p style="font-size:13px;color:#667;margin:0 0 6px">${kind.icon} ${escape(kind.label)}</p>
  <div style="white-space:pre-wrap;font-size:16px;line-height:1.5;padding:16px;border-radius:12px;background:#f4f6fa;border:1px solid #e1e5ee">${escape(f.message)}</div>
  <table style="margin-top:16px;font-size:13px;border-collapse:collapse">
    ${rows.map(([k, v]) => `<tr><td style="padding:3px 14px 3px 0;color:#667;vertical-align:top">${escape(k)}</td><td style="padding:3px 0">${escape(typeof v === "object" ? JSON.stringify(v) : v)}</td></tr>`).join("")}
  </table>
</div>`;
  return { subject, text, html };
}

async function send(f: Feedback) {
  if (!TO) throw new Error("Set FEEDBACK_TO (or GMAIL_USER) to say where feedback goes");
  const { subject, text, html } = compose(f);
  const resend = Deno.env.get("RESEND_API_KEY");
  if (resend) {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resend}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: "Apticks Feedback <onboarding@resend.dev>",
        to: [TO],
        reply_to: f.email ?? undefined,
        subject,
        text,
        html,
      }),
    });
    if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
    return;
  }
  const user = Deno.env.get("GMAIL_USER");
  const pass = Deno.env.get("GMAIL_APP_PASSWORD");
  if (!user || !pass) throw new Error("No email secrets set: add GMAIL_USER and GMAIL_APP_PASSWORD, or RESEND_API_KEY");
  const mailer = nodemailer.createTransport({ host: "smtp.gmail.com", port: 465, secure: true, auth: { user, pass } });
  await mailer.sendMail({ from: `Apticks Feedback <${user}>`, to: TO, replyTo: f.email ?? undefined, subject, text, html });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  let id: number;
  try {
    id = Number((await req.json()).id);
  } catch {
    return new Response("Bad request", { status: 400 });
  }
  if (!Number.isInteger(id) || id <= 0) return new Response("Bad request", { status: 400 });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  // Claim it: only a row that hasn't been emailed yet.
  const { data, error } = await db
    .from("feedback")
    .update({ emailed_at: new Date().toISOString() })
    .eq("id", id)
    .is("emailed_at", null)
    .select()
    .maybeSingle();
  if (error) return new Response(error.message, { status: 500 });
  if (!data) return new Response("Nothing to send", { status: 200 });

  try {
    await send(data as Feedback);
    return new Response("Sent", { status: 200 });
  } catch (e) {
    // Leave it unsent so it can be retried, and say why in the logs.
    await db.from("feedback").update({ emailed_at: null }).eq("id", id);
    console.error("feedback-mail:", e);
    return new Response("Couldn't send", { status: 502 });
  }
});
