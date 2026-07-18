-- Phase 2 seed data: Nouakchott districts, destination categories,
-- representative neighborhoods, and a representative set of public places.
--
-- This file is intentionally separate from supabase/migrations/ - it is
-- content, not schema, and is meant to be re-run safely at any time
-- (idempotent via ON CONFLICT on the unique/dedupe indexes created in
-- 20260712000015_destinations_indexes.sql).
--
-- Coordinates are approximate (rounded to 4 decimal places, ~11m) unless
-- noted otherwise - they are good enough to place a marker in the right
-- part of the city and to compute a reasonable district, but every row
-- listed here should be reviewed/corrected by an admin against a real
-- source (Google Maps / on-the-ground survey) before being fully trusted.
-- None of these places are marked is_verified = true purely because they
-- appear in this seed; is_verified reflects real-world confirmation and is
-- only set for well-known, unambiguous landmarks.

-- ---------------------------------------------------------------------
-- 1. Districts
-- ---------------------------------------------------------------------
insert into public.districts (name_ar, name_fr, code, latitude, longitude, map_zoom)
values
  ('تفرغ زينة', 'Tevragh Zeina', 'tevragh_zeina', 18.1103, -15.9683, 14),
  ('لكصر', 'Ksar', 'ksar', 18.0858, -15.9700, 14),
  ('السبخة', 'Sebkha', 'sebkha', 18.0781, -15.9819, 14),
  ('الميناء', 'El Mina', 'el_mina', 18.0631, -16.0122, 13),
  ('الرياض', 'Riadh', 'riadh', 18.0219, -15.9481, 13),
  ('عرفات', 'Arafat', 'arafat', 18.0393, -15.9560, 13),
  ('توجنين', 'Toujounine', 'toujounine', 18.1370, -15.9280, 13),
  ('دار النعيم', 'Dar Naim', 'dar_naim', 18.1263, -15.9075, 13),
  ('تيارت', 'Teyarett', 'teyarett', 18.0983, -15.9280, 13)
on conflict (code) do update
  set name_ar = excluded.name_ar,
      name_fr = excluded.name_fr,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      map_zoom = excluded.map_zoom;

-- ---------------------------------------------------------------------
-- 2. Destination categories
-- ---------------------------------------------------------------------
insert into public.place_categories (code, name_ar, name_fr, icon_name, sort_order)
values
  ('restaurants', 'مطاعم', 'Restaurants', 'restaurant', 10),
  ('cafes', 'مقاهي', 'Cafés', 'local_cafe', 20),
  ('hospitals', 'مستشفيات', 'Hôpitaux', 'local_hospital', 30),
  ('clinics', 'عيادات', 'Cliniques', 'medical_services', 40),
  ('pharmacies', 'صيدليات', 'Pharmacies', 'local_pharmacy', 50),
  ('markets', 'أسواق', 'Marchés', 'storefront', 60),
  ('shops', 'محلات تجارية', 'Commerces', 'shopping_bag', 70),
  ('universities', 'جامعات', 'Universités', 'account_balance', 80),
  ('schools', 'مدارس', 'Écoles', 'school', 90),
  ('mosques', 'مساجد', 'Mosquées', 'mosque', 100),
  ('hotels', 'فنادق', 'Hôtels', 'hotel', 110),
  ('government', 'إدارات حكومية', 'Administrations', 'apartment', 120),
  ('neighborhoods', 'أحياء', 'Quartiers', 'location_city', 130),
  ('streets', 'شوارع', 'Rues', 'route', 140),
  ('landmarks', 'معالم مشهورة', 'Sites connus', 'tour', 150),
  ('airport', 'مطار', 'Aéroport', 'flight', 160),
  ('port', 'ميناء', 'Port', 'directions_boat', 170),
  ('other', 'أخرى', 'Autre', 'more_horiz', 180)
