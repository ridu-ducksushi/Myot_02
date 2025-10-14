-- =========================================
-- PetCare Supabase 설정 스크립트 (최종 수정 버전 + 물품 기록 기능)
-- =========================================

-- =========================================
-- 0) 기본 테이블 (이미 있으면 건너뜀)
-- =========================================
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  display_name text,
  created_at timestamptz default now()
);

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  species text,
  breed text,
  sex text,
  neutered boolean,
  birth_date date,
  blood_type text,
  weight_kg numeric,
  avatar_url text,
  default_icon text,
  note text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 기존 pets 테이블에 물품 기록 관련 컬럼 추가 (이력형 pet_supplies 테이블은 별도 관리)
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS supplies_food TEXT; -- 유지(프로필의 요약 표시용)
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS supplies_supplement TEXT;
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS supplies_snack TEXT;
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS supplies_litter TEXT;
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS supplies_last_updated TIMESTAMPTZ;

-- 기존 pets 테이블에 프로필 배경색 컬럼 추가
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS profile_bg_color TEXT;

create table if not exists public.records (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  type text not null,
  title text,
  content text,
  value jsonb,
  at timestamptz not null default now(),
  files jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.labs (
  id uuid primary key default gen_random_uuid(),
  pet_id text not null,
  panel text not null,
  items jsonb not null default '{}'::jsonb,
  measured_at timestamptz not null default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  type text not null,
  title text,
  note text,
  scheduled_at timestamptz not null,
  repeat_rule text,
  done boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.lab_refs (
  id bigserial primary key,
  species text not null,
  panel text not null,
  item text not null,
  unit text,
  ref_min numeric,
  ref_max numeric
);

create table if not exists public.default_icons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon_data text not null,
  color text not null,
  category text,
  is_active boolean default true,
  sort_order integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =========================================
-- 1) RLS 활성화
-- =========================================
alter table public.users enable row level security;
alter table public.pets enable row level security;
alter table public.records enable row level security;
alter table public.labs enable row level security;
alter table public.reminders enable row level security;
alter table public.default_icons enable row level security;
alter table public.lab_refs enable row level security;

-- =========================================
-- 2) RLS 정책 설정
-- =========================================
-- users
drop policy if exists "users self" on public.users;
create policy "users self" on public.users for select using (id = auth.uid());
drop policy if exists "users insert self" on public.users;
create policy "users insert self" on public.users for insert with check (id = auth.uid());
drop policy if exists "users update self" on public.users;
create policy "users update self" on public.users for update using (id = auth.uid());

-- pets
drop policy if exists "owner can read" on public.pets;
create policy "owner can read" on public.pets for select using (owner_id = auth.uid());
drop policy if exists "owner can write" on public.pets;
create policy "owner can write" on public.pets for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- records
drop policy if exists "owner can read rec" on public.records;
create policy "owner can read rec" on public.records for select using (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
);
drop policy if exists "owner can write rec" on public.records;
create policy "owner can write rec" on public.records for all using (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
) with check (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
);

-- reminders
drop policy if exists "owner can read reminders" on public.reminders;
create policy "owner can read reminders" on public.reminders for select using (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
);
drop policy if exists "owner can write reminders" on public.reminders;
create policy "owner can write reminders" on public.reminders for all using (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
) with check (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
);

-- default_icons
drop policy if exists "Anyone can read default icons" on public.default_icons;
create policy "Anyone can read default icons" on public.default_icons for select using (true);

-- lab_refs
drop policy if exists "Anyone can read lab references" on public.lab_refs;
create policy "Anyone can read lab references" on public.lab_refs for select using (true);

-- =========================================
-- 3) labs 테이블 설정
-- =========================================
begin;

-- labs 정책 제거
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'labs'
  loop
    execute format('drop policy if exists %I on public.labs', pol.policyname);
  end loop;
end $$;

-- FK 제거
do $$
declare
  fk_name text;
