-- One-time provisioning of a real (non-demo) admin account, per the pattern
-- documented in 20260712000004_create_admin_users.sql: admin accounts are
-- not self-service, they're created by inserting directly into auth.users
-- with role = 'admin' metadata, which handle_new_user then turns into the
-- matching profiles/admin_users/wallets rows automatically.
--
-- Login: admin dashboard -> "كلمة المرور" (password) mode -> phone number
-- below as the identifier. AdminAuthService/AuthService.signIn map a plain
-- phone identifier to the same deterministic synthetic email
-- (`<digits>@hudhud.app`) this migration writes directly, so a phone-shaped
-- identifier "just works" without the caller ever seeing the email.
do $$
declare
  v_phone text := '+22220522064';
  v_password text := '20522064';
  v_email text := '22220522064@hudhud.app';
  v_user_id uuid;
begin
  if exists (select 1 from auth.users where email = v_email) then
    return;
  end if;

  v_user_id := gen_random_uuid();

  -- confirmed_at is a generated column (derived from email_confirmed_at/
  -- phone_confirmed_at) - it must not appear in this column list at all,
  -- Postgres rejects any explicit value for it on both insert and update.
  --
  -- confirmation_token/recovery_token/email_change*/phone_change*/
  -- reauthentication_token have no database-level default on this project,
  -- so leaving them out of the column list leaves them NULL - GoTrue's Go
  -- client scans them into a plain string and errors with "converting NULL
  -- to string is unsupported" on every login attempt for this user. They
  -- must be explicit empty strings, matching what a normal signup writes.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, phone, phone_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, is_sso_user, is_anonymous,
    confirmation_token, recovery_token, email_change_token_new,
    email_change, phone_change, phone_change_token,
    email_change_token_current, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    now(),
    v_phone,
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('role', 'admin', 'full_name', 'مدير الهدهد', 'phone', v_phone),
    false,
    false,
    false,
    '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(),
    v_user_id,
    v_user_id::text,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email',
    now(),
    now(),
    now()
  );

  -- handle_new_user already created the admin_users row (id only); fill in
  -- the sub-role so every admin-only screen/action is available immediately
  -- instead of only the ones that don't call has_admin_role().
  update public.admin_users
  set admin_role = 'super_admin', full_name = 'مدير الهدهد'
  where id = v_user_id;
end $$;