on conflict (code) do update
  set name_ar = excluded.name_ar,
      name_fr = excluded.name_fr,
      icon_name = excluded.icon_name,
      sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------
-- 3. Representative neighborhoods (2 per district)
-- ---------------------------------------------------------------------
insert into public.neighborhoods (district_id, name_ar, name_fr, latitude, longitude)
select d.id, v.name_ar, v.name_fr, v.latitude, v.longitude
from (values
  ('tevragh_zeina', 'تفرغ زينة الشمالية', 'Tevragh Zeina Nord', 18.1150, -15.9700),
  ('tevragh_zeina', 'تفرغ زينة الجنوبية', 'Tevragh Zeina Sud', 18.1050, -15.9660),
  ('ksar', 'لكصر القديم', 'Vieux Ksar', 18.0870, -15.9720),
  ('ksar', 'لكصر الجديد', 'Ksar Nouveau', 18.0840, -15.9680),
  ('sebkha', 'السبخة الشمالية', 'Sebkha Nord', 18.0800, -15.9830),
  ('sebkha', 'السبخة الجنوبية', 'Sebkha Sud', 18.0760, -15.9805),
  ('el_mina', 'الميناء الشمالي', 'El Mina Nord', 18.0660, -16.0100),
  ('el_mina', 'الميناء الجنوبي', 'El Mina Sud', 18.0600, -16.0150),
  ('riadh', 'الرياض 1', 'Riadh 1', 18.0240, -15.9500),
  ('riadh', 'الرياض 2', 'Riadh 2', 18.0195, -15.9460),
  ('arafat', 'عرفات 1', 'Arafat 1', 18.0410, -15.9580),
  ('arafat', 'عرفات 2', 'Arafat 2', 18.0370, -15.9540),
  ('toujounine', 'توجنين 1', 'Toujounine 1', 18.1400, -15.9310),
  ('toujounine', 'توجنين 2', 'Toujounine 2', 18.1340, -15.9250),
  ('dar_naim', 'دار النعيم 1', 'Dar Naim 1', 18.1290, -15.9100),
  ('dar_naim', 'دار النعيم 2', 'Dar Naim 2', 18.1235, -15.9050),
  ('teyarett', 'تيارت 1', 'Teyarett 1', 18.1010, -15.9300),
  ('teyarett', 'تيارت 2', 'Teyarett 2', 18.0955, -15.9260)
) as v(district_code, name_ar, name_fr, latitude, longitude)
join public.districts d on d.code = v.district_code
on conflict (district_id, lower(btrim(name_ar))) do nothing;

-- ---------------------------------------------------------------------
-- 4. Representative places, grouped by district and category
-- ---------------------------------------------------------------------
insert into public.places (
  district_id, category_id, name_ar, name_fr, address_ar, latitude, longitude,
  is_popular, is_verified
)
select d.id, c.id, v.name_ar, v.name_fr, v.address_ar, v.latitude, v.longitude,
       v.is_popular, v.is_verified