begin
  select c.conname into fk_name
  from pg_constraint c
  join pg_class t on c.conrelid = t.oid
  where t.relname = 'labs'
    and c.contype = 'f'
    and c.conname like '%pet_id%fkey%'
  limit 1;

  if fk_name is not null then
    execute format('alter table public.labs drop constraint %I', fk_name);
  end if;
end $$;

-- pet_id 타입 변경
alter table public.labs alter column pet_id type text using pet_id::text;

-- 보조 컬럼 추가
alter table public.labs
  add column if not exists user_id uuid,
  add column if not exists date date,
  add column if not exists hospital_name text,
  add column if not exists cost text,
  alter column items set default '{}'::jsonb;

-- 데이터 백필
update public.labs l
set user_id = p.owner_id
from public.pets p
where p.id::text = l.pet_id
  and l.user_id is null;

update public.labs
set date = coalesce(date(measured_at), current_date)
where date is null;

-- not null 설정
alter table public.labs
  alter column user_id set not null,
  alter column date set not null,
  alter column items set not null;

-- PK 재정의
alter table public.labs drop constraint if exists labs_pkey;
alter table public.labs add primary key (user_id, pet_id, date);

-- 보안 강화된 함수 생성
create or replace function public.set_updated_at()
returns trigger 
language plpgsql 
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 트리거 재생성
drop trigger if exists labs_set_updated_at on public.labs;
create trigger labs_set_updated_at
before update on public.labs
for each row execute function public.set_updated_at();

-- labs 정책 재생성
create policy labs_select_own on public.labs for select using (auth.uid() = user_id);
create policy labs_insert_own on public.labs for insert with check (auth.uid() = user_id);
create policy labs_update_own on public.labs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy labs_owner_can_read_by_pet_owner on public.labs for select using (
  exists (
    select 1 from public.pets p
    where p.id::text = public.labs.pet_id
      and p.owner_id = auth.uid()
  )
);

create policy labs_owner_can_write_by_pet_owner on public.labs for all using (
  exists (
    select 1 from public.pets p
    where p.id::text = public.labs.pet_id
      and p.owner_id = auth.uid()
  )
) with check (
  exists (
    select 1 from public.pets p
    where p.id::text = public.labs.pet_id
      and p.owner_id = auth.uid()
  )
);

commit;

-- =========================================
-- 4) Storage 설정
-- =========================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true), ('profile_icons', 'profile_icons', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  -- avatars 정책
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can upload their own avatar') THEN
    CREATE POLICY "Users can upload their own avatar" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can update their own avatar') THEN
    CREATE POLICY "Users can update their own avatar" ON storage.objects
    FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can delete their own avatar') THEN
    CREATE POLICY "Users can delete their own avatar" ON storage.objects
    FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Avatar images are publicly accessible') THEN
    CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');
  END IF;

  -- profile_icons 정책
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Profile icons are publicly accessible') THEN
    CREATE POLICY "Profile icons are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile_icons');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Anyone can list profile icons') THEN
    CREATE POLICY "Anyone can list profile icons" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile_icons');
  END IF;
END $$;

-- =========================================
-- 5) 데이터 설정
-- =========================================
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS default_icon TEXT;

DELETE FROM public.default_icons;

INSERT INTO public.default_icons (name, icon_data, color, category, sort_order) VALUES
('강아지 1', 'pets', '#8B4513', 'dog', 1),
('강아지 2', 'pets_outlined', '#CD853F', 'dog', 2),
('고양이 1', 'cruelty_free', '#696969', 'cat', 3),
('고양이 2', 'cruelty_free_outlined', '#A9A9A9', 'cat', 4),
('토끼', 'cruelty_free', '#FFB6C1', 'other', 5),
('새', 'flight', '#87CEEB', 'other', 6),
('물고기', 'water_drop', '#4169E1', 'other', 7),
('햄스터', 'circle', '#DEB887', 'other', 8),
('거북이', 'circle_outlined', '#9ACD32', 'other', 9),
('하트', 'favorite', '#FF69B4', 'other', 10);

