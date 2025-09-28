-- =========================================
-- Supabase Storage 및 RLS 정책 설정
-- =========================================

-- 1. Storage 버킷 생성 (이미 존재하는 경우 무시)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS 정책 설정
-- 사용자는 자신의 아바타만 업로드/다운로드 가능
CREATE POLICY IF NOT EXISTS "Users can upload their own avatar" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY IF NOT EXISTS "Users can update their own avatar" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY IF NOT EXISTS "Users can delete their own avatar" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY IF NOT EXISTS "Avatar images are publicly accessible" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

-- 3. pets 테이블에 default_icon 컬럼 추가
ALTER TABLE public.pets ADD COLUMN IF NOT EXISTS default_icon TEXT;

-- 4. 기존 RLS 정책 확인 및 추가 (필요한 경우)
-- pets 테이블 RLS 정책
CREATE POLICY IF NOT EXISTS "Users can view their own pets" ON public.pets
FOR SELECT USING (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can insert their own pets" ON public.pets
FOR INSERT WITH CHECK (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can update their own pets" ON public.pets
FOR UPDATE USING (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own pets" ON public.pets
FOR DELETE USING (auth.uid()::text = owner_id);

-- records 테이블 RLS 정책
CREATE POLICY IF NOT EXISTS "Users can view their own records" ON public.records
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = records.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can insert their own records" ON public.records
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = records.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can update their own records" ON public.records
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = records.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can delete their own records" ON public.records
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = records.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

-- labs 테이블 RLS 정책
CREATE POLICY IF NOT EXISTS "Users can view their own lab results" ON public.labs
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = labs.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can insert their own lab results" ON public.labs
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = labs.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can update their own lab results" ON public.labs
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = labs.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

CREATE POLICY IF NOT EXISTS "Users can delete their own lab results" ON public.labs
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.pets 
    WHERE pets.id = labs.pet_id 
    AND pets.owner_id = auth.uid()::text
  )
);

-- reminders 테이블 RLS 정책
CREATE POLICY IF NOT EXISTS "Users can view their own reminders" ON public.reminders
FOR SELECT USING (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can insert their own reminders" ON public.reminders
FOR INSERT WITH CHECK (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can update their own reminders" ON public.reminders
FOR UPDATE USING (auth.uid()::text = owner_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own reminders" ON public.reminders
FOR DELETE USING (auth.uid()::text = owner_id);
