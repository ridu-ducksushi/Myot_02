-- =========================================
-- PetCare Supabase 설정 스크립트 (최종 수정 버전)
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
  default_icon text,  -- 추가: 기본 아이콘 필드
  note text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.records (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  type text not null,     -- meal|snack|litter|med|vaccine|visit|weight|other
  title text,
  content text,
  value jsonb,
  at timestamptz not null default now(),
  files jsonb,            -- array-like: [{url,kind,thumbUrl}]
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- labs: pet_id는 text(앱의 문자열 ID와 호환), panel/measured_at은 유지
create table if not exists public.labs (
  id uuid primary key default gen_random_uuid(),
  pet_id text not null,                 -- 중요: uuid → text
  panel text not null,                  -- CBC|Biochemistry
  items jsonb not null default '{}'::jsonb,
  measured_at timestamptz not null default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()  -- 추가: updated_at 컬럼
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  type text not null,     -- med|vaccine|visit|diet|litter|other
  title text,
  note text,
  scheduled_at timestamptz not null,
  repeat_rule text,       -- RRULE or simple pattern
  done boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.lab_refs (
  id bigserial primary key,
  species text not null,      -- cat/dog
  panel text not null,        -- CBC/Biochemistry
  item text not null,         -- RBC/HGB/...
  unit text,
  ref_min numeric,
  ref_max numeric
);

-- =========================================
-- 기본 아이콘 테이블 추가
-- =========================================
create table if not exists public.default_icons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon_data text not null,     -- Material Icons 이름
  color text not null,         -- HEX 색상 코드
  category text,               -- 'dog', 'cat', 'other' 등
  is_active boolean default true,
  sort_order integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =========================================
-- 1) RLS 활성화 (이미 활성화면 유지)
-- =========================================
alter table public.users enable row level security;
alter table public.pets enable row level security;
alter table public.records enable row level security;
alter table public.labs enable row level security;
alter table public.reminders enable row level security;
alter table public.default_icons enable row level security;

-- =========================================
-- 2) 기본 정책 (중복 방지 위해 드롭 후 생성)
-- =========================================
-- users
drop policy if exists "users self" on public.users;
create policy "users self"
on public.users for select using (id = auth.uid());

drop policy if exists "users insert self" on public.users;
create policy "users insert self"
on public.users for insert with check (id = auth.uid());

drop policy if exists "users update self" on public.users;
create policy "users update self"
on public.users for update using (id = auth.uid());

-- pets
drop policy if exists "owner can read" on public.pets;
create policy "owner can read"
on public.pets for select using (owner_id = auth.uid());

drop policy if exists "owner can write" on public.pets;
create policy "owner can write"
on public.pets for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- records
drop policy if exists "owner can read rec" on public.records;
create policy "owner can read rec"
on public.records for select using (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
);

drop policy if exists "owner can write rec" on public.records;
create policy "owner can write rec"
on public.records for all using (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
) with check (
  exists (select 1 from public.pets p where p.id = records.pet_id and p.owner_id = auth.uid())
);

-- reminders
drop policy if exists "owner can read reminders" on public.reminders;
create policy "owner can read reminders"
on public.reminders for select using (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
);

drop policy if exists "owner can write reminders" on public.reminders;
create policy "owner can write reminders"
on public.reminders for all using (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
) with check (
  exists (select 1 from public.pets p where p.id = reminders.pet_id and p.owner_id = auth.uid())
);

-- default_icons (모든 사용자가 읽기 가능)
drop policy if exists "Anyone can read default icons" on public.default_icons;
create policy "Anyone can read default icons"
on public.default_icons for select using (true);

-- =========================================
-- 3) labs 스키마 정렬 (정책 → FK → 타입 → 보조컬럼 → PK/RLS 재생성)
-- =========================================
begin;

-- 3-1) labs의 모든 정책을 먼저 제거 (pet_id 참조 의존성 해제)
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

-- 3-2) labs.pet_id에 걸린 FK가 있으면 제거
do $$
declare
  fk_name text;
begin
  select c.conname
    into fk_name
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

-- 3-3) pet_id 타입을 text로 강제 (기존 uuid → text)
alter table public.labs
  alter column pet_id type text using pet_id::text;

-- 3-4) 보조 컬럼/기본값 정리
alter table public.labs
  add column if not exists user_id uuid,
  add column if not exists date date,
  add column if not exists hospital_name text,                    -- 추가: 병원명 컬럼
  add column if not exists cost text,                             -- 추가: 비용 컬럼
  alter column items set default '{}'::jsonb;

-- 3-5) 기존 데이터 백필 (pets.id(uuid) → text 비교)
update public.labs l
set user_id = p.owner_id
from public.pets p
where p.id::text = l.pet_id
  and l.user_id is null;

-- measured_at(타임스탬프) → date 저장
update public.labs
set date = coalesce(date(measured_at), current_date)
where date is null;

