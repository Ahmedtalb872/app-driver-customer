-- credit_wallet_from_bpay (20260910000095) credited the wallet directly
-- with no Selefli-debt-repayment step, unlike admin_approve_recharge
-- (20260812000055_selefli_credit.sql), which already auto-repays any
-- outstanding Selefli debt out of a recharge before leaving the rest as
-- free balance. That debt repayment is this wallet's whole current
-- real-world purpose - a customer topping up via the new live Bpay flow
-- with an outstanding debt would otherwise keep that debt stuck forever
-- (blocking further Selefli use) while the Bpay-credited money just sat
-- as ordinary balance, with no admin-review step left in this flow to
-- catch it the way a recharge_requests row would have.
create or replace function public.credit_wallet_from_bpay(
  p_user_id uuid,
  p_amount numeric,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
  v_debt public.selefli_debts;
  v_repay numeric;
begin
  select * into v_wallet from public.wallets where user_id = p_user_id for update;
  if not found then
    raise exception 'wallet_not_found';
  end if;

  v_before := v_wallet.balance;
  v_after := v_before + p_amount;

  update public.wallets set balance = v_after where id = v_wallet.id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, description
  ) values (
    v_wallet.id, p_user_id, 'recharge', p_amount, v_before, v_after,
    true, 'bpay', p_title
  );

  select * into v_debt from public.selefli_debts
    where customer_id = p_user_id and status = 'outstanding'
    order by created_at
    limit 1
    for update;

  if found and v_after > 0 then
    v_repay := least(v_after, v_debt.amount - v_debt.amount_paid);
    if v_repay > 0 then
      update public.selefli_debts
        set amount_paid = amount_paid + v_repay,
            status = case when amount_paid + v_repay >= amount then 'paid' else 'outstanding' end,
            paid_at = case when amount_paid + v_repay >= amount then now() else null end
        where id = v_debt.id;

      update public.wallets set balance = v_after - v_repay where id = v_wallet.id;
      insert into public.wallet_transactions (
        wallet_id, user_id, type, amount, balance_before, balance_after,
        is_credit, reference_type, reference_id, description
      ) values (
        v_wallet.id, p_user_id, 'payment', v_repay,
        v_after, v_after - v_repay,
        false, 'selefli_debt', v_debt.id, 'سداد دين سلفلي تلقائي'
      );
    end if;
  end if;
end;
$$;

revoke execute on function public.credit_wallet_from_bpay(uuid, numeric, text) from public, authenticated;
grant execute on function public.credit_wallet_from_bpay(uuid, numeric, text) to service_role;
