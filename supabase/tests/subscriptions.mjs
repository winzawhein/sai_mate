// Isolated PostgreSQL/PGlite test. Never connects to the live Supabase project.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const reviewer = '33333333-3333-4333-8333-333333333333';
const shop = '44444444-4444-4444-8444-444444444444';
const plan = '55555555-5555-4555-8555-555555555555';
const method = '66666666-6666-4666-8666-666666666666';
const payment = n => `77777777-7777-4777-8777-${String(n).padStart(12,'0')}`;
const migration = await readFile(new URL('../upgrade_v7_subscriptions.sql', import.meta.url), 'utf8');
await db.exec(`
 create role anon; create role authenticated;
 create schema auth; create schema storage;
 create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create table public.shops(id uuid primary key, owner_id uuid);
 create function public.is_shop_member(p_id uuid) returns boolean language sql stable security definer as $$ select exists(select 1 from public.shops where id=p_id and owner_id=auth.uid()) $$;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid default gen_random_uuid() primary key,bucket_id text,name text, unique(bucket_id,name));
 alter table storage.objects enable row level security;
 create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
 create function storage.extension(text) returns text language sql immutable as $$ select reverse(split_part(reverse($1),'.',1)) $$;
 grant usage on schema public,auth,storage to authenticated,anon;
 grant select on public.shops to authenticated;
 grant select,insert,update,delete on storage.objects to authenticated;
 insert into auth.users values('${owner}'),('${other}'),('${reviewer}');
 insert into public.shops values('${shop}','${owner}');
`);
await db.exec(migration);
await db.exec(migration); // Repeat application preserves objects and data.
await db.exec(`insert into public.billing_reviewers values('${reviewer}');
 insert into public.subscription_plans(id,name,price,duration_days) values('${plan}','Test plan',10000,30);
 insert into public.subscription_payment_methods(id,name,account_name,account_number) values('${method}','Test bank','Test recipient','TEST-ONLY');`);
async function asUser(id) {
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
 await db.exec('set role authenticated');
}
let checks = 0;
async function denied(fn, expected) {
 try { await fn(); assert.fail('Expected request to fail'); }
 catch(e) { assert.match(e.message, expected); checks++; }
}
async function upload(n) {
 await db.query('insert into storage.objects(bucket_id,name) values($1,$2)', ['subscription-slips',`${owner}/${payment(n)}.jpg`]);
}
async function submit(n, ref=`REF-${n}`, amount=10000) {
 return db.query('select public.submit_subscription_payment($1,$2,$3,$4,$5,now(),$6,$7,30,$8)',
  [payment(n),shop,plan,method,ref,`${owner}/${payment(n)}.jpg`,amount,'TEST-ONLY']);
}
await asUser(owner);
await denied(() => db.exec(`insert into public.billing_reviewers values('${owner}')`), /permission denied/);
await denied(() => db.exec(`update public.subscription_plans set price=1 where id='${plan}' returning id`).then(r => { assert.equal(r[0].rows.length,1); }), /0 !== 1/);
await denied(() => db.exec(`insert into storage.objects(bucket_id,name) values('subscription-slips','${other}/bad.jpg')`), /row-level security/);
await denied(() => submit(1), /Upload a payment slip first/);
await upload(1);
await submit(1);
await submit(1); // Network retry is idempotent.
assert.equal((await db.query('select * from public.subscription_payments')).rows.length,1); checks++;
await denied(() => db.exec(`update public.subscription_payments set status='approved'`), /permission denied/);
await denied(() => db.exec(`select public.review_subscription_payment('${payment(1)}',true,'')`), /Reviewer access required/);
await upload(2);
await denied(() => submit(2), /already awaiting review/);
await db.exec('delete from storage.objects');
assert.equal((await db.query('select * from storage.objects')).rows.length,2); checks++;
await asUser(other);
assert.equal((await db.query('select * from public.subscription_payments')).rows.length,0); checks++;
assert.equal((await db.query('select * from storage.objects')).rows.length,0); checks++;
await denied(() => submit(1), /Only the shop owner/);
await asUser(reviewer);
assert.equal((await db.query('select * from storage.objects')).rows.length,2); checks++;
await db.exec(`select public.review_subscription_payment('${payment(1)}',true,'Verified bank transfer')`);
const firstExpiry = (await db.query('select expires_at from public.shop_subscriptions')).rows[0].expires_at;
await denied(() => db.exec(`select public.review_subscription_payment('${payment(1)}',true,'Again')`), /already reviewed/);
await asUser(owner);
await denied(() => submit(2,'REF-1'), /unique constraint/);
await submit(2);
await asUser(reviewer);
await db.exec(`select public.review_subscription_payment('${payment(2)}',true,'Verified')`);
const secondExpiry = (await db.query('select expires_at from public.shop_subscriptions')).rows[0].expires_at;
assert.equal(new Date(secondExpiry)-new Date(firstExpiry),30*86400000); checks++;
await asUser(owner);
await upload(3);
await submit(3);
await asUser(reviewer);
await denied(() => db.exec(`select public.review_subscription_payment('${payment(3)}',false,'')`), /rejection reason/);
await db.exec(`select public.review_subscription_payment('${payment(3)}',false,'Amount did not arrive')`);
assert.equal(new Date((await db.query('select expires_at from public.shop_subscriptions')).rows[0].expires_at).getTime(),new Date(secondExpiry).getTime()); checks++;
await db.exec(`update public.subscription_plans set price=12000 where id='${plan}'`);
await asUser(owner);
await upload(4);
await denied(() => submit(4), /Payment details changed/);
await asUser(other);
assert.equal((await db.query('select * from public.shop_subscriptions')).rows.length,0); checks++;
console.log(`PASS: ${checks} subscription security and lifecycle checks; migration applies twice.`);
await db.close();