-- 3-6) not null 보장
alter table public.labs
  alter column user_id set not null,
  alter column date set not null,
  alter column items set not null;

-- 3-7) PK 재정의: (user_id, pet_id, date)
alter table public.labs
  drop constraint if exists labs_pkey;
alter table public.labs
  add primary key (user_id, pet_id, date);

-- 3-8) updated_at 트리거 재설정
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists labs_set_updated_at on public.labs;
create trigger labs_set_updated_at
before update on public.labs
for each row execute function public.set_updated_at();

-- 3-9) RLS 활성화 유지
alter table public.labs enable row level security;

-- 3-10) labs 정책 재생성
-- (A) 앱 최종 사용: user_id 직접 매칭
create policy labs_select_own
on public.labs for select
using (auth.uid() = user_id);

create policy labs_insert_own
on public.labs for insert
with check (auth.uid() = user_id);

create policy labs_update_own
on public.labs for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- (B) 보조 정책(선택): pet.owner_id 기반. 타입 캐스팅 명시
create policy labs_owner_can_read_by_pet_owner
on public.labs for select using (
  exists (
    select 1 from public.pets p
    where p.id::text = public.labs.pet_id
      and p.owner_id = auth.uid()
  )
);

create policy labs_owner_can_write_by_pet_owner
on public.labs for all using (
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
-- 4) Storage bucket 생성 및 정책 설정
-- =========================================
-- Storage bucket 생성 (중복 방지)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('profile_icons', 'profile_icons', true)
ON CONFLICT (id) DO NOTHING;

-- RLS 정책 설정 (중복 방지)
DO $$
BEGIN
  -- avatars bucket 정책
  -- 업로드 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can upload their own avatar'
  ) THEN
    CREATE POLICY "Users can upload their own avatar" ON storage.objects
    FOR INSERT WITH CHECK (
      bucket_id = 'avatars' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;

  -- 업데이트 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can update their own avatar'
  ) THEN
    CREATE POLICY "Users can update their own avatar" ON storage.objects
    FOR UPDATE USING (
      bucket_id = 'avatars' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;

  -- 삭제 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can delete their own avatar'
  ) THEN
    CREATE POLICY "Users can delete their own avatar" ON storage.objects
    FOR DELETE USING (
      bucket_id = 'avatars' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;

  -- 공개 읽기 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Avatar images are publicly accessible'
  ) THEN
    CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');
  END IF;

  -- profile_icons bucket 정책
  -- 공개 읽기 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Profile icons are publicly accessible'
  ) THEN
    CREATE POLICY "Profile icons are publicly accessible" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile_icons');
  END IF;

  -- 파일 목록 조회 정책
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Anyone can list profile icons'
  ) THEN
    CREATE POLICY "Anyone can list profile icons" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile_icons');
  END IF;

END $$;

-- =========================================
-- 5) 중복 데이터 정리 및 기본 아이콘 데이터 삽입
-- =========================================

-- 기존 pets 테이블에 default_icon 컬럼 추가 (중요!)
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS default_icon TEXT;

-- 중복된 기본 아이콘 데이터 모두 삭제
DELETE FROM public.default_icons;

-- 기본 아이콘 데이터 깔끔하게 재삽입
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
-- 6) 인덱스 생성 (성능 최적화)
-- =========================================
CREATE INDEX IF NOT EXISTS idx_pets_owner_id ON public.pets(owner_id);
CREATE INDEX IF NOT EXISTS idx_records_pet_id ON public.records(pet_id);
CREATE INDEX IF NOT EXISTS idx_reminders_pet_id ON public.reminders(pet_id);
CREATE INDEX IF NOT EXISTS idx_labs_pet_id ON public.labs(pet_id);
CREATE INDEX IF NOT EXISTS idx_default_icons_category ON public.default_icons(category);
CREATE INDEX IF NOT EXISTS idx_default_icons_active ON public.default_icons(is_active);

-- =========================================
-- 7) 최종 확인 쿼리
-- =========================================
-- 테이블 구조 확인
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'labs' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 트리거 확인
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'labs';

-- Storage bucket 확인
SELECT id, name, public FROM storage.buckets WHERE id IN ('avatars', 'profile_icons');

-- Storage 정책 확인
SELECT policyname, cmd, qual FROM pg_policies 
WHERE schemaname = 'storage' AND tablename = 'objects' 
AND (policyname LIKE '%avatar%' OR policyname LIKE '%profile_icon%');

-- 기본 아이콘 데이터 확인 (중복 없이 10개만)
SELECT COUNT(*) as total_icons FROM public.default_icons;
SELECT name, icon_data, color, category, sort_order 
FROM public.default_icons 
ORDER BY sort_order;

-- pets 테이블에 default_icon 컬럼이 있는지 확인
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'pets' AND table_schema = 'public' 
AND column_name = 'default_icon';