from (values
  -- تفرغ زينة
  ('tevragh_zeina', 'hospitals', 'مستشفى الشيخ زايد', 'Hôpital Cheikh Zayed', 'تفرغ زينة، نواكشوط', 18.1088, -15.9679, true, true),
  ('tevragh_zeina', 'mosques', 'الجامع الكبير (المسجد السعودي)', 'Grande Mosquée Saoudienne', 'تفرغ زينة، نواكشوط', 18.1049, -15.9698, true, true),
  ('tevragh_zeina', 'hotels', 'فندق أزاليه مرحبا', 'Azalaï Hôtel Marhaba', 'تفرغ زينة، نواكشوط', 18.1071, -15.9648, true, true),
  ('tevragh_zeina', 'cafes', 'مقهى تفرغ زينة', 'Café Tevragh Zeina', 'تفرغ زينة، نواكشوط', 18.1112, -15.9701, false, false),
  ('tevragh_zeina', 'restaurants', 'مطعم البركة', 'Restaurant El Baraka', 'تفرغ زينة، نواكشوط', 18.1121, -15.9655, false, false),
  ('tevragh_zeina', 'government', 'القصر الرئاسي', 'Palais Présidentiel', 'تفرغ زينة، نواكشوط', 18.1180, -15.9720, true, true),
  ('tevragh_zeina', 'neighborhoods', 'حي تفرغ زينة', 'Quartier Tevragh Zeina', 'تفرغ زينة، نواكشوط', 18.1103, -15.9683, true, false),

  -- لكصر
  ('ksar', 'markets', 'السوق المركزي (السوق الكبير)', 'Marché Capitale', 'لكصر، نواكشوط', 18.0844, -15.9721, true, true),
  ('ksar', 'hospitals', 'المستشفى الوطني', 'Centre Hospitalier National', 'لكصر، نواكشوط', 18.0825, -15.9678, true, true),
  ('ksar', 'universities', 'جامعة نواكشوط العصرية', 'Université de Nouakchott Al Aasriya', 'لكصر، نواكشوط', 18.0870, -15.9650, true, true),
  ('ksar', 'government', 'الوزارة الأولى', 'Primature', 'لكصر، نواكشوط', 18.0860, -15.9715, false, true),
  ('ksar', 'landmarks', 'ساحة الاستقلال', 'Place de l''Indépendance', 'لكصر، نواكشوط', 18.0851, -15.9706, true, false),
  ('ksar', 'pharmacies', 'صيدلية لكصر المركزية', 'Pharmacie Centrale du Ksar', 'لكصر، نواكشوط', 18.0839, -15.9695, false, false),
  ('ksar', 'streets', 'شارع جمال عبد الناصر', 'Avenue Gamal Abdel Nasser', 'لكصر، نواكشوط', 18.0862, -15.9690, false, false),

  -- السبخة
  ('sebkha', 'markets', 'سوق السبخة الشعبي', 'Marché Populaire de Sebkha', 'السبخة، نواكشوط', 18.0772, -15.9835, true, false),
  ('sebkha', 'schools', 'مدرسة السبخة الابتدائية', 'École Primaire de Sebkha', 'السبخة، نواكشوط', 18.0790, -15.9810, false, false),
  ('sebkha', 'mosques', 'مسجد السبخة الكبير', 'Grande Mosquée de Sebkha', 'السبخة، نواكشوط', 18.0765, -15.9822, false, false),
  ('sebkha', 'clinics', 'عيادة السبخة الطبية', 'Clinique de Sebkha', 'السبخة، نواكشوط', 18.0778, -15.9805, false, false),
  ('sebkha', 'other', 'نقطة مرجعية - السبخة', 'Repère - Sebkha', 'السبخة، نواكشوط', 18.0781, -15.9819, false, false),

  -- الميناء
  ('el_mina', 'port', 'الميناء المستقل (ميناء الصداقة)', 'Port Autonome de Nouakchott (Port de l''Amitié)', 'الميناء، نواكشوط', 18.0459, -16.0301, true, true),
  ('el_mina', 'markets', 'سوق الميناء', 'Marché d''El Mina', 'الميناء، نواكشوط', 18.0640, -16.0110, false, false),
  ('el_mina', 'mosques', 'مسجد الميناء', 'Mosquée d''El Mina', 'الميناء، نواكشوط', 18.0625, -16.0130, false, false),
  ('el_mina', 'schools', 'ثانوية الميناء', 'Lycée d''El Mina', 'الميناء، نواكشوط', 18.0650, -16.0095, false, false),

  -- الرياض
  ('riadh', 'hospitals', 'مستشفى الرياض', 'Hôpital de Riadh', 'الرياض، نواكشوط', 18.0230, -15.9470, false, false),
  ('riadh', 'mosques', 'مسجد الرياض الكبير', 'Grande Mosquée de Riadh', 'الرياض، نواكشوط', 18.0205, -15.9495, false, false),
  ('riadh', 'shops', 'مركز الرياض التجاري', 'Centre Commercial Riadh', 'الرياض، نواكشوط', 18.0240, -15.9460, false, false),
  ('riadh', 'schools', 'مدرسة الرياض', 'École de Riadh', 'الرياض، نواكشوط', 18.0215, -15.9505, false, false),

  -- عرفات
  ('arafat', 'markets', 'سوق عرفات', 'Marché d''Arafat', 'عرفات، نواكشوط', 18.0405, -15.9548, true, false),
  ('arafat', 'clinics', 'عيادة عرفات', 'Clinique d''Arafat', 'عرفات، نواكشوط', 18.0380, -15.9575, false, false),
  ('arafat', 'mosques', 'مسجد عرفات', 'Mosquée d''Arafat', 'عرفات، نواكشوط', 18.0399, -15.9552, false, false),
  ('arafat', 'restaurants', 'مطعم عرفات الشعبي', 'Restaurant Populaire d''Arafat', 'عرفات، نواكشوط', 18.0388, -15.9568, false, false),

  -- توجنين
  ('toujounine', 'airport', 'مطار نواكشوط أم تونسي الدولي', 'Aéroport International Nouakchott-Oumtounsy', 'توجنين، نواكشوط', 18.1785, -15.8763, true, true),
  ('toujounine', 'schools', 'ثانوية توجنين', 'Lycée de Toujounine', 'توجنين، نواكشوط', 18.1360, -15.9300, false, false),
  ('toujounine', 'mosques', 'مسجد توجنين الكبير', 'Grande Mosquée de Toujounine', 'توجنين، نواكشوط', 18.1345, -15.9265, false, false),
  ('toujounine', 'markets', 'سوق توجنين', 'Marché de Toujounine', 'توجنين، نواكشوط', 18.1380, -15.9250, false, false),

  -- دار النعيم
  ('dar_naim', 'hospitals', 'مركز دار النعيم الصحي', 'Centre de Santé de Dar Naim', 'دار النعيم، نواكشوط', 18.1250, -15.9090, false, false),
  ('dar_naim', 'schools', 'مدرسة دار النعيم', 'École de Dar Naim', 'دار النعيم، نواكشوط', 18.1275, -15.9060, false, false),
  ('dar_naim', 'mosques', 'مسجد دار النعيم', 'Mosquée de Dar Naim', 'دار النعيم، نواكشوط', 18.1258, -15.9082, false, false),
  ('dar_naim', 'markets', 'سوق دار النعيم الشعبي', 'Marché Populaire de Dar Naim', 'دار النعيم، نواكشوط', 18.1270, -15.9050, false, false),

  -- تيارت
  ('teyarett', 'universities', 'المعهد العالي للمحاسبة وإدارة المقاولات', 'Institut Supérieur de Comptabilité', 'تيارت، نواكشوط', 18.0995, -15.9265, false, true),
  ('teyarett', 'mosques', 'مسجد تيارت', 'Mosquée de Teyarett', 'تيارت، نواكشوط', 18.0970, -15.9295, false, false),
  ('teyarett', 'schools', 'ثانوية تيارت', 'Lycée de Teyarett', 'تيارت، نواكشوط', 18.1000, -15.9250, false, false),
  ('teyarett', 'shops', 'محلات تيارت التجارية', 'Commerces de Teyarett', 'تيارت، نواكشوط', 18.0978, -15.9310, false, false)
) as v(
  district_code, category_code, name_ar, name_fr, address_ar, latitude, longitude,
  is_popular, is_verified
)
join public.districts d on d.code = v.district_code
join public.place_categories c on c.code = v.category_code
on conflict (district_id, lower(btrim(name_ar)), round(latitude::numeric, 4), round(longitude::numeric, 4))
do nothing;
