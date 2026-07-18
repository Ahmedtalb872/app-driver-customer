// Provisions Hudhud's fixed demo accounts (customer/captain/admin) directly
// in Supabase Auth via the Admin API, mirroring exactly what
// AuthService.signUp() already does client-side (phone -> synthetic email,
// full_name/phone/role metadata) so the existing handle_new_user trigger
// creates the matching profiles/customers/captains/admin_users/wallets rows
// on its own - no parallel provisioning path.
//
// This is intentionally NOT run from the Flutter app: it needs the
// Supabase service-role key, which per docs/admin_web_deployment.md must
// never ship in the app or any client build. Run it manually, from a
// trusted machine, with the key only in your shell environment:
//
//   SUPABASE_URL=https://<project-ref>.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=<service-role-key> \
//   node scripts/seed_demo_accounts.mjs
//
// Safe to re-run: existing demo accounts are updated in place rather than
// duplicated.

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error(
    "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY environment variables.",
  );
  process.exit(1);
}

// Keep in sync with lib/core/config/demo_mode_config.dart.
const DEMO_ACCOUNTS = [
  {
    phone: "+22240000001",
    code: "111111",
    fullName: "زبون تجريبي",
    role: "customer",
  },
  {
    phone: "+22240000002",
    code: "222222",
    fullName: "كابتن تجريبي",
    role: "captain",
  },
  {
    phone: "+22240000003",
    code: "333333",
    fullName: "مدير تجريبي",
    role: "admin",
  },
];

function phoneToEmail(phone) {
  const digits = phone.replace(/[^0-9]/g, "");
  return `${digits}@hudhud.app`;
}

function internalPassword(phone, code) {
  const digits = phone.replace(/[^0-9]/g, "");
  return `hudhud_demo_${digits}_${code}_2026`;
}

const authHeaders = {
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

async function findUserByEmail(email) {
  const url = new URL(`${SUPABASE_URL}/auth/v1/admin/users`);
  url.searchParams.set("page", "1");
  url.searchParams.set("per_page", "200");
  const res = await fetch(url, { headers: authHeaders });
  if (!res.ok) {
    throw new Error(`List users failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json();
  return (body.users || []).find((u) => u.email === email) || null;
}

async function createUser({ email, phone, password, fullName, role }) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      email,
      phone,
      password,
      email_confirm: true,
      phone_confirm: true,
      user_metadata: { full_name: fullName, phone, role },
    }),
  });
  if (!res.ok) {
    throw new Error(`Create user failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function updateUser(id, { phone, password, fullName, role }) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${id}`, {
    method: "PUT",
    headers: authHeaders,
    body: JSON.stringify({
      phone,
      password,
      phone_confirm: true,
      user_metadata: { full_name: fullName, phone, role },
    }),
  });
  if (!res.ok) {
    throw new Error(`Update user failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function patchTable(table, id, patch) {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/${table}?id=eq.${id}`,
    {
      method: "PATCH",
      headers: { ...authHeaders, Prefer: "return=minimal" },
      body: JSON.stringify(patch),
    },
  );
  if (!res.ok) {
    throw new Error(
      `Patch ${table} failed: ${res.status} ${await res.text()}`,
    );
  }
}

async function main() {
  for (const account of DEMO_ACCOUNTS) {
    const email = phoneToEmail(account.phone);
    const password = internalPassword(account.phone, account.code);

    let user = await findUserByEmail(email);
    if (user) {
      console.log(`Updating existing ${account.role} demo user ${email}`);
      user = await updateUser(user.id, {
        phone: account.phone,
        password,
        fullName: account.fullName,
        role: account.role,
      });
    } else {
      console.log(`Creating ${account.role} demo user ${email}`);
      const created = await createUser({
        email,
        phone: account.phone,
        password,
        fullName: account.fullName,
        role: account.role,
      });
      user = created.user ?? created;
    }

    // handle_new_user() already inserted profiles/customers/captains/
    // admin_users/wallets rows for `user.id` - just flip the role-specific
    // flags the demo accounts need for testing.
    if (account.role === "captain") {
      await patchTable("captains", user.id, {
        status: "approved",
        is_online: true,
        vehicle_type: "economy",
      });
      console.log("  -> captains.status=approved, is_online=true");
    } else if (account.role === "admin") {
      await patchTable("admin_users", user.id, {
        admin_role: "super_admin",
        is_active: true,
        full_name: account.fullName,
      });
      console.log("  -> admin_users.admin_role=super_admin, is_active=true");
    }
  }

  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