-- =========================================
-- 6) 물품 기록 관련 설정
-- =========================================
-- pet_supplies 이력 테이블 (일자별 5항목: 건사료/습식사료/영양제/간식/모래)
create table if not exists public.pet_supplies (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  dry_food text,
  wet_food text,
  supplement text,
  snack text,
  litter text,
  recorded_at timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.pet_supplies enable row level security;

drop policy if exists "owner can read supplies" on public.pet_supplies;
create policy "owner can read supplies" on public.pet_supplies for select using (
  exists (select 1 from public.pets p where p.id = pet_supplies.pet_id and p.owner_id = auth.uid())
);

drop policy if exists "owner can write supplies" on public.pet_supplies;
create policy "owner can write supplies" on public.pet_supplies for all using (
  exists (select 1 from public.pets p where p.id = pet_supplies.pet_id and p.owner_id = auth.uid())
) with check (
  exists (select 1 from public.pets p where p.id = pet_supplies.pet_id and p.owner_id = auth.uid())
);

create index if not exists idx_pet_supplies_pet_id on public.pet_supplies(pet_id);
create index if not exists idx_pet_supplies_recorded_at on public.pet_supplies(recorded_at);
-- 물품 관련 컬럼에 대한 코멘트 추가
COMMENT ON COLUMN public.pets.supplies_food IS '펫의 건사료 정보(요약)';
COMMENT ON COLUMN public.pets.supplies_supplement IS '펫의 영양제 정보';
COMMENT ON COLUMN public.pets.supplies_snack IS '펫의 간식 정보';
COMMENT ON COLUMN public.pets.supplies_litter IS '펫의 모래 정보';
COMMENT ON COLUMN public.pets.supplies_last_updated IS '물품 정보 마지막 업데이트 시간';

-- 물품 기록 관련 인덱스 생성 (성능 최적화)
CREATE INDEX IF NOT EXISTS idx_pets_supplies_last_updated ON public.pets(supplies_last_updated);
CREATE INDEX IF NOT EXISTS idx_pets_supplies_food ON public.pets(supplies_food) WHERE supplies_food IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pets_supplies_supplement ON public.pets(supplies_supplement) WHERE supplies_supplement IS NOT NULL;

-- =========================================
-- 7) 인덱스 생성
-- =========================================
CREATE INDEX IF NOT EXISTS idx_pets_owner_id ON public.pets(owner_id);
CREATE INDEX IF NOT EXISTS idx_records_pet_id ON public.records(pet_id);
CREATE INDEX IF NOT EXISTS idx_reminders_pet_id ON public.reminders(pet_id);
CREATE INDEX IF NOT EXISTS idx_labs_pet_id ON public.labs(pet_id);
CREATE INDEX IF NOT EXISTS idx_default_icons_category ON public.default_icons(category);
CREATE INDEX IF NOT EXISTS idx_default_icons_active ON public.default_icons(is_active);

-- =========================================
-- 8) 업데이트 트리거 설정
-- =========================================
-- pets 테이블 업데이트 트리거 생성
CREATE OR REPLACE FUNCTION public.set_pets_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- pets 테이블 업데이트 트리거 적용
DROP TRIGGER IF EXISTS set_pets_updated_at ON public.pets;
CREATE TRIGGER set_pets_updated_at
  BEFORE UPDATE ON public.pets
  FOR EACH ROW
  EXECUTE FUNCTION public.set_pets_updated_at();

-- =========================================
-- 9) 완료 메시지
-- =========================================
DO $$
BEGIN
  RAISE NOTICE 'PetCare Supabase 설정이 완료되었습니다!';
  RAISE NOTICE '- 기본 테이블 생성 완료';
  RAISE NOTICE '- RLS 정책 설정 완료';
  RAISE NOTICE '- Storage 설정 완료';
  RAISE NOTICE '- 물품 기록 기능 추가 완료';
  RAISE NOTICE '- 인덱스 및 트리거 설정 완료';
END $$;